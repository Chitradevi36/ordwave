module Suppliers
  class SoftDeleteSupplierService
    Result = Struct.new(:success?, :supplier, :errors)

    def initialize(supplier:, actor:, reason: nil)
      @supplier = supplier
      @actor    = actor
      @reason   = reason
    end

    def call
      blockers = @supplier.deletion_blockers
      unless blockers.empty?
        return Result.new(false, @supplier, blockers)
      end

      @supplier.soft_delete!

      Credit::AuditLogger.log(
        actor:        @actor,
        organization: @supplier.organization,
        auditable:    @supplier,
        action:       'supplier_deleted',
        changes:      { status: 'inactive', deleted_at: @supplier.deleted_at },
        reason:       @reason
      )

      Result.new(true, @supplier, [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, @supplier, [e.message])
    end
  end
end
