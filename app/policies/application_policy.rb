class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  # Default deny — policies must explicitly grant.
  def index?   = false
  def show?    = false
  def create?  = false
  def update?  = false
  def destroy? = false

  private

  # Bridges Pundit to the Section 7 permissions table (resource:action names).
  def permission?(name) = user&.permission?(name)
  def admin? = user&.role?("admin")

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve = scope.none   # default deny
  end
end
