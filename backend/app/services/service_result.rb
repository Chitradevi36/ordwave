# Standardized result object for service methods
# Provides consistent interface for returning success/failure status with data
#
# Example usage:
#   class MyService
#     include ServiceResult
#
#     def call
#       success(data: { value: 123 }, message: "Operation successful")
#     end
#   end
#
#   result = MyService.new.call
#   result.success?  # => true
#   result.data      # => { value: 123 }
#   result.message   # => "Operation successful"

module ServiceResult
  class Result
    attr_reader :success, :data, :message, :error, :error_code

    def initialize(success:, data: nil, message: nil, error: nil, error_code: nil)
      @success = success
      @data = data
      @message = message
      @error = error
      @error_code = error_code
    end

    def success?
      @success == true
    end

    def failure?
      !success?
    end

    def to_h
      {
        success: success?,
        data: @data,
        message: @message,
        error: @error,
        error_code: @error_code
      }.compact
    end

    def to_json(options = {})
      to_h.to_json(options)
    end
  end

  # Return a successful result
  def success(data: nil, message: nil)
    Result.new(success: true, data: data, message: message)
  end

  # Return a failed result
  def failure(message:, data: nil, error: nil, error_code: nil)
    Result.new(
      success: false,
      data: data,
      message: message,
      error: error,
      error_code: error_code
    )
  end

  # Return a failed result with validation errors
  def validation_error(message:, errors: {}, data: nil)
    Result.new(
      success: false,
      data: data,
      message: message,
      error: errors,
      error_code: 'VALIDATION_ERROR'
    )
  end
end
