namespace :seed do
  desc "Create deterministic synthetic data (10,000 employees by default). Repeatable. Set EMPLOYEE_COUNT to change the size."
  task synthetic: :environment do
    count = Integer(ENV.fetch("EMPLOYEE_COUNT", SyntheticSeed::DEFAULT_EMPLOYEE_COUNT))
    puts SyntheticSeed.call(employee_count: count).inspect
  end
end
