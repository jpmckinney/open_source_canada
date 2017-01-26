LICENSES_FILENAME = 'licenses.yml'

CONFIDENCE_THRESHOLD = Licensee::CONFIDENCE_THRESHOLD
CONFIDENCE_THRESHOLD_LOW = 70

# Override `Licensee::License.license_dir` in order to customize the licenses.
# `_licenses` is based on https://github.com/github/choosealicense.com/tree/gh-pages/_licenses
class Licensee::License
  class << self
    def license_dir
      dir = File.dirname(__FILE__)
      File.expand_path '_licenses', dir
    end
  end
end

namespace :licenses do
  desc "Write a licenses.yml file with each repository's license, according to GitHub"
  task :github do
    process(LICENSES_FILENAME) do |data,repo|
      if repo.license
        contents = github_client.repository_license_contents(repo.full_name, {accept: 'application/vnd.github.drax-preview+json'})

        data[repo.full_name] = {
          'id' => repo.license.spdx_id,
          'url' => contents.html_url,
        }

        if repo.license.key == 'other'
          body = Faraday.get(contents.download_url).body

          case File.extname(contents.download_url)
          when '.html'
            # Remove non-content HTML.
            text = Nokogiri::HTML(body).xpath('//main').text
            unless text.empty?
              body = text
            end
          when '.md'
            # Remove YAML Front Matter.
            # https://github.com/RAMP-PCAR/ramp-pcar-docs/blob/master/license-en.md
            body = body.gsub(/\A---\n.+\n---\n/m, '')
          when '.txt'
            # Remove license terms of additional libraries.
            # https://github.com/infra-geo-ouverte/igo2/blob/master/LICENCE.txt
            body = body.gsub(/\n_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ \n.+/m, '')
          end

          matched_file = Licensee::Project::LicenseFile.new(body, File.basename(contents.download_url))

          if matched_file.license
            data[repo.full_name]['id'] = matched_file.license.meta['spdx-id']
          else
            # CA-CROWN-COPYRIGHT.txt's `max_delta`, which is based on `inverse_confidence_threshold`,
            # is too small to match due to the file's small size.

            Licensee.instance_variable_set('@inverse', (1 - CONFIDENCE_THRESHOLD_LOW / 100.0).round(2))

            matcher = Licensee::Matchers::Dice.new(matched_file)
            matches = matcher.licenses_by_similiarity.select{|_, similarity| similarity >= CONFIDENCE_THRESHOLD_LOW}

            unless matches.empty?
              data[repo.full_name].merge!({
                'id' => matches[0][0].meta['spdx-id'],
                'confidence' => matches[0][1],
              })
            end

            Licensee.instance_variable_set('@inverse', (1 - CONFIDENCE_THRESHOLD / 100.0).round(2))
          end
        end
      elsif !Git.ls_remote(repo.html_url).empty?
        Dir.mktmpdir do |dir|
          # @see https://github.com/benbalter/licensee/blob/master/bin/licensee
          git = Git.clone("git@github.com:#{repo.full_name}.git", dir)

          project = Licensee.project(dir, detect_packages: true, detect_readme: true)
          matched_file = project.matched_file

          if matched_file
            if matched_file.license
              data[repo.full_name] = {
                'id' => matched_file.license.meta['spdx-id'],
                'url' => "https://github.com/#{repo.full_name}/blob/#{repo.default_branch}/#{matched_file.filename}",
                'confidence' => matched_file.confidence,
              }
            elsif matched_file.is_a?(Licensee::Project::LicenseFile)
              matcher = Licensee::Matchers::Dice.new(matched_file)
              matches = matcher.licenses_by_similiarity

              unless matches.empty?
                data[repo.full_name] = {
                  'id' => matches[0][0].meta['spdx-id'],
                  'url' => "https://github.com/#{repo.full_name}/blob/#{repo.default_branch}/#{matched_file.filename}",
                  'confidence' => matches[0][1],
                }
              end
            end
          end
        end
      end
    end
  end

  def print_repository_urls(matcher, formatter)
    matches = []

    owners = ENV['ORGS'] && ENV['ORGS'].split(',')

    File.open(File.join('data', LICENSES_FILENAME)) do |f|
      YAML.load(f).each do |full_name, license|
        if matcher.call(license)
          owner, _ = full_name.split('/', 2)
          if owners.nil? || owners.include?(owner)
            matches << [full_name, license]
          end
        end
      end
    end

    if ENV['CSV']
      puts matches.map(&:first).join(',')
    else
      matches.each do |full_name, license|
        puts formatter.call(full_name, license)
      end
    end
  end

  desc 'Prints URLs for repositories without licenses, according to GitHub'
  task :none do
    print_repository_urls(
      ->(license) { license.nil? },
      ->(full_name, license) { "https://github.com/#{full_name}" }
    )
  end

  desc 'Prints URLs for repositories with unknown licenses, according to GitHub'
  task :unknown do
    print_repository_urls(
      ->(license) { license && license['id'].nil? }, 
      ->(full_name, license) { license['url'] }
    )
  end
end
