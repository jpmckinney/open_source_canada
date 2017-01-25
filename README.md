# Auditing tools for Canadian governments' open source code

This project audits the source code repositories published by Canadian governments.

Care about open data? Head over to the [database of Canadian open government data catalogs](https://github.com/jpmckinney/open_data_canada).

## Usage

[Generate a personal access token on GitHub](https://github.com/settings/tokens) and set an `ACCESS_TOKEN` environment variable:

    export ACCESS_TOKEN=22276075e3468c2ede27c6b3abfbc502d0d7b45f

Collect the licenses under which repositories are released on GitHub:

    bundle exec rake licenses:github

Collect the licenses for only the repositories that were created since the last run:

    bundle exec rake licenses:github ONLYNEW=true

### Add licenses to repositories without licenses

This section describes tools to submit pull requests to add licenses to repositories that don't have any.

First, run the `licenses:github` task above. Then, list the repositories without licenses:

    bundle exec rake licenses:none

Or, list one organization's repositories without licenses:

    bundle exec rake licenses:none ORG=wet-boew

Then, list the repositories without licenses as a comma-separated list:

    bundle exec rake licenses:none CSV=true

Analyze selected repositories (`REPOS`) for further processing:

    bundle exec rake repos:analyze REPOS=wet-boew/codefest,wet-boew/wet-boew-php,wet-boew/techspecs

Repositories analyzed as `empty_repository` or `stub_repository` should be reported for deletion as a GitHub issue. The output includes text to use in the issue description. Create the issue on an active repository of the organization to increase its visibility.

Other repositories may require pull requests to add licenses. Fork and clone selected repositories (`REPOS`):

    bundle exec rake repos:fork_and_clone REPOS=wet-boew/codefest,wet-boew/wet-boew-php

Then, add licenses to selected repositories (`REPOS`) and open a pull request on GitHub. If a repository was analyzed as having multiple branches, you may need to perform this step manually. There is no undo!

    bundle exec rake repos:license REPOS=wet-boew/codefest,wet-boew/wet-boew-php

Once your pull requests are merged, you can easily remove the unneeded forks using [remove-github-forks](https://github.com/denis-sokolov/remove-github-forks/).

### Determine licenses of repositories with unrecognized licenses

This section describes tools to improve the `licenses:github` task's identification of licenses.

First, run the `licenses:github` above. Then, list the repositories with unrecognized licenses:

    bundle exec rake licenses:unknown

Or, list one organization's repositories with unrecognized licenses:

    bundle exec rake licenses:none ORG=wet-boew

Then, open each URL to inspect each license. If appropriate, create a file under `_licenses/` following the pattern `XX[-YY]-key-NOTE.txt` where:

* `XX` is the ISO 3166-1 alpha-2 code of the jurisdiction using the license
* `YY` is the second part of the ISO-3166-2 code of the jurisdiction using the license
* If the license modifies a [choosealicense.com](https://github.com/benbalter/licensee/tree/master/vendor/choosealicense.com/_licenses) license, `key` is the lowercase basename of the license it modifies (e.g. `mit` or `apache-2.0`). Otherwise, `key` is the uppercase abbreviation of the license, which should include the version number if available.
* `NOTE` is an uppercase note to differentiate a modified license, in case the jurisdiction prefix is insufficient.

The first lines of the file should be YAML Front Matter, for example:

```
---
title: MIT License
spdx-id: MIT

using:
  - https://raw.githubusercontent.com/fgpv-vpgf/gulp-i18n-csv/master/license

notes: Adds a translation of mit.txt

---
```

* If the license modifies a choosealicense.com license, use the same `title` and `spdx-id` and write brief `notes` describing the modification. If the license is listed in the [SPDX License List](https://spdx.org/licenses/), use the license's full name and identifier from SPDX. Otherwise, choose a title and identifier.
* List at least one URL to a repository using the license under `using`; as more governments adopt standard licenses, this data can be used to remove obsolete licenses from this project.
* After the YAML Front Matter, if the license is listed in the SPDX License List, use its SPDX license text. Otherwise, use the text you have, replacing copyright years with `[year]`, copyright holders with `[fullname]`, and project names with `[project]`.

Then, list the repositories with unrecognized licenses as a comma-separated list:

    bundle exec rake licenses:none CSV=true

And run the `licenses:github` task to recognize additional licenses thanks to your changes. Repeat this section until all licenses are recognized.

### Add GitHub organizations to [@cdngovrepos](https://twitter.com/cdngovrepos)

`cdngovrepos` is a Twitter bot that tweets every time any Canadian government opens a new repo on GitHub. It uses IFTTT. IFTTT applets can only be created manually. (I attempted to automate the process using the Web Console, but I couldn't trigger the selection of services or the configuring of the organization and message.)

My process for adding new organizations to IFTTT is:

#### Setup

1. Copy the message `{{RepositoryName}} is a new repo by {{OwnerUsername}}: {{RepositoryURL}}` into a text editor
1. Run `bundle exec rake organizations` to get a list of organizations to add
1. Copy the list of organizations into the same file in the text editor
1. Add `https://ifttt.com/create/` to the Bookmarks Toolbar
1. Zoom all the way out

#### Repeat

1. Click the bookmark
1. Click 'this'
1. ⌘↓
1. Click 'GitHub' (last row)
1. Click 'New repository by a specific username or organization' (last item)
1. Cut and paste the first organization in the list
1. Click 'Create trigger'
1. Click 'that'
1. Click 'Twitter' (first item)
1. Click 'Post a tweet' (first item)
1. Copy and paste the message
1. Click 'Create action'
1. Uncheck 'Receive notifications when this Applet runs'
1. Click 'Finish'

Copyright (c) 2017 James McKinney, released under the MIT license
