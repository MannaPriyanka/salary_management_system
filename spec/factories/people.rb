FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "hr#{n}@example.test" }
    password { "correct horse battery staple" }
    password_confirmation { password }
  end

  factory :employee do
    association :department
    association :designation
    association :country
    sequence(:employee_code) { |n| format("EMP%05d", n) }
    sequence(:work_email) { |n| "employee#{n}@example.test" }
    full_name { "Test Employee" }
    employment_status { "active" }
    joining_date { Date.new(2020, 1, 1) }
    exit_date { nil }

    trait :exited do
      employment_status { "exited" }
      exit_date { Date.new(2024, 6, 30) }
    end
  end

  factory :salary_revision do
    association :employee
    association :recorded_by, factory: :user
    currency_code { "INR" }
    base_amount { BigDecimal("100000.00") }
    effective_date { Date.new(2021, 1, 1) }
    reason { "Annual review" }
  end

  factory :revision_component do
    association :salary_revision
    component_type { "allowance" }
    currency_code { salary_revision.currency_code }
    amount { BigDecimal("5000.00") }
  end

  factory :audit_log do
    occurred_at { Time.utc(2026, 11, 15, 10, 0, 0) }
    action { "create" }
    entity_type { "Employee" }
    entity_id { "1" }
  end
end
