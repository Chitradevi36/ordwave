# frozen_string_literal: true

module Accounting
  # Public facade for the accounting sync pipeline.
  #
  # All OMS model callbacks and application code should call Router, not the
  # internal dispatch/sync services directly.
  #
  # Every method is fire-and-forget from the caller's perspective.
  # Results are logged but do not raise to the caller.
  #
  # Usage from model callback:
  #   after_commit { Accounting::Router.enqueue_invoice(self) if issued? }
  #
  # Usage from service object:
  #   Accounting::Router.enqueue_invoice(invoice, event_type: "invoice_updated")
  module Router
    module_function

    # ------------------------------------------------------------------
    # Sales voucher entities
    # ------------------------------------------------------------------

    def enqueue_invoice(invoice, event_type: "invoice_issued")
      dispatch(entity: invoice, event_type: event_type)
    end

    def enqueue_credit_note(credit_note, event_type: "credit_note_issued")
      dispatch(entity: credit_note, event_type: event_type)
    end

    def enqueue_purchase_invoice(purchase_invoice, event_type: "purchase_invoice_posted")
      dispatch(entity: purchase_invoice, event_type: event_type)
    end

    # ------------------------------------------------------------------
    # Payment / receipt voucher entities
    # ------------------------------------------------------------------

    def enqueue_payment(payment, event_type: "payment_recorded")
      dispatch(entity: payment, event_type: event_type)
    end

    # ------------------------------------------------------------------
    # Master data entities
    # ------------------------------------------------------------------

    def enqueue_retailer(retailer, event_type: "retailer_synced")
      dispatch(entity: retailer, event_type: event_type)
    end

    def enqueue_supplier(supplier, event_type: "supplier_synced")
      dispatch(entity: supplier, event_type: event_type)
    end

    def enqueue_product(product, event_type: "product_synced")
      dispatch(entity: product, event_type: event_type)
    end

    # ------------------------------------------------------------------
    # Internal dispatcher
    # ------------------------------------------------------------------

    # @param entity     [Object]
    # @param event_type [String]
    # @param provider   [String, nil]
    # @return [Accounting::Result::DispatchResult]
    def dispatch(entity:, event_type:, provider: nil)
      result = Router::DispatchService.new(
        entity:     entity,
        event_type: event_type,
        provider:   provider
      ).call

      log_result(result, entity: entity, event_type: event_type)
      result
    end

    # -----------------------------------------------------------------------
    private
    # -----------------------------------------------------------------------

    def log_result(result, entity:, event_type:)
      tag = "[Accounting::Router] #{entity.class.name}##{entity.try(:id)} event=#{event_type}"

      case result.status
      when :enqueued      then Rails.logger.info("#{tag} → enqueued sync_record##{result.sync_record&.id}")
      when :no_integration then Rails.logger.debug("#{tag} → no active integration, skipped")
      when :duplicate     then Rails.logger.debug("#{tag} → duplicate, skipped")
      when :skipped       then Rails.logger.debug("#{tag} → skipped: #{result.message}")
      when :error         then Rails.logger.warn("#{tag} → error: #{result.message}")
      end
    end
  end
end
