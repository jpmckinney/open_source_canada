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
