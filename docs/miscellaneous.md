# Miscellaneous tasks

The following documentation describes how to:

* [Collect the languages used by code repositories controlled by Canadian governments on GitHub.](#collect-language-data)
* [List the GitHub organizations controlled by Canadian governments](#list-github-organizations-controlled-by-canadian-governments)

Just want the data on programming language usage? [Download the YAML.](https://raw.githubusercontent.com/jpmckinney/open_source_canada/master/data/languages.yml)

## Collect language data

Collect the languages in which repositories are written on GitHub:

    bundle exec rake languages:github

Collect the licenses for only the repositories that were created since the last run:

    bundle exec rake languages:github ONLYNEW=true

Or for only specific *organizations*:

    bundle exec rake languages:github ORGS=wet-boew,open-data

Or for only specific *repositories*:

    bundle exec rake languages:github REPOS=wet-boew/codefest,wet-boew/wet-boew-php

## List GitHub organizations controlled by Canadian governments

    bundle exec rake organizations
