class Currency < ApplicationRecord
  validates :code, presence: true, uniqueness: true, format: { with: /\A[A-Z]{3}\z/, message: "must be three uppercase letters" }
  validates :name, presence: true
  validates :minor_units, inclusion: { in: 0..4 }
end
