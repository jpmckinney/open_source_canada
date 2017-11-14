# Software licenses

The following documentation describes how to:

* [Collect the licenses used by code repositories controlled by Canadian governments on GitHub](#collect-data)
* [Automate the process of issuing pull requests to add open source licenses to the repositories without licenses](#add-licenses-to-repositories-without-licenses)
* [Semi-automate the process of improving this project's ability to identify licenses](#determine-licenses-of-repositories-with-unrecognized-licenses)

Just want the data on software license usage? [Download the YAML.](https://raw.githubusercontent.com/jpmckinney/open_source_canada/master/data/licenses.yml)

## Collect licensing data

Collect the licenses under which repositories are released on GitHub:

    bundle exec rake licenses:github

Collect the licenses for only the repositories that were created since the last run:

    bundle exec rake licenses:github ONLYNEW=true

Or for only specific *organizations*:

    bundle exec rake licenses:github ORGS=wet-boew,open-data

Or for only specific *repositories*:

    bundle exec rake licenses:github REPOS=wet-boew/codefest,wet-boew/wet-boew-php

## Add licenses to repositories without licenses

This section describes tools to submit pull requests to add licenses to repositories that don't have any.

First, run the `licenses:github` task above. Then, list the non-empty, non-stub repositories without licenses:

    bundle exec rake licenses:none

Or, list specific organization's repositories without licenses:

    bundle exec rake licenses:none ORGS=wet-boew,open-data

Then, list the repositories without licenses as a comma-separated list:

    bundle exec rake licenses:none CSV=true

Analyze selected repositories (`REPOS`) for further processing:

    bundle exec rake repos:analyze REPOS=wet-boew/codefest,wet-boew/wet-boew-php,wet-boew/techspecs

Repositories analyzed as `empty_repository` or `stub_repository` should be reported for deletion as a GitHub issue; the output includes text to use in the issue's description. Create the issue on an active repository of the organization to increase its visibility.

Other repositories, especially those analyzed as `multiple_files`, may require pull requests to add licenses. Fork and clone selected repositories (`REPOS`):

    bundle exec rake repos:fork_and_clone REPOS=wet-boew/codefest,wet-boew/wet-boew-php

Select a license among those already in use by the organization (`ORGS`):

    bundle exec rake licenses:any ORGS=wet-boew

Then, add licenses to selected repositories (`REPOS`) and open a pull request on GitHub. If a repository was analyzed as having multiple branches, you may need to perform this step manually. Set the paths or URLs of the license files (`LICENSE_PATHS`). Set the commit message (`COMMIT_MESSAGE`), which is `"Add open source license"` by default. **There is no undo!**

    bundle exec rake repos:license REPOS=wet-boew/codefest,wet-boew/wet-boew-php COMMIT_MESSAGE="Add MIT license" LICENSE_PATHS=https://raw.githubusercontent.com/wet-boew/wet-boew/master/License-en.txt,https://raw.githubusercontent.com/wet-boew/wet-boew/master/Licence-fr.txt

Once your pull requests are merged, you can easily remove the unneeded forks using [remove-github-forks](https://github.com/denis-sokolov/remove-github-forks/).

## Determine licenses of repositories with unrecognized licenses

This section describes tools to improve the `licenses:github` task's identification of licenses.

First, run the `licenses:github` above. Then, list the repositories with unrecognized licenses:

    bundle exec rake licenses:unknown

Or, list one organization's repositories with unrecognized licenses:

    bundle exec rake licenses:unknown ORG=wet-boew

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

    bundle exec rake licenses:unknown CSV=true

And run the `licenses:github` task to recognize additional licenses thanks to your changes. Repeat this section until all licenses are recognized.

## Cheat sheet

        # Select one organization to work on.
        export ORGS=

        # Get a list of repositories without licenses.
        export REPOS=`bundle exec rake licenses:none CSV=true`

        # Look for an appropriate license. If you need different licenses for
        # different repositories, like GPL-2.0 for Drupal modules, change the
        # REPOS variable as appropriate.
        bundle exec rake licenses:any

        # Check whether any repositories are empty or stubs before forking.
        # Change the REPOS variable as appropriate.
        bundle exec rake repos:analyze

        # Fork and clone the repositories.
        bundle exec rake repos:fork_and_clone

        # Set the path to the license's URL (the raw content, not the GitHub
        # page!). If you had to manually create a license file, set the path to
        # the file.
        export LICENSE_PATHS=

        # Set a commit message like "Add MIT license"
        export COMMIT_MESSAGE="Add MIT license"

        # Check the values of REPOS, COMMIT_MESSAGE and LICENSE_PATHS as the
        # next step has no undo and affects others!
        printenv

        # Create the pull requests.
        bundle exec rake repos:license
