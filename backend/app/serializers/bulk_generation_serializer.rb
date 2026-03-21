# frozen_string_literal: true

class BulkGenerationSerializer < ActiveModel::Serializer
  attributes :id, :session_id, :total_orders, :completed_orders,
             :error_count, :progress_percent, :errors,
             :created_at, :updated_at

  attribute :progress_percent do
    return 0 if object.total_orders.zero?
    ((object.completed_orders + object.error_count) * 100.0 / object.total_orders).round(0)
  end

  attribute :status do
    if object.completed_orders + object.error_count >= object.total_orders
      'completed'
    else
      'in_progress'
    end
  end
end
