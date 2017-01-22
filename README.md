# Canadian governments' open source code

This project audits the source code repositories published by Canadian governments.

Care about open data? Head over to the [database of Canadian open government data catalogs](https://github.com/jpmckinney/open_data_canada).

## Usage

[Generate a personal access token on GitHub](https://github.com/settings/tokens) and set an `ACCESS_TOKEN` environment variable:

    export ACCESS_TOKEN=22276075e3468c2ede27c6b3abfbc502d0d7b45f

Collect the licenses under which repositories are released on GitHub:

    bundle exec rake licenses:github

### License repositories without licenses

List the repositories without licenses:

    bundle exec rake licenses:none

List one organization's repositories without licenses:

    bundle exec rake licenses:none ORG=wet-boew

List the repositories without licenses as a comma-separated list:

    bundle exec rake licenses:none CSV=true

Analyze selected repositories (`REPOS`) for further processing:

    bundle exec rake repos:analyze REPOS=wet-boew/codefest,wet-boew/wet-boew-php,wet-boew/techspecs

Repositories analyzed as `empty_repository` or `stub_repository` should be reported for deletion as a GitHub issue. The output includes text to use in the issue description. Create the issue on an active repository of the organization to increase its visibility.

Other repositories may require pull requests to add licenses. Fork and clone selected repositories (`REPOS`):

    bundle exec rake repos:fork_and_clone REPOS=wet-boew/codefest,wet-boew/wet-boew-php

Then, add licenses to selected repositories (`REPOS`) and open a pull request on GitHub. If a repository was analyzed as having multiple branches, you may need to perform this step manually. There is no undo!

    bundle exec rake repos:license REPOS=wet-boew/codefest,wet-boew/wet-boew-php

Once your pull requests are merged, you can easily remove the unneeded forks using [remove-github-forks](https://github.com/denis-sokolov/remove-github-forks/).

### Review repositories with unknown licenses

List the repositories with unknown licenses:

    bundle exec rake licenses:unknown

Copyright (c) 2017 James McKinney, released under the MIT license
