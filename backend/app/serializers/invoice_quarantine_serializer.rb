# frozen_string_literal: true

class InvoiceQuarantineSerializer < ActiveModel::Serializer
  attributes :id, :organization_id, :trip_stop_id, :sales_order_id, :branch_id,
             :error_message, :retry_count, :last_retry_at, :status,
             :resolved_at, :resolved_by_id, :created_at, :updated_at

  attribute :days_in_quarantine do
    object.days_in_quarantine
  end

  attribute :quarantine_urgent do
    object.quarantine_urgent?
  end

  attribute :customer_name do
    object.customer&.name
  end

  attribute :order_number do
    object.order_number
  end

  attribute :trip_number do
    object.trip_number
  end

  attribute :order_total do
    object.sales_order&.total_amount
  end

  attribute :error_summary do
    # First 100 chars of error for quick scanning
    object.error_message&.truncate(100)
  end

  has_one :sales_order, serializer: SalesOrderBaseSerializer
  has_one :trip_stop, serializer: TripStopSerializer
  has_one :resolved_by, serializer: UserSerializer
end
