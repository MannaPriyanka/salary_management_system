require "rails_helper"

RSpec.describe User, type: :model do
  it { is_expected.to validate_presence_of(:email) }

  it "stores email in lower case and rejects duplicates regardless of case" do
    create(:user, email: "HR@Example.TEST")
    expect(User.first.email).to eq("hr@example.test")
    expect(build(:user, email: "hr@example.test")).to be_invalid
  end

  it "stores only a password digest" do
    user = create(:user, password: "a long passphrase")
    expect(user.password_digest).to be_present
    expect(user.password_digest).not_to include("a long passphrase")
  end

  it "requires a password of at least 12 characters" do
    expect(build(:user, password: "short", password_confirmation: "short")).to be_invalid
  end
end
