require 'rubygems'
require 'bundler/setup'

require 'fileutils'
require 'set'
require 'yaml'

require 'faraday-http-cache'
require 'git'
require 'licensee'
require 'nokogiri'
require 'octokit'

LICENSES_FILENAME = 'licenses.yml'

Octokit.auto_paginate = true

Octokit.default_media_type = 'application/vnd.github.drax-preview+json'

Octokit.middleware = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::HttpCache, serializer: Marshal, shared_cache: false
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end

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
            # Remove Jekyll Front Matter.
            body = body.gsub(/\A---\n.+\n---\n/m, '')
          end

          matched_file = Licensee::Project::LicenseFile.new(body, File.basename(contents.download_url))

          if matched_file.license
            licenses[repo.full_name]['id'] = matched_file.license.meta['spdx-id']
          else
            # CA-CROWN-COPYRIGHT.txt's `max_delta`, which is based on `inverse_confidence_threshold`,
            # is too small to match due to the file's small size.

            Licensee.instance_variable_set('@inverse', (1 - 90 / 100.0).round(2))

            matcher = Licensee::Matchers::Dice.new(matched_file)
            matches = matcher.licenses_by_similiarity.select{|_, similarity| similarity >= 80}

            unless matches.empty?
              licenses[repo.full_name].merge!({
                'id' => matches[0][0].meta['spdx-id'],
                'confidence' => matches[0][1],
              })
            end

            Licensee.instance_variable_set('@inverse', (1 - 95 / 100.0).round(2))
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

    File.open(LICENSES_FILENAME) do |f|
      YAML.load(f).each do |full_name, license|
        if matcher.call(license)
          owner, _ = full_name.split('/', 2)
          if ENV['ORG'].nil? || ENV['ORG'] == owner
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
    print_repository_urls(->(license) { license.nil? }, ->(full_name, license) { "https://github.com/#{full_name}" })
  end

  desc 'Prints URLs for repositories with unknown licenses, according to GitHub'
  task :unknown do
    print_repository_urls(->(license) { license && license['id'].nil? }, ->(full_name, license) { license['url'] })
  end
end

namespace :repos do
  desc 'Recommends repositories to delete or process further'
  task :analyze do
    client = Octokit::Client.new(access_token: ENV['ACCESS_TOKEN'])

    date_threshold = (Time.now - 10_368_000).to_i # 120 days

    messages = []

    ENV['REPOS'].split(',').each do |full_name|
      print '.'

      repo = client.repo(full_name)

      begin
        commit = repo.rels[:commits].get.data[0].commit
        tree_sha = commit.tree.sha
        tree = client.tree(full_name, tree_sha).tree
        path = tree[0].path

        if tree.one? && path == 'README.md'
          size = tree[0].size
          if size < 2_048
            date = commit.author.date
            if date.to_i < date_threshold
              branches = repo.rels[:branches].get.data.map(&:name)
              if branches.one?
                messages << [full_name, :stub_repository, "has a single branch (#{branches[0]}) with a single file (#{path}) of #{size} bytes updated on #{date.strftime('%b %e, %Y')}"]
              else
                messages << [full_name, :multiple_branches, branches.join(', ')]
              end
            else
              messages << [full_name, :recent_commit_date, "#{path} #{date.strftime('%b %e, %Y')}"]
            end
          else
            messages << [full_name, :large_file_size, "#{path} #{size} bytes"]
          end
        else
          messages << [full_name, :multiple_files, tree.map(&:path).join(', ')]
        end
      rescue Octokit::Conflict => e
        if e.message['409 - Git Repository is empty.']
          messages << [full_name, :empty_repository, "is empty and was updated on #{repo.updated_at.strftime('%b %e, %Y')}"]
        else
          messages << [full_name, :http_error, e]
        end
      end
    end

    order = [
      # Read the error and update this code.
      :http_error,

      # Create a GitHub issue to delete these.
      :empty_repository,
      :stub_repository,

       # Add licenses to active branches using `rake repos:license`.
      :multiple_branches,
      :recent_commit_date,
      :large_file_size,
      :multiple_files,
    ]

    puts
    messages.sort_by{|_, key, _| order.index(key)}.group_by{|_, key, _| key}.each do |key, group|
      puts "#{key} (#{group.size})"
      group.sort.each do |full_name, _, message|
        puts "* [ ] https://github.com/#{full_name} #{message}"
      end
      puts
    end
  end

  desc 'Forks and clones the repositories'
  task :fork_and_clone do
    client = Octokit::Client.new(access_token: ENV['ACCESS_TOKEN'])

    ENV['REPOS'].split(',').each do |full_name|
      _, repo = full_name.split('/', 2)
      url = "https://github.com/#{client.user.login}/#{repo}"

      unless Faraday.head(url).success?
        begin
          client.fork(full_name)
        rescue Octokit::Forbidden => e
          $stderr.puts e.message
          next
        end
      end

      unless File.exist?(repo)
        loop do
          if Faraday.head(url).success?
            Git.clone("git@github.com:#{path}.git", repo)
            break
          else
            sleep 1
          end
        end
      end
    end
  end

  desc 'Adds licenses to the repositories'
  task :license do
    en_license = Faraday.get('https://raw.githubusercontent.com/wet-boew/wet-boew/master/License-en.txt').body
    fr_license = Faraday.get('https://raw.githubusercontent.com/wet-boew/wet-boew/master/Licence-fr.txt').body

    client = Octokit::Client.new(access_token: ENV['ACCESS_TOKEN'])

    branch = 'license'
    message = 'Add license files'
    login = client.user.login

    ENV['REPOS'].split(',').each do |full_name|
      _, repo = full_name.split('/', 2)
      if File.exist?(repo)
        Dir.chdir(repo) do
          git = Git.open(Dir.pwd)
          origin = client.repo("#{login}:#{repo}")
          upstream = client.repo(full_name)

          if File.exist?('License-en.txt') || File.exist?('Licence-fr.txt')
            abort "#{repo}: A license named 'License-en.txt' and/or 'Licence-fr.txt' already exists."
          end
          if git.branches[branch]
            abort "#{repo}: A local branch named '#{branch}' already exists."
          end
          if origin.rels[:branches].get.data.map(&:name).include?(branch)
            abort "#{repo}: A remote branch named '#{branch}' already exists."
          end
          if upstream.rels[:pulls].get.data.map(&:title).include?(message)
            abort "#{repo}: A pull request titled '#{message}' already exists."
          end

          File.open('License-en.txt', 'w') do |f|
            f.write(en_license)
          end
          File.open('Licence-fr.txt', 'w') do |f|
            f.write(fr_license)
          end

          git.branch(branch).checkout
          git.add(%w(License-en.txt Licence-fr.txt))
          git.commit(message)
          git.push('origin', branch)

          client.create_pull_request(full_name, repo.default_branch, "#{login}:#{branch}", message)
        end
      end
    end
  end
end
