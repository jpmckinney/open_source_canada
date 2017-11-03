# @cdngovrepos

[@cdngovrepos](https://twitter.com/cdngovrepos) tweets every time any Canadian government opens a new code repository on GitHub, inspired by [@newgovrepos](https://twitter.com/newgovrepos) and [@newsnerdrepos](https://twitter.com/newsnerdrepos) and powered by [IFTTT](https://ifttt.com/).

**Is a Canadian government's repositories not being tweeted? [Create an issue on GitHub](https://github.com/jpmckinney/open_source_canada/issues/new) or [contact James McKinney](mailto:james@slashpoundbang.com).**

Please also add missing government GitHub organizations to the [GitHub government community](https://government.github.com/community/#canada) by [following these instructions](https://government.github.com/community/#add-an-organization-to-the-list).

The following documentation describes how to:

* [Add GitHub organizations to IFTTT.](#add-github-organizations-to-ifttt)

## Add GitHub organizations to IFTTT

I created one IFTTT applet per GitHub organization to send the tweets. IFTTT applets can only be created manually. (I attempted to automate the process using the Web Console, but I couldn't trigger the selection of services or the configuring of the organization and message.)

My process for adding a new IFTTT applet is:

### Setup

1. Copy the message `{{RepositoryName}} is a new repo by {{OwnerUsername}}: {{RepositoryURL}}` into a text editor
1. Run `bundle exec rake organizations` to update the list of organizations
1. Run `git diff data/organizations.txt | grep '^\+' | tail -n +2` to get organizations to add
1. Copy the list of organizations into the same file in the text editor
1. Add `https://ifttt.com/create/` to the browser's bookmarks toolbar
1. Zoom the browser all the way out

### Repeat

1. Click the bookmark
1. Click 'this'
1. ⌘↓
1. Click 'GitHub' (before last row)
1. Click 'New repository by a specific username or organization' (last item in first row)
1. Cut and paste the first organization in the list
1. Click 'Create trigger'
1. Click 'that'
1. Click 'Twitter' (first item)
1. Click 'Post a tweet' (first item)
1. Copy and paste the message
1. Click 'Create action'
1. Uncheck 'Receive notifications when this Applet runs'
1. Click 'Finish'
