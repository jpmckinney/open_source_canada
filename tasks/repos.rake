namespace :repos do
  desc 'Recommends repositories to delete or process further'
  task :analyze do
    date_threshold = (Time.now - 10_368_000).to_i # 120 days

    messages = []

    ENV['REPOS'].split(',').each do |full_name|
      print '.'

      repo = github_client.repo(full_name)

      begin
        commit = repo.rels[:commits].get.data[0].commit
        tree_sha = commit.tree.sha
        tree = github_client.tree(full_name, tree_sha).tree
        path = tree[0].path

        if tree.one? && path == 'README.md'
          size = tree[0].size
          if size < 2_048
            date = commit.author.date
            if date.to_i < date_threshold
              branches = repo.rels[:branches].get.data.map(&:name)
              if branches.one?
                messages << [full_name, :stub_repository, "has a single branch (#{branches[0]}) with a single file (#{path}) of #{size} bytes updated on #{date.strftime('%b %e, %Y')}"]
              else
                messages << [full_name, :multiple_branches, branches.join(', ')]
              end
            else
              messages << [full_name, :recent_commit_date, "#{path} #{date.strftime('%b %e, %Y')}"]
            end
          else
            messages << [full_name, :large_file_size, "#{path} #{size} bytes"]
          end
        else
          messages << [full_name, :multiple_files, tree.map(&:path).join(', ')]
        end
      rescue Octokit::Conflict => e
        if e.message['409 - Git Repository is empty.']
          messages << [full_name, :empty_repository, "is empty and was updated on #{repo.updated_at.strftime('%b %e, %Y')}"]
        else
          messages << [full_name, :http_error, e]
        end
      end
    end

    order = [
      # Read the error and update this code.
      :http_error,

      # Create a GitHub issue to delete these.
      :empty_repository,
      :stub_repository,

       # Add licenses to active branches using `rake repos:license`.
      :multiple_branches,
      :recent_commit_date,
      :large_file_size,
      :multiple_files,
    ]

    puts
    messages.sort_by{|_, key, _| order.index(key)}.group_by{|_, key, _| key}.each do |key, group|
      puts "#{key} (#{group.size})"
      group.sort.each do |full_name, _, message|
        puts "* [ ] https://github.com/#{full_name} #{message}"
      end
      puts
    end
  end

  desc 'Forks and clones the repositories'
  task :fork_and_clone do
    login = github_client.user.login

    ENV['REPOS'].split(',').each do |full_name|
      _, repo = full_name.split('/', 2)
      url = "https://github.com/#{login}/#{repo}"

      unless Faraday.head(url).success?
        begin
          github_client.fork(full_name)
        rescue Octokit::Forbidden => e
          $stderr.puts e.message
          next
        end
      end

      unless File.exist?(repo)
        loop do
          if Faraday.head(url).success?
            Git.clone("git@github.com:#{login}/#{repo}.git", repo)
            break
          else
            sleep 1
          end
        end
      end
    end
  end

  desc 'Adds licenses to the repositories'
  task :license do
    license_contents = {}

    ENV['LICENSE_PATHS'].split(',').each do |path|
      filename = File.basename(path)
      if URI.parse(path).scheme
        license_contents[filename] = Faraday.get(path).body
      else
        license_contents[filename] = File.read(path)
      end
    end

    branch = 'license'
    message = ENV['COMMIT_MESSAGE'] || 'Add open source license'
    login = github_client.user.login

    ENV['REPOS'].split(',').each do |full_name|
      _, repo = full_name.split('/', 2)
      if File.exist?(repo)
        Dir.chdir(repo) do
          git = Git.open(Dir.pwd)
          origin = github_client.repo("#{login}/#{repo}")
          upstream = github_client.repo(full_name)

          if license_contents.keys.any?{ |filename| File.exist?(filename)}
            abort "#{repo}: A license file already exists."
          end
          if git.branches[branch]
            abort "#{repo}: A local branch named '#{branch}' already exists."
          end
          if origin.rels[:branches].get.data.map(&:name).include?(branch)
            abort "#{repo}: A remote branch named '#{branch}' already exists."
          end
          if upstream.rels[:pulls].get.data.map(&:title).include?(message)
            abort "#{repo}: A pull request titled '#{message}' already exists."
          end

          license_contents.each do |filename,content|
            File.open(filename, 'w') do |f|
              f.write(content)
            end
          end

          git.branch(branch).checkout
          git.add(license_contents.keys)
          git.commit(message)
          git.push('origin', branch)

          github_client.create_pull_request(full_name, origin.default_branch, "#{login}:#{branch}", message)
        end
      end
    end
  end
end
