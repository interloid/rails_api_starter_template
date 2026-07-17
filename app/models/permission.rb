class Permission < ApplicationRecord
  has_many :role_permissions, dependent: :destroy
  has_many :roles, through: :role_permissions

  validates :name, presence: true, uniqueness: true
  validates :resource, :action, presence: true

  # name is always "resource:action"
  before_validation { self.name = "#{resource}:#{action}" if resource.present? && action.present? }
end
