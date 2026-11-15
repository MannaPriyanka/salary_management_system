require "rails_helper"

RSpec.describe Bootstrap::HrManager do
  let(:email) { "hr.admin@example.test" }
  let(:strong_password) { "a sufficiently long passphrase" }

  def as_environment(name)
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new(name))
  end

  it "creates the HR Manager account in development with the development password when none is given" do
    as_environment("development")
    user = described_class.call(email: email, password: nil)
    expect(user.authenticate(DevelopmentCredentials::PASSWORD)).to be_truthy
  end

  it "requires an explicit password in production" do
    as_environment("production")
    expect { described_class.call(email: email, password: nil) }.to raise_error(Bootstrap::Error, /password/)
    expect(User.count).to eq(0)
  end

  it "refuses the development password in production" do
    as_environment("production")
    expect { described_class.call(email: email, password: DevelopmentCredentials::PASSWORD) }
      .to raise_error(Bootstrap::Error, /development/)
    expect(User.count).to eq(0)
  end

  it "creates the account in production when a strong password is supplied" do
    as_environment("production")
    user = described_class.call(email: email, password: strong_password)
    expect(user).to be_persisted
  end

  it "does not reset the password of an existing account" do
    as_environment("production")
    described_class.call(email: email, password: strong_password)
    described_class.call(email: email, password: "a different passphrase here")
    expect(User.find_by(email: email).authenticate(strong_password)).to be_truthy
  end
end
