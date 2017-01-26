LANGUAGES_FILENAME = 'languages.yml'

namespace :languages do
  desc "Write a languages.yml file with each repository's languages, according to GitHub"
  task :github do
    process(LANGUAGES_FILENAME) do |data,repo|
      data[repo.full_name] = repo.rels[:languages].get.data.to_h
    end
  end
end
