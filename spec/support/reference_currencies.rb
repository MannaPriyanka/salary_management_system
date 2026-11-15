# Specs need the MVP currencies (INR, USD, EUR, GBP) to exist, because
# revisions and components look them up by code. FactoryBot builds associations
# without saving them, so the currencies are created here before each model example.
RSpec.configure do |config|
  config.before(:each) do
    { "INR" => 2, "USD" => 2, "EUR" => 2, "GBP" => 2 }.each do |code, minor_units|
      Currency.find_or_create_by!(code: code) do |currency|
        currency.name = code
        currency.minor_units = minor_units
        currency.enabled = true
      end
    end
  end
end
