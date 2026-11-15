FactoryBot.define do
  factory :currency do
    sequence(:code) { |n| %w[INR USD EUR GBP][n % 4] }
    name { "Test currency" }
    minor_units { 2 }
    enabled { true }
    initialize_with { Currency.find_or_initialize_by(code: code) }
  end

  factory :country do
    sequence(:code) { |n| "C#{n}" }
    sequence(:name) { |n| "Country #{n}" }
    active { true }
  end

  factory :department do
    sequence(:name) { |n| "Department #{n}" }
    active { true }
  end

  factory :designation do
    sequence(:name) { |n| "Designation #{n}" }
    active { true }
  end
end
