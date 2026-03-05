module Suppliers
  class UpdateSupplierService
    Result = Struct.new(:success?, :supplier, :errors)

    def initialize(supplier:, params:, actor:)
      @supplier = supplier
      @params   = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
      @actor    = actor
    end

    def call
      gstin_before  = @supplier.gstin
      status_before = @supplier.status

      if @supplier.update(@params)
        log_updates(gstin_before, status_before)
        Result.new(true, @supplier, [])
      else
        Result.new(false, @supplier, @supplier.errors.full_messages)
      end
    end

    private

    def log_updates(gstin_before, status_before)
      organization = @supplier.organization

      # Always log general update
      Credit::AuditLogger.log(
        actor:        @actor,
        organization: organization,
        auditable:    @supplier,
        action:       'supplier_updated',
        changes:      @supplier.previous_changes.except('updated_at')
      )

      # Log specific GSTIN change for compliance audit trail
      if @supplier.gstin != gstin_before
        Credit::AuditLogger.log(
          actor:        @actor,
          organization: organization,
          auditable:    @supplier,
          action:       'supplier_gstin_changed',
          changes:      { gstin: [gstin_before, @supplier.gstin] }
        )
      end

      # Log blacklisting as separate event
      if @supplier.blacklisted? && status_before != 'blacklisted'
        Credit::AuditLogger.log(
          actor:        @actor,
          organization: organization,
          auditable:    @supplier,
          action:       'supplier_blacklisted',
          changes:      { status: [status_before, 'blacklisted'] }
        )
      end
    end
  end
end
