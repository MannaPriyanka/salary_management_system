module Bootstrap
  class Error < StandardError; end

  # Creates the initial HR Manager account. It never changes the password of an account that
  # already exists. In production the email and password must come from the environment.
  class HrManager
    def self.call(email:, password:)
      new(email: email, password: password).call
    end

    def initialize(email:, password:)
      @email = email.to_s.strip.downcase
      @password = password.to_s
    end

    def call
      raise Error, "An email is required. Set HR_MANAGER_EMAIL." if @email.blank?

      existing = User.find_by(email: @email)
      return existing if existing

      create_account(resolved_password)
    end

    private

    def create_account(password)
      user = User.new(email: @email, password: password, password_confirmation: password)
      user.save!
      user
    rescue ActiveRecord::RecordInvalid => error
      raise Error, "The HR Manager account is invalid: #{error.record.errors.full_messages.to_sentence}"
    end

    def resolved_password
      if @password.blank?
        raise Error, "A password is required in production. Set HR_MANAGER_PASSWORD." if Rails.env.production?

        return DevelopmentCredentials::PASSWORD
      end

      if Rails.env.production? && @password == DevelopmentCredentials::PASSWORD
        raise Error, "The development password cannot be used in production."
      end

      @password
    end
  end
end
