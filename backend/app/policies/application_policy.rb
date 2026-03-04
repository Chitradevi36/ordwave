class ApplicationPolicy
  attr_reader :user_context, :record

  def initialize(user_context, record)
    @user_context = user_context
    @user         = user_context.user
    @organization = user_context.organization
    @record       = record
  end

  def index?   = false
  def show?    = false
  def create?  = false
  def update?  = false
  def destroy? = false

  protected

  def member?
    membership.present?
  end

  def membership
    @membership ||= @user&.membership_for(@organization)
  end

  def role_name
    membership&.role&.name
  end

  def owner?          = role_name == 'owner'
  def admin?          = role_name == 'admin'
  def manager?        = role_name == 'manager'
  def owner_or_admin? = role_name.in?(%w[owner admin])
  def manager_above?  = role_name.in?(%w[owner admin manager])

  class Scope
    def initialize(user_context, scope)
      @user_context = user_context
      @user         = user_context.user
      @organization = user_context.organization
      @scope        = scope
    end

    def resolve
      @scope.none
    end

    private

    attr_reader :user_context, :user, :organization, :scope
  end
end
