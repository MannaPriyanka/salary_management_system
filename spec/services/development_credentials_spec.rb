require "rails_helper"

RSpec.describe DevelopmentCredentials do
  def as_environment(name)
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new(name))
  end

  it "does nothing outside production" do
    create(:user, password: DevelopmentCredentials::PASSWORD)
    as_environment("development")
    expect { described_class.check_production! }.not_to raise_error
  end

  it "refuses to start in production when an account uses the development password" do
    create(:user, password: DevelopmentCredentials::PASSWORD)
    as_environment("production")
    expect { described_class.check_production! }.to raise_error(DevelopmentCredentials::Refused)
  end

  it "passes in production when no account uses the development password" do
    create(:user, password: "a sufficiently long passphrase")
    as_environment("production")
    expect { described_class.check_production! }.not_to raise_error
  end
end
