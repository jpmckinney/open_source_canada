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

Octokit.auto_paginate = true

Octokit.default_media_type = 'application/vnd.github.drax-preview+json'

Octokit.middleware = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::HttpCache, serializer: Marshal, shared_cache: false
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end

# @return [Octokit::Client] A GitHub API client
def github_client
  @github_client ||= Octokit::Client.new(access_token: ENV['ACCESS_TOKEN'])
end

# @param [String] basename a basename
# @yieldparam [Hash] data the data that will be written
# @yieldparam [Sawyer::Resource] repo the GitHub repository to process
def process(basename)
  filename = File.join('data', basename)

  headers = {accept: 'application/vnd.github.drax-preview+json'}

  data = {}

  # Load existing data.
  if File.exist?(filename)
    data = YAML.load_file(filename)
  end

  # Get the repositories to process.
  if ENV['REPOS']
    repositories = ENV['REPOS'].split(',').map do |full_name|
      github_client.repo(full_name, headers.dup)
    end
  else
    # Get the organizations to process.
    if ENV['ORGS']
      organization_names = ENV['ORGS'].split(',')
    else
      organization_names = canadian_government_organizations
    end

    repositories = organization_names.to_a.sort.flat_map do |organization_name|
      github_client.org_repos(organization_name, headers.merge(type: 'sources'))
    end
  end

  # Eliminate repositories for which we already have data.
  if ENV['ONLYNEW']
    repositories.reject!{|repo| data.key?(repo.full_name)}
  end

  # Print the number of repositories to get a sense of how long it will take.
  puts "#{repositories.size} repositories"

  begin
    repositories.each do |repo|
      print '.'

      data[repo.full_name] ||= nil

      begin
        yield data, repo
      rescue Octokit::NotFound => e
        puts e
      rescue => e
        puts "#{e.class}: #{e}"
        if data[repo.full_name].nil?
          data.delete(repo.full_name)
        end
        puts e.backtrace.join("\n")
      end
    end
  end

  File.open(filename, 'w') do |f|
    f.write(YAML.dump(data.sort.to_h))
  end
end

# @return [Array<String>] GitHub organizations controlled by Canadian governments
def canadian_government_organizations
  organization_names = Set.new

  Faraday.get('https://raw.githubusercontent.com/canada-ca/welcome/master/Organizations-Organisations.md').body.scan(/\(([a-z]+:[^)]+)\)/).each do |url|
    parsed = URI.parse(url[0])
    if parsed.host['github.com']
      organization_names << parsed.path.chomp('/')[1..-1].downcase
    end
  end

  organization_names += YAML.load(Faraday.get('https://raw.githubusercontent.com/github/government.github.com/gh-pages/_data/governments.yml').body)['Canada'].map(&:downcase)
end

Dir['tasks/*.rake'].each { |r| import r }
