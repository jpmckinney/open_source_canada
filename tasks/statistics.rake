namespace :statistics do
  def print_aggregate(aggregate)
    regex = /(\d)(?=(\d\d\d)+(?!\d))/
    total = aggregate.values.reduce(&:+)
    puts "%13s       total" % total.to_s.gsub(regex, '\1,')
    aggregate.sort_by(&:last).reverse.each do |license,count|
      puts "%13s %4.1f%% %s" % [count.to_s.gsub(regex, '\1,'), count / total.to_f * 100, license]
    end
    puts
  end

  desc 'Analyze repositories'
  task :repos do
    organization_names = ENV['ORGS'] && ENV['ORGS'].split(',').map(&:downcase)

    data = YAML.load_file(File.join('data', 'languages.yml'))

    jurisdictions = {
      # ISO-3166-1
      'CA' => federal_government_organizations + %w(fgpv-vpgf),

      # ISO-3166-2
      'CA-AB' => %w(abgov),
      'CA-BC' => %w(bcdevexchange bcgov),
      'CA-NS' => %w(nsgov),
      'CA-NT' => %w(gnwt),
      'CA-QC' => %w(electionsquebec infra-geo-ouverte),

      'CA-AB Calgary' => %w(thecityofcalgary),
      'CA-BC Surrey' => %w(cityofsurrey),
      'CA-ON Greater Sudbury' => %w(cityofgreatersudbury),
      'CA-ON Ottawa' => %w(cityofottawa),
      'CA-ON Toronto' => %w(cityoftoronto),
      'CA-QC Montréal' => %w(villedemontreal),
    }

    per_organization = Hash.new(0)
    per_jurisdiction = Hash.new(0)

    data.each do |full_name,license|
      organization = full_name.split('/', 2)[0].downcase

      if !organization_names || organization_names.include?(organization)
        jurisdiction = jurisdictions.keys.find{ |key| jurisdictions[key].include?(organization) } || organization

        per_organization[organization] += 1
        per_jurisdiction[jurisdiction] += 1
      end
    end

    print_aggregate(per_organization)
    print_aggregate(per_jurisdiction)
  end

  desc 'Analyze software licenses'
  task :licenses do
    organization_names = ENV['ORGS'] && ENV['ORGS'].split(',').map(&:downcase)

    data = YAML.load_file(File.join('data', 'licenses.yml'))

    per_license_id = Hash.new(0)
    per_organization = {}

    data.each do |full_name,license|
      organization = full_name.split('/', 2)[0].downcase

      if !organization_names || organization_names.include?(organization)
        if license
          license_id = license['id'] || 'other'
        else
          license_id = 'no-license'
        end

        per_license_id[license_id] += 1
        per_organization[organization] ||= Hash.new(0)
        per_organization[organization][license_id] += 1
      end
    end

    print_aggregate(per_license_id)
    per_organization.sort_by{|_,counts| counts.values.reduce(:+)}.reverse.each do |organization,counts|
      puts organization
      print_aggregate(counts)
    end

    %w(no-license other).each do |license_id|
      aggregate = Hash.new(0)

      per_organization.each do |organization,counts|
        count = counts[license_id]
        if count.nonzero?
          aggregate[organization] = count
        end
      end

      puts license_id
      print_aggregate(aggregate)
    end
  end

  desc 'Analyze programming languages'
  task :languages do
    data = YAML.load_file(File.join('data', 'languages.yml'))

    per_language = Hash.new(0)
    per_organization = {}

    data.each do |full_name,languages|
      organization = full_name.split('/', 2)[0].downcase

      languages.each do |language,count|
        per_language[language] += count
        per_organization[organization] ||= Hash.new(0)
        per_organization[organization][language] += count
      end
    end

    print_aggregate(per_language)
    per_organization.sort_by{|_,counts| counts.values.reduce(:+)}.reverse.each do |organization,counts|
      puts organization
      print_aggregate(counts)
    end
  end
end
