namespace :accounts do
  desc "Create the initial HR Manager account. Production needs HR_MANAGER_EMAIL and HR_MANAGER_PASSWORD."
  task bootstrap_hr_manager: :environment do
    email = ENV["HR_MANAGER_EMAIL"].presence || (Rails.env.production? ? nil : "hr.manager@example.test")
    user = Bootstrap::HrManager.call(email: email, password: ENV["HR_MANAGER_PASSWORD"])
    puts "HR Manager account ready: #{user.email}"
  end
end
