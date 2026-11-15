require "rails_helper"

RSpec.describe "Reference data", type: :model do
  describe Department do
    subject { Department.new(name: "Finance") }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
  end

  describe Designation do
    subject { Designation.new(name: "Analyst") }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
  end

  describe Country do
    subject { Country.new(code: "IN", name: "India") }

    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:code).case_insensitive }

    it "is active by default" do
      expect(Country.new).to be_active
    end
  end
end
