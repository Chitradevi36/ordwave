module Products
  class UpdateProductService
    Result = Struct.new(:success?, :product, :errors)

    def initialize(product:, params:)
      @product = product
      @params  = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
    end

    def call
      # Product#auto_fill_gst_from_hsn callback fires when hsn_sac_code_id changes,
      # overwriting gst_rate with the master value unless caller explicitly passes gst_rate.
      # If caller also passes gst_rate, assign it AFTER the update so it wins.
      explicit_gst = @params.delete(:gst_rate)

      if @product.update(@params)
        if explicit_gst.present?
          @product.update_column(:gst_rate, explicit_gst.to_d)
        end
        Result.new(true, @product.reload, [])
      else
        Result.new(false, @product, @product.errors.full_messages)
      end
    end
  end
end
