# Basic protection against password guessing (ADR-0006, security design §6).
# State is keyed by the normalised email, whether or not an account exists, so the
# response never reveals which emails are registered. Values are provisional defaults.
class SignInProtection
  MAX_FAILURES = 5
  FAILURE_WINDOW = 15.minutes
  REFUSAL_PERIOD = 15.minutes

  class << self
    # Time until which sign-in for this email is refused, or nil when allowed.
    def refused_until(email, now: Time.current)
      state = read(email)
      state[:refused_until] if state[:refused_until] && state[:refused_until] > now
    end

    def record_failure(email, now: Time.current)
      state = read(email)
      if state[:first_failed_at].nil? || state[:first_failed_at] <= now - FAILURE_WINDOW
        state = { failures: 0, first_failed_at: now, refused_until: nil }
      end

      state[:failures] += 1
      if state[:failures] >= MAX_FAILURES
        state = { failures: 0, first_failed_at: nil, refused_until: now + REFUSAL_PERIOD }
      end

      write(email, state)
    end

    def clear(email)
      Rails.cache.delete(key(email))
    end

    private

    def key(email)
      "sign_in_protection:#{email}"
    end

    def read(email)
      Rails.cache.read(key(email)) || { failures: 0, first_failed_at: nil, refused_until: nil }
    end

    def write(email, state)
      Rails.cache.write(key(email), state, expires_in: FAILURE_WINDOW + REFUSAL_PERIOD)
    end
  end
end
