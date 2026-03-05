module Returns
  # Completes QC for a ReturnRequest in qc_in_progress status.
  # For each line, records qty_resalable / qty_damaged / qty_expired.
  # Posts return_received inventory movement for ALL resalable items.
  # Damaged/expired are captured for records only (v1; no damage bucket).
  #
  # Inputs:
  #   qc_lines: [
  #     {
  #       return_line_id:  "...",
  #       qty_resalable:   Numeric,
  #       qty_damaged:     Numeric,
  #       qty_expired:     Numeric,
  #       condition_final: "resalable|damaged|expired|mixed",
  #       qc_notes:        "..."
  #     }
  #   ]
  #
  class CompleteQc
    Result = Struct.new(:success?, :return_request, :errors)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, return_request:, qc_lines:)
      @actor          = actor
      @return_request = return_request
      @qc_lines       = Array(qc_lines)
    end

    def call
      unless @return_request.qc_in_progress?
        return Result.new(false, @return_request, ['Return must be in qc_in_progress status'])
      end

      if @qc_lines.blank?
        return Result.new(false, @return_request, ['QC data for lines is required'])
      end

      ActiveRecord::Base.transaction do
        @qc_lines.each do |qc_attrs|
          attrs = qc_attrs.is_a?(ActionController::Parameters) ? qc_attrs.to_h.deep_symbolize_keys : qc_attrs.symbolize_keys

          line = @return_request.lines.find(attrs[:return_line_id])

          # Validate totals
          resalable = attrs[:qty_resalable].to_d
          damaged   = attrs[:qty_damaged].to_d
          expired   = attrs[:qty_expired].to_d
          total     = resalable + damaged + expired

          if total > line.qty_reported.to_d
            raise ActiveRecord::RecordInvalid.new(line),
                  "QC total (#{total}) exceeds qty_reported (#{line.qty_reported}) for product #{line.product.sku}"
          end

          # Determine condition_final
          condition_final = derive_condition(resalable, damaged, expired, attrs[:condition_final])

          # Create / update QC item
          qc_item = line.qc_item || line.build_qc_item
          qc_item.assign_attributes(
            qc_by:          @actor,
            qty_resalable:  resalable,
            qty_damaged:    damaged,
            qty_expired:    expired,
            condition_final: condition_final,
            qc_notes:       attrs[:qc_notes],
            qc_at:          Time.current
          )
          qc_item.save!

          # Update return_line accepted/rejected totals
          line.update!(
            qty_accepted: resalable,
            qty_rejected: damaged + expired
          )

          # Post inventory movement for resalable units only
          if resalable > 0
            result = Inventory::PostMovement.call(
              org:           @return_request.organization,
              branch:        @return_request.branch,
              product:       line.product,
              movement_type: 'return_received',
              quantity:      resalable,
              reference:     @return_request,
              reference_line_id: line.id,
              unit_cost:     line.unit_price_snapshot,
              actor:         @actor,
              metadata:      {
                return_number: @return_request.return_number,
                condition:     condition_final,
                reason_code:   line.reason_code
              }
            )

            unless result.success?
              raise ActiveRecord::RecordInvalid.new(line),
                    "Inventory posting failed for #{line.product.sku}: #{result.errors.join(', ')}"
            end
          end
        end

        @return_request.transition_to!('qc_completed')

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @return_request.organization,
          auditable:    @return_request,
          action:       'return_qc_completed',
          changes:      {
            status:         'qc_completed',
            qc_completed_at: @return_request.qc_completed_at,
            line_count:     @qc_lines.size
          }
        )

        Result.new(true, @return_request.reload, [])
      end
    rescue ActiveRecord::RecordNotFound => e
      Result.new(false, @return_request, ["Line not found: #{e.message}"])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, @return_request, [e.message])
    end

    private

    def derive_condition(resalable, damaged, expired, override)
      return override.to_s if override.present? && ReturnQcItem::CONDITIONS_FINAL.include?(override.to_s)

      positive_types = [
        resalable > 0 ? 'resalable' : nil,
        damaged   > 0 ? 'damaged'   : nil,
        expired   > 0 ? 'expired'   : nil
      ].compact

      case positive_types.size
      when 0 then 'resalable'
      when 1 then positive_types.first
      else        'mixed'
      end
    end
  end
end
