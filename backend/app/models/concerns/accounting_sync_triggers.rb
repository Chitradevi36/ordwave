# frozen_string_literal: true

# Thin mixin that wires OMS model after_commit callbacks to the accounting
# sync pipeline.
#
# Usage:
#   Include this concern in any model that should push to accounting on change.
#   Then call the class-level DSL method once per trigger you need:
#
#   class SalesInvoice < ApplicationRecord
#     include AccountingSyncTriggers
#
#     accounting_sync_trigger(
#       event_type: "invoice_issued",
#       on:         [:create, :update],
#       if:         :sync_to_accounting?
#     )
#
#     def sync_to_accounting?
#       issued? || partially_paid?
#     end
#   end
#
# Design principles:
#   - Callbacks only delegate to Accounting::Router.  Zero accounting logic here.
#   - `if:` guard methods are pure predicates on the model.
#   - Only after_commit is used — no after_save/after_create — to ensure the
#     DB transaction is committed before the job reads the entity.
#   - Multiple triggers can be registered on the same model.
#
module AccountingSyncTriggers
  extend ActiveSupport::Concern

  included do
    class_attribute :_accounting_sync_triggers, default: []
  end

  module ClassMethods
    # Register an accounting sync trigger for this model.
    #
    # @param event_type [String]        e.g. "invoice_issued"
    # @param on         [Array<Symbol>] [:create], [:update], or [:create, :update]
    # @param if         [Symbol, Proc]  guard predicate (instance method name or proc)
    def accounting_sync_trigger(event_type:, on: %i[create update], if: nil)
      guard    = binding.local_variable_get(:if)
      triggers = Array(on).map(&:to_sym)

      # Accumulate without clobbering inherited triggers.
      self._accounting_sync_triggers = _accounting_sync_triggers.dup

      triggers.each do |lifecycle|
        trigger_config = { event_type: event_type, guard: guard }
        _accounting_sync_triggers << trigger_config

        # Register the after_commit callback inline.
        method_name = :"_accounting_sync_#{lifecycle}_#{event_type.parameterize(separator: '_')}"

        define_method(method_name) do
          trigger_accounting_sync!(event_type: event_type, guard: guard)
        end
        private method_name

        after_commit method_name, on: lifecycle
      end
    end
  end

  # -----------------------------------------------------------------------
  # Instance helpers
  # -----------------------------------------------------------------------

  # Called by the registered after_commit callback.
  # Checks the guard predicate, then delegates to Accounting::Router.
  def trigger_accounting_sync!(event_type:, guard: nil)
    return unless accounting_sync_guard_passes?(guard)

    Accounting::Router.dispatch(entity: self, event_type: event_type)
  rescue => e
    # Never let accounting trigger crash the model callback.
    Rails.logger.error(
      "[AccountingSyncTriggers] #{self.class.name}##{id} trigger failed " \
      "for event=#{event_type}: #{e.class}: #{e.message}"
    )
  end

  # -----------------------------------------------------------------------
  private
  # -----------------------------------------------------------------------

  def accounting_sync_guard_passes?(guard)
    return true if guard.nil?

    case guard
    when Symbol then public_send(guard)
    when Proc   then instance_exec(&guard)
    else true
    end
  end
end
