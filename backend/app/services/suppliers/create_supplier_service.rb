module Suppliers
  class CreateSupplierService
    Result = Struct.new(:success?, :supplier, :errors)

    def initialize(params:, organization:, actor:)
      @params       = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
      @organization = organization
      @actor        = actor
    end

    def call
      supplier = Supplier.new(@params.merge(organization: @organization))

      if supplier.save
        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @organization,
          auditable:    supplier,
          action:       'supplier_created',
          changes:      { name: supplier.name, code: supplier.code, status: supplier.status }
        )
        Result.new(true, supplier, [])
      else
        Result.new(false, nil, supplier.errors.full_messages)
      end
    end
  end
end
