class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  belongs_to :branch
  belongs_to :role
end
