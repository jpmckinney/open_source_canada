# Auditing tools for Canadian governments' open source code

This project audits the source code repositories published by Canadian governments.

Care about open data? Head over to the [database of Canadian open government data catalogs](https://github.com/jpmckinney/open_data_canada).

## Downloads

Download the data as YAML:

* [Software license usage](https://raw.githubusercontent.com/jpmckinney/open_source_canada/master/data/licenses.yml)
* [Programming language usage](https://raw.githubusercontent.com/jpmckinney/open_source_canada/master/data/languages.yml)
* [GitHub organizations controlled by Canadian governments](https://raw.githubusercontent.com/jpmckinney/open_source_canada/master/data/organizations.txt)

## Usage

[Generate a personal access token on GitHub](https://github.com/settings/tokens) and set an `ACCESS_TOKEN` environment variable:

    export ACCESS_TOKEN=22276075e3468c2ede27c6b3abfbc502d0d7b45f

Then, follow the documentation relating to:

* [What software licenses Canadian governments use](docs/licenses.md#readme)
* [Tweeting each time a Canadian government creates a GitHub repository](docs/cdngovrepos.md#readme)
* [What programming languages Canadian governments use](docs/miscellaneous.md#readme)

### Regular maintenance

    bundle exec rake organizations > data/organizations.txt
    bundle exec rake licenses:github ONLYNEW=true
    bundle exec rake languages:github ONLYNEW=true
    bundle exec rake validate
    bundle exec rake licenses:none
    bundle exec rake licenses:unknown

Copyright (c) 2017 James McKinney, released under the MIT license
