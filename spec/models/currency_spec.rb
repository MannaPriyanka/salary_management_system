require "rails_helper"

RSpec.describe Currency, type: :model do
  subject { Currency.new(code: "CAD", name: "Canadian dollar", minor_units: 2, enabled: true) }

  it { is_expected.to validate_presence_of(:code) }
  it { is_expected.to validate_uniqueness_of(:code) }
  it { is_expected.to validate_inclusion_of(:minor_units).in_array([ 0, 1, 2, 3, 4 ]) }

  it "accepts only three-letter uppercase ISO codes" do
    expect(build(:currency, code: "usd")).to be_invalid
    expect(build(:currency, code: "US")).to be_invalid
    expect(build(:currency, code: "USDX")).to be_invalid
  end

  it "is enabled only when marked so" do
    expect(build(:currency, enabled: false)).not_to be_enabled
  end
end
