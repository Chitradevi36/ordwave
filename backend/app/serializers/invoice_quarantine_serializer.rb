# frozen_string_literal: true

class InvoiceQuarantineSerializer < BaseSerializer
  def serialize
    {
      id: object.id,
      organization_id: object.organization_id,
      trip_stop_id: object.trip_stop_id,
      sales_order_id: object.sales_order_id,
      branch_id: object.branch_id,
      error_message: object.error_message,
      retry_count: object.retry_count,
      last_retry_at: object.last_retry_at,
      status: object.status,
      resolved_at: object.resolved_at,
      resolved_by_id: object.resolved_by_id,
      created_at: object.created_at,
      updated_at: object.updated_at,
      days_in_quarantine: object.days_in_quarantine,
      quarantine_urgent: object.quarantine_urgent?,
      customer_name: object.customer&.name,
      order_number: object.order_number,
      trip_number: object.trip_number,
      order_total: object.sales_order&.total_amount,
      error_summary: object.error_message&.truncate(100),
      sales_order: object.sales_order.present? ? { id: object.sales_order.id } : nil,
      trip_stop: object.trip_stop.present? ? { id: object.trip_stop.id } : nil,
      resolved_by: object.resolved_by.present? ? { id: object.resolved_by.id, name: object.resolved_by.name } : nil
    }
  end
end
