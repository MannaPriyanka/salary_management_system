require "rails_helper"

RSpec.describe Money do
  describe ".within_precision?" do
    it "allows values with no more decimal places than the currency" do
      expect(Money.within_precision?(BigDecimal("12.34"), 2)).to be(true)
      expect(Money.within_precision?(BigDecimal("12.3"), 2)).to be(true)
      expect(Money.within_precision?(BigDecimal("12"), 0)).to be(true)
    end

    it "rejects extra decimal places" do
      expect(Money.within_precision?(BigDecimal("12.345"), 2)).to be(false)
      expect(Money.within_precision?(BigDecimal("12.5"), 0)).to be(false)
    end

    it "ignores trailing zeros" do
      expect(Money.within_precision?(BigDecimal("12.3400"), 2)).to be(true)
    end
  end

  describe ".to_json_string" do
    it "formats an amount as a string with the currency's decimal places" do
      expect(Money.to_json_string(BigDecimal("125000"), 2)).to eq("125000.00")
      expect(Money.to_json_string(BigDecimal("500"), 0)).to eq("500")
    end
  end
end
