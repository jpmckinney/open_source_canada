require 'rubygems'
require 'bundler/setup'

require 'fileutils'
require 'set'
require 'yaml'

require 'faraday-http-cache'
require 'git'
require 'licensee'
require 'octokit'

Octokit.auto_paginate = true

Octokit.default_media_type = 'application/vnd.github.drax-preview+json'

Octokit.middleware = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::HttpCache, serializer: Marshal, shared_cache: false
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end

namespace :licenses do
  desc "Write a licenses.yml file with each repository's license, according to GitHub"
  task :github do
    client = Octokit::Client.new(access_token: ENV['ACCESS_TOKEN'])
    headers = {accept: 'application/vnd.github.drax-preview+json'}

    licenses_filename = 'licenses.yml'
    licenses = {}

    if File.exist?(licenses_filename)
      licenses = YAML.load(File.read(licenses_filename))
    end

    if ENV['ORGS']
      organization_names = ENV['ORGS'].split(',')
    else
      organization_names = Set.new

      Faraday.get('https://raw.githubusercontent.com/canada-ca/welcome/master/Organizations-Organisations.md').body.scan(/\(([a-z]+:[^)]+)\)/).sort.each do |url|
        parsed = URI.parse(url[0])
        if parsed.host['github.com']
          organization_names << parsed.path.chomp('/').match(%r{/(\S+)})[1].downcase
        end
      end

      organization_names += YAML.load(Faraday.get('https://raw.githubusercontent.com/github/government.github.com/gh-pages/_data/governments.yml').body)['Canada'].map(&:downcase)
    end

    if ENV['REPOS']
      repositories = ENV['REPOS'].split(',').map do |owner_repo|
        client.repo(owner_repo, headers)
      end
    else
      repositories = organization_names.flat_map do |organization_name|
        client.repos(organization_name, headers.merge(type: 'sources'))
      end
    end

    repositories.each do |repo|
      licenses[repo.full_name] = nil

      if repo.license
        licenses[repo.full_name] = {
          'id' => repo.license.spdx_id,
          'key' => repo.license.key,
          'url' => client.repository_license_contents(repo.full_name, headers).html_url,
        }
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

    File.open(licenses_filename, 'w') do |f|
      f.write(YAML.dump(licenses))
    end
  end

  desc 'Prints URLs for repositories without licenses, according to GitHub'
  task :none do
    owner_repos = []

    File.open('licenses.yml') do |f|
      YAML.load(f).each do |owner_repo,license|
        if license.nil?
          owner, _ = owner_repo.split('/', 2)
          if ENV['ORG'].nil? || ENV['ORG'] == owner
            owner_repos << owner_repo
          end
        end
      end
    end

    if ENV['CSV']
      puts owner_repos.join(',')
    else
      owner_repos.each do |owner_repo|
        puts "https://github.com/#{owner_repo}"
      end
    end
  end

  desc 'Prints URLs for repositories with unknown licenses, according to GitHub'
  task :unknown do
    File.open('licenses.yml') do |f|
      YAML.load(f).each do |owner_repo,license|
        if license && license['id'].nil?
          puts "https://github.com/#{owner_repo}"
        end
      end
    end
  end
end

namespace :repos do
  desc 'Recommends repositories to delete or process further'
  task :analyze do
    client = Octokit::Client.new(access_token: ENV['ACCESS_TOKEN'])

    date_threshold = (Time.now - 10_368_000).to_i # 120 days

    messages = []

    ENV['REPOS'].split(',').each do |owner_repo|
      print '.'

      repo = client.repo(owner_repo)

      begin
        commit = repo.rels[:commits].get.data[0].commit
        tree_sha = commit.tree.sha
        tree = client.tree(owner_repo, tree_sha).tree
        path = tree[0].path

        if tree.one? && path == 'README.md'
          size = tree[0].size
          if size < 2_048
            date = commit.author.date
            if date.to_i < date_threshold
              branches = repo.rels[:branches].get.data.map(&:name)
              if branches.one?
                messages << [owner_repo, :stub_repository, "has a single branch (#{branches[0]}) with a single file (#{path}) of #{size} bytes updated on #{date.strftime('%b %e, %Y')}"]
              else
                messages << [owner_repo, :multiple_branches, branches.join(', ')]
              end
            else
              messages << [owner_repo, :recent_commit_date, "#{path} #{date.strftime('%b %e, %Y')}"]
            end
          else
            messages << [owner_repo, :large_file_size, "#{path} #{size} bytes"]
          end
        else
          messages << [owner_repo, :multiple_files, tree.map(&:path).join(', ')]
        end
      rescue Octokit::Conflict => e
        if e.message['409 - Git Repository is empty.']
          messages << [owner_repo, :empty_repository, "is empty and was updated on #{repo.updated_at.strftime('%b %e, %Y')}"]
        else
          messages << [owner_repo, :http_error, e]
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
      group.sort.each do |owner_repo, _, message|
        puts "* [ ] https://github.com/#{owner_repo} #{message}"
      end
      puts
    end
  end

  desc 'Forks and clones the repositories'
  task :fork_and_clone do
    client = Octokit::Client.new(access_token: ENV['ACCESS_TOKEN'])

    ENV['REPOS'].split(',').each do |owner_repo|
      _, repo = owner_repo.split('/', 2)
      url = "https://github.com/#{client.user.login}/#{repo}"

      unless Faraday.head(url).success?
        begin
          client.fork(owner_repo)
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

    ENV['REPOS'].split(',').each do |owner_repo|
      _, repo = owner_repo.split('/', 2)
      if File.exist?(repo)
        Dir.chdir(repo) do
          git = Git.open(Dir.pwd)
          origin = client.repo("#{login}:#{repo}")
          upstream = client.repo(owner_repo)

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

          client.create_pull_request(owner_repo, repo.default_branch, "#{login}:#{branch}", message)
        end
      end
    end
  end
end
