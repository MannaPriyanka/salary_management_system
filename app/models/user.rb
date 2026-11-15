class User < ApplicationRecord
  # Used to spend the same bcrypt time for unknown emails, so timing does not reveal accounts.
  PLACEHOLDER_DIGEST = BCrypt::Password.create("placeholder-password-for-timing").freeze

  has_secure_password

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }, allow_nil: true

  def self.authenticate_unknown(password)
    PLACEHOLDER_DIGEST.is_password?(password.to_s)
    false
  end
end
