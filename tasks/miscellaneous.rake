desc 'Prints GitHub organizations'
task :organizations do
  puts canadian_government_organizations.to_a.sort
end
