# Miscellaneous tasks

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
