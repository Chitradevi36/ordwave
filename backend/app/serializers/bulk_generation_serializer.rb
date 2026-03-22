# frozen_string_literal: true

class BulkGenerationSerializer < BaseSerializer
  def serialize
    progress = object.total_orders.zero? ? 0 : ((object.completed_orders + object.error_count) * 100.0 / object.total_orders).round(0)
    status = object.completed_orders + object.error_count >= object.total_orders ? 'completed' : 'in_progress'
    
    {
      id: object.id,
      session_id: object.session_id,
      total_orders: object.total_orders,
      completed_orders: object.completed_orders,
      error_count: object.error_count,
      progress_percent: progress,
      errors: object.errors,
      created_at: object.created_at,
      updated_at: object.updated_at,
      status: status
    }
  end
end
