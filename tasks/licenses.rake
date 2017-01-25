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
    client = Octokit::Client.new(access_token: ENV['ACCESS_TOKEN'])
    headers = {accept: 'application/vnd.github.drax-preview+json'}

    licenses = {}

    # Load existing licenses.
    if File.exist?(LICENSES_FILENAME)
      licenses = YAML.load(File.read(LICENSES_FILENAME))
    end

    # Get the repositories to process.
    if ENV['REPOS']
      repositories = ENV['REPOS'].split(',').map do |full_name|
        client.repo(full_name, headers.dup)
      end
    else
      # Get the organizations to process.
      if ENV['ORGS']
        organization_names = ENV['ORGS'].split(',')
      else
        organization_names = Set.new

        Faraday.get('https://raw.githubusercontent.com/canada-ca/welcome/master/Organizations-Organisations.md').body.scan(/\(([a-z]+:[^)]+)\)/).each do |url|
          parsed = URI.parse(url[0])
          if parsed.host['github.com']
            organization_names << parsed.path.chomp('/')[1..-1].downcase
          end
        end

        organization_names += YAML.load(Faraday.get('https://raw.githubusercontent.com/github/government.github.com/gh-pages/_data/governments.yml').body)['Canada'].map(&:downcase)
      end

      repositories = organization_names.to_a.sort.flat_map do |organization_name|
        client.org_repos(organization_name, headers.merge(type: 'sources'))
      end
    end

    if ENV['ONLYNEW']
      repositories.reject!{|repo| licenses.key?(repo.full_name)}
    end

    repositories.each do |repo|
      print '.'

      licenses[repo.full_name] ||= nil

      if repo.license
        contents = client.repository_license_contents(repo.full_name, headers.dup)

        licenses[repo.full_name] = {
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
            licenses[repo.full_name]['id'] = matched_file.license.meta['spdx-id']
          else
            # CA-CROWN-COPYRIGHT.txt's `max_delta`, which is based on `inverse_confidence_threshold`,
            # is too small to match due to the file's small size.

            Licensee.instance_variable_set('@inverse', (1 - CONFIDENCE_THRESHOLD_LOW / 100.0).round(2))

            matcher = Licensee::Matchers::Dice.new(matched_file)
            matches = matcher.licenses_by_similiarity.select{|_, similarity| similarity >= CONFIDENCE_THRESHOLD_LOW}

            unless matches.empty?
              licenses[repo.full_name].merge!({
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
              licenses[repo.full_name] = {
                'id' => matched_file.license.meta['spdx-id'],
                'url' => "https://github.com/#{repo.full_name}/blob/#{repo.default_branch}/#{matched_file.filename}",
                'confidence' => matched_file.confidence,
              }
            elsif matched_file.is_a?(Licensee::Project::LicenseFile)
              matcher = Licensee::Matchers::Dice.new(matched_file)
              matches = matcher.licenses_by_similiarity

              unless matches.empty?
                licenses[repo.full_name] = {
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

    File.open(LICENSES_FILENAME, 'w') do |f|
      f.write(YAML.dump(licenses))
    end
  end

  def print_repository_urls(matcher, formatter)
    matches = []

    owners = ENV['ORGS'] && ENV['ORGS'].split(',')

    File.open(LICENSES_FILENAME) do |f|
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
