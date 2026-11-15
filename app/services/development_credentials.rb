# Development and test accounts use a well-known password. Production must never run with it
# (security design §11). This module is the single place that knows that value.
module DevelopmentCredentials
  PASSWORD = "development-only-password-do-not-use".freeze

  class Refused < StandardError; end

  module_function

  # Raises when running in production and any account still uses the development password.
  def check_production!
    return unless Rails.env.production?
    return unless User.connection.data_source_exists?(User.table_name)

    User.find_each do |user|
      next unless user.authenticate(PASSWORD)

      raise Refused, "An account uses the development password. Change it before starting in production."
    end
  end
end
