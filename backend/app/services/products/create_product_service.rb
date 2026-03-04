module Products
  class CreateProductService
    Result = Struct.new(:success?, :product, :errors)

    def initialize(params:, organization:)
      @params       = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
      @organization = organization
    end

    def call
      # gst_rate is auto-filled by Product#auto_fill_gst_from_hsn callback;
      # consumer may override by passing gst_rate explicitly.
      product = Product.new(@params.merge(organization: @organization))

      if product.save
        Result.new(true, product, [])
      else
        Result.new(false, nil, product.errors.full_messages)
      end
    end
  end
end
