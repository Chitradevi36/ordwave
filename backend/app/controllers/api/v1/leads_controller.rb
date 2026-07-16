module Api
  module V1
    class LeadsController < ActionController::API
      def demo_request
        payload = lead_params.to_h

        required = %w[name email company phone message]
        missing = required.select { |key| payload[key].blank? }
        unless missing.empty?
          return render json: { errors: ["Missing required fields: #{missing.join(', ')}"] }, status: :unprocessable_entity
        end

        LeadMailer.demo_request(payload).deliver_now

        render json: {
          data: {
            message: 'Demo request submitted successfully'
          }
        }, status: :ok
      rescue StandardError => e
        Rails.logger.error("LeadsController#demo_request failed: #{e.class} #{e.message}")
        render json: { errors: ['Unable to submit request at the moment. Please try again.'] }, status: :internal_server_error
      end

      private

      def lead_params
        params.permit(:name, :email, :company, :phone, :message, :source)
      end
    end
  end
end
