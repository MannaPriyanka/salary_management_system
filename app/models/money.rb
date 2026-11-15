# Exact decimal helpers for money (ADR-0005). Never uses floats.
module Money
  module_function

  # True when the amount has no more decimal places than the currency allows.
  # Trailing zeros do not count. Values are never rounded here.
  def within_precision?(amount, minor_units)
    decimals = amount.to_d.to_s("F").split(".", 2)[1].to_s.sub(/0+\z/, "")
    decimals.length <= minor_units
  end

  # Formats an amount as a JSON string with exactly the currency's decimal places.
  # Raises if the amount has more decimal places than allowed, so nothing is rounded silently.
  def to_json_string(amount, minor_units)
    raise ArgumentError, "amount has more decimal places than #{minor_units} allows" unless within_precision?(amount, minor_units)

    whole, fraction = amount.to_d.to_s("F").split(".", 2)
    return whole if minor_units.zero?

    "#{whole}.#{fraction.to_s.ljust(minor_units, '0')}"
  end
end
