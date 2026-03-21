# frozen_string_literal: true

module Api
  module V1
    module Webhooks
      class TwilioController < BaseController
        skip_before_action :authenticate_request! # Webhook doesn't have JWT
        skip_before_action :set_current_organization # No user context

        # Feature 10: Handle incoming SMS messages (customer replies to delivery failure notification)
        # Webhook called by Twilio when customer replies to SMS
        #
        # Twilio sends:
        #   - From: Customer phone number
        #   - Body: Message text ("DECLINE", "RESCHEDULE", etc.)
        #   - MessageSid: Unique message ID
        #   - AccountSid: Twilio account ID (for validation)
        def sms_reply
          # Validate Twilio signature (security check)
          unless validate_twilio_request
            render json: { error: 'Invalid request signature' }, status: :unauthorized
            return
          end

          phone_number = params[:From]
          message_body = params[:Body]&.strip&.upcase
          message_sid = params[:MessageSid]

          # Find customer by phone number
          customer = Customer.find_by(phone: phone_number)
          unless customer
            log_warn("SMS reply: Customer not found for phone #{phone_number}")
            return twilio_response  # Return empty response to prevent Twilio retry
          end

          # Find active reschedule delivery for this customer
          reschedule = RescheduleDelivery
                        .where(customer: customer)
                        .where(status: %w[pending rescheduled])
                        .order(created_at: :desc)
                        .first

          unless reschedule
            log_warn("SMS reply: No active reschedule found for customer #{customer.id}")
            return twilio_response
          end

          # Handle customer response
          process_customer_response(reschedule, message_body, message_sid, phone_number)

          render xml: twilio_response
        end

        private

        def process_customer_response(reschedule, message_body, message_sid, phone_number)
          log_info("SMS reply received from #{phone_number}: #{message_body} (SID: #{message_sid})")

          case message_body
          when 'DECLINE'
            handle_decline_response(reschedule)
          when /RESCHEDULE|CHANGE DATE/
            handle_reschedule_request(reschedule)
          else
            handle_unknown_response(reschedule, phone_number)
          end

          # Log SMS reply in notification_data
          notification_data = reschedule.notification_data || {}
          notification_data['customer_reply'] = {
            message: message_body,
            received_at: Time.current.iso8601,
            twilio_message_sid: message_sid
          }
          reschedule.update(notification_data: notification_data)
        rescue StandardError => error
          log_error("Error processing customer SMS reply for reschedule #{reschedule.id}", error)
        end

        def handle_decline_response(reschedule)
          # Customer declined the rescheduled date
          # Mark as needing attention from operations team
          notification_data = reschedule.notification_data || {}
          notification_data['customer_declined_reschedule'] = {
            declined_at: Time.current.iso8601,
            declined_date: reschedule.next_retry_date
          }
          reschedule.update(notification_data: notification_data)

          # Create notification for operations team
          organization = reschedule.organization
          managers = User.joins(:memberships)
                         .where(memberships: { organization_id: organization.id, active: true })
                         .joins(memberships: :role)
                         .where(roles: { name: %w[manager admin] })
                         .distinct

          managers.each do |manager|
            Notification.create(
              organization: organization,
              user: manager,
              title: 'Customer Declined Rescheduled Delivery',
              body: "Order #{reschedule.sales_order.order_number} from #{reschedule.customer.name}. " \
                    "Customer declined reschedule date of #{reschedule.next_retry_date.strftime('%b %d')}. " \
                    "Please contact customer to arrange alternative.",
              notification_type: 'delivery_declined',
              deep_link_url: "/orders/#{reschedule.sales_order.id}?action=rescheduled_delivery",
              severity: 'high'
            )
          end

          log_info("Delivery decline recorded for reschedule #{reschedule.id}")
        end

        def handle_reschedule_request(reschedule)
          # Customer wants to reschedule to a different date
          # Mark for operations team to contact customer
          notification_data = reschedule.notification_data || {}
          notification_data['customer_wants_reschedule'] = {
            requested_at: Time.current.iso8601,
            original_scheduled_date: reschedule.next_retry_date
          }
          reschedule.update(notification_data: notification_data)

          log_info("Reschedule request recorded for reschedule #{reschedule.id}")
        end

        def handle_unknown_response(reschedule, phone_number)
          # Customer replied but message wasn't recognized
          # Send help message
          if TwilioClient.enabled?
            help_message = "Reply with: DECLINE (to cancel), or call #{reschedule.organization.phone || 'support'} for other options."
            TwilioClient.send_sms(phone_number: phone_number, message: help_message)
          end

          log_info("Unknown SMS response from #{phone_number}: handling with help message")
        end

        # Validate that the request came from Twilio
        # Twilio signs requests with an HMAC hash of the request body + auth token
        def validate_twilio_request
          # Get the URL from the request (Twilio includes this in signature)
          url = request.base_url + request.path
          # Get the request body
          body_string = request.body.string
          # Reset the body stream so action controllers can read it
          request.body.rewind
          
          # Calculate the expected signature
          expected_signature = calculate_twilio_signature(url, body_string)
          
          # Compare with the signature from header
          signature_from_header = request.headers['X-Twilio-Signature']
          
          # Secure compare to prevent timing attacks
          ActiveSupport::SecurityUtils.secure_compare(
            expected_signature.to_s,
            signature_from_header.to_s
          )
        rescue StandardError => e
          log_warn("Twilio signature validation failed: #{e.message}")
          false
        end

        def calculate_twilio_signature(url, body)
          auth_token = ENV.fetch('TWILIO_AUTH_TOKEN', '')
          # Twilio signature is Base64(HMAC-SHA1(url + body, auth_token))
          data = url + body
          OpenSSL::HMAC.digest(
            OpenSSL::Digest.new('sha1'),
            auth_token,
            data
          ).encode('base64').strip
        end

        def twilio_response
          # Return empty TwiML response (tells Twilio we processed the message)
          '<?xml version="1.0" encoding="UTF-8"?><Response></Response>'
        end

        def log_info(message)
          Rails.logger.info({
            controller: 'Api::V1::Webhooks::TwilioController',
            action: 'sms_reply',
            message: message,
            timestamp: Time.current
          }.to_json)
        end

        def log_warn(message)
          Rails.logger.warn({
            controller: 'Api::V1::Webhooks::TwilioController',
            action: 'sms_reply',
            message: message,
            timestamp: Time.current
          }.to_json)
        end

        def log_error(message, error)
          Rails.logger.error({
            controller: 'Api::V1::Webhooks::TwilioController',
            action: 'sms_reply',
            message: message,
            error: error.message,
            backtrace: error.backtrace[0..4]
          }.to_json)
        end
      end
    end
  end
end
