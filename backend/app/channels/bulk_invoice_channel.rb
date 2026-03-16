# frozen_string_literal: true

# ActionCable channel for bulk invoice generation progress updates.
#
# Usage (Frontend):
#   import consumer from 'channels/consumer'
#
#   const sessionId = 'unique-session-uuid'
#   const subscription = consumer.subscriptions.create(
#     { channel: 'BulkInvoiceChannel', session_id: sessionId },
#     {
#       received: (data) => {
#         if (data.type === 'progress') {
#           updateProgressBar(data.percent, data.message)
#         } else if (data.type === 'complete') {
#           showSuccessAndRedirect()
#         } else if (data.type === 'error') {
#           showError(data.message)
#         }
#       }
#     }
#   )
#
class BulkInvoiceChannel < ApplicationCable::Channel
  def subscribed
    session_id = params['session_id']

    if session_id.blank?
      reject
      return
    end

    # Verify the BulkGeneration exists and belongs to current user's organization
    bulk_gen = BulkGeneration.find_by(session_id: session_id)
    unless bulk_gen && bulk_gen.organization_id == current_user.current_organization&.id
      reject
      return
    end

    stream_from "bulk_invoice_#{session_id}"
  end

  def unsubscribed
    # Any cleanup when user leaves or disconnects
  end
end
