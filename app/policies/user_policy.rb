class UserPolicy < ApplicationPolicy
  def index? = permission?("users:read")
  def show?  = permission?("users:read")
  def create? = permission?("users:write")

  # Capability from the table AND a record-level rule: you may edit yourself,
  # or anyone if you're an admin.
  def update? = permission?("users:write") && (record.id == user.id || admin?)
  def destroy? = permission?("users:delete") && admin?

  class Scope < Scope
    def resolve
      if user&.permission?("users:read")
        scope.kept
      else
        scope.none
      end
    end
  end
end
