desc 'Prints GitHub organizations'
task :organizations do
  puts canadian_government_organizations.to_a.sort
end

desc 'Prints discrepancies across data files'
task :validate do
  def compare(hash)
    hash.keys.permutation(2).each do |a, b|
      difference = hash[a] - hash[b]
      unless difference.empty?
        puts "in #{a} not in #{b}: #{difference.uniq.map{|path| "https://github.com/#{path}"}.join(' ')}"
      end
    end
  end

  def organizations_from_hash(hash)
    hash.keys.map{|full_name| full_name.split('/', 2)[0].downcase}
  end

  organizations = File.readlines(File.join('data', 'organizations.txt')).map(&:chomp)
  licenses = YAML.load_file(File.join('data', 'licenses.yml'))
  languages = YAML.load_file(File.join('data', 'languages.yml'))

  compare({
    'organizations.txt' => organizations,
    'licenses.yml' => organizations_from_hash(licenses),
    'languages.yml' => organizations_from_hash(languages),
  })

  compare({
    'licenses.yml' => licenses.keys,
    'languages.yml' => languages.keys,
  })
end
