class Employee < ApplicationRecord
  STATUSES = %w[active on_leave exited].freeze

  belongs_to :department
  belongs_to :designation
  belongs_to :country
  has_many :salary_revisions, dependent: :restrict_with_error

  normalizes :work_email, with: ->(email) { email.strip.downcase }

  validates :employee_code, presence: true, uniqueness: true
  validates :full_name, presence: true, length: { maximum: 200 }
  validates :work_email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :employment_status, inclusion: { in: STATUSES }
  validates :joining_date, presence: true
  validates :exit_date, presence: true, if: :exited?
  validate :exit_date_after_joining_date
  validate :archived_only_when_exited
  validate :employee_code_is_immutable, on: :update
  validate :joining_date_keeps_revisions_valid, on: :update

  def exited?
    employment_status == "exited"
  end

  def archived?
    archived_at.present?
  end

  # Archiving is allowed only for exited employees (BR-14). Salary history is not touched.
  def archive!
    self.archived_at = Time.current
    save!
  end

  # The latest revision whose effective date is on or before the given date.
  def current_salary_revision(on: Date.current)
    salary_revisions.where(effective_date: ..on).order(effective_date: :desc).first
  end

  private

  def exit_date_after_joining_date
    return if exit_date.blank? || joining_date.blank?

    errors.add(:exit_date, "must be after the joining date") if exit_date <= joining_date
  end

  def archived_only_when_exited
    return unless archived? && !exited?

    errors.add(:archived_at, "can only be set for an exited employee")
  end

  def employee_code_is_immutable
    errors.add(:employee_code, "cannot be changed") if will_save_change_to_employee_code?
  end

  def joining_date_keeps_revisions_valid
    return unless will_save_change_to_joining_date? && joining_date.present?
    return unless salary_revisions.where(effective_date: ...joining_date).exists?

    errors.add(:joining_date, "is after an existing salary revision; correct the revisions first")
  end
end
