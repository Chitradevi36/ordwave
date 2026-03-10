module Api
  module V1
    class SyncController < BaseController
      before_action :require_organization!

      skip_after_action :verify_authorized
      skip_after_action :verify_policy_scoped

      # GET /api/v1/sync/delta
      # Params:
      #   since         — ISO8601 datetime, defaults to 24 hours ago
      #   entity_types  — comma-separated: customers,products,price_list_items
      def delta
        since        = parse_since(params[:since])
        entity_types = (params[:entity_types].presence || 'customers,products').split(',').map(&:strip)

        data   = {}
        counts = {}

        entity_types.each do |type|
          case type
          when 'customers'
            scope    = policy_scope(Customer).where(organization: current_organization)
            upserted = scope.where('customers.updated_at > ?', since)
                           .includes(:credit_account, :addresses)
                           .map { |c| serialize_customer_for_sync(c) }
            deleted  = Customer.only_deleted
                                .where(organization: current_organization)
                                .where('deleted_at > ?', since)
                                .pluck(:id)
            data[:customers] = { upserted: upserted, deleted_ids: deleted }
            counts[:customers] = upserted.size

          when 'products'
            scope    = current_organization.products
            upserted = scope.where('products.updated_at > ?', since)
                            .includes(:category, :uom, :hsn)
                            .map { |p| serialize_product_for_sync(p) }
            deleted  = Product.only_deleted
                               .where(organization: current_organization)
                               .where('deleted_at > ?', since)
                               .pluck(:id)
            data[:products] = { upserted: upserted, deleted_ids: deleted }
            counts[:products] = upserted.size

          when 'price_list_items'
            active_list_ids = current_organization.price_lists.where(status: 'active').pluck(:id)
            upserted = PriceListItem.where(price_list_id: active_list_ids)
                                    .where('price_list_items.updated_at > ?', since)
                                    .includes(:product, :price_list)
                                    .map { |i| serialize_price_item_for_sync(i) }
            data[:price_list_items] = { upserted: upserted, deleted_ids: [] }
            counts[:price_list_items] = upserted.size
          end
        end

        render_success(data, meta: {
          server_time:   Time.current.iso8601,
          has_more:      false,
          entity_types:  entity_types,
          counts:        counts
        })
      end

      # POST /api/v1/sync/push
      # Body: { operations: [{ idempotency_key, entity_type, operation, payload }, ...] }
      def push
        operations = params[:operations]

        unless operations.is_a?(Array) && operations.any?
          return render json: { errors: ['operations must be a non-empty array'] }, status: :unprocessable_entity
        end

        results = operations.map do |op|
          process_operation(op.to_unsafe_h)
        end

        render_success({ results: results })
      end

      private

      def parse_since(raw)
        return 24.hours.ago if raw.blank?
        Time.parse(raw)
      rescue ArgumentError
        24.hours.ago
      end

      def process_operation(op)
        idempotency_key = op['idempotency_key'].to_s

        # Check if already processed
        existing = SyncOperation.find_by(idempotency_key: idempotency_key)
        if existing&.succeeded?
          return { idempotency_key: idempotency_key, status: 'success', server_id: existing.server_id }
        end

        result = execute_operation(op, idempotency_key)

        # Persist the sync operation record
        SyncOperation.upsert(
          {
            idempotency_key: idempotency_key,
            organization_id: current_organization.id,
            user_id:         current_user.id,
            entity_type:     op['entity_type'].to_s,
            operation:       op['operation'].to_s,
            payload:         op['payload'] || {},
            status:          result[:status],
            server_id:       result[:server_id],
            error_message:   result[:error_message],
            processed_at:    Time.current,
            created_at:      Time.current,
            updated_at:      Time.current
          },
          unique_by: :idempotency_key
        )

        result
      rescue StandardError => e
        Rails.logger.error("[SyncController#push] Unhandled error for key=#{op['idempotency_key']}: #{e.message}")
        { idempotency_key: op['idempotency_key'].to_s, status: 'error', error_message: e.message }
      end

      def execute_operation(op, idempotency_key)
        case "#{op['entity_type']}.#{op['operation']}"
        when 'order.create'
          payload  = (op['payload'] || {}).with_indifferent_access
          customer = Customer.not_deleted.where(organization: current_organization).find(payload[:customer_id])
          branch   = current_organization.branches.find(payload[:branch_id])

          ActiveRecord::Base.transaction do
            draft_result = Orders::DraftUpsertService.call(
              actor:        current_user,
              organization: current_organization,
              branch:       branch,
              customer:     customer,
              params:       payload,
              order:        nil
            )
            raise draft_result[:errors].join(', ') unless draft_result[:ok]

            submit_result = Orders::SubmitOrderService.call(
              actor:           current_user,
              order:           draft_result[:order],
              idempotency_key: idempotency_key
            )
            raise submit_result[:errors].join(', ') unless submit_result[:ok]

            order = submit_result[:order]
            { idempotency_key: idempotency_key, status: 'success', server_id: order.id, order_number: order.order_number }
          end

        when 'payment.create'
          payload = (op['payload'] || {}).with_indifferent_access
          customer = Customer.not_deleted.where(organization: current_organization).find(payload[:customer_id])
          payment = Payment.create!(
            organization: current_organization,
            branch:       current_organization.branches.find(payload[:branch_id]),
            customer:     customer,
            amount:       payload[:amount],
            mode:         payload[:mode] || 'cash',
            reference_number: payload[:reference_number],
            notes:        payload[:notes],
            payment_date: payload[:payment_date].present? ? Date.parse(payload[:payment_date]) : Date.current,
            collected_by: current_user,
            status:       'collected'
          )
          { idempotency_key: idempotency_key, status: 'success', server_id: payment.id }

        else
          { idempotency_key: idempotency_key, status: 'error', error_message: "Unknown operation: #{op['entity_type']}.#{op['operation']}" }
        end
      rescue StandardError => e
        { idempotency_key: idempotency_key, status: 'error', error_message: e.message }
      end

      def serialize_customer_for_sync(c)
        ca = c.credit_account
        addr = c.addresses.find { |a| a.address_type == 'billing' } || c.addresses.first
        {
          id: c.id, name: c.name, code: c.code, channel: c.channel, tier: c.tier,
          status: c.status, phone: c.phone, gstin: c.gstin, updated_at: c.updated_at,
          credit_account: ca ? {
            current_balance: ca.current_balance.to_f,
            credit_limit:    ca.credit_limit.to_f,
            overdue_amount:  ca.overdue_amount.to_f,
            overdue_days:    ca.overdue_days,
            blocked:         ca.blocked?,
            hold_required:   ca.hold_required?,
            watchlist:       ca.watchlist?,
            collection_first: ca.collection_first?
          } : nil,
          address: addr ? "#{addr.line1}, #{addr.city}" : nil
        }
      end

      def serialize_product_for_sync(p)
        {
          id: p.id, sku: p.sku, name: p.name, status: p.status,
          gst_rate: p.gst_rate.to_f, min_order_qty: p.min_order_qty,
          updated_at: p.updated_at,
          category: p.category ? { name: p.category.name } : nil,
          uom:      p.uom      ? { name: p.uom.name, symbol: p.uom.symbol } : nil,
          hsn:      p.hsn      ? { code: p.hsn.code } : nil
        }
      end

      def serialize_price_item_for_sync(i)
        {
          id:            i.id,
          product_id:    i.product_id,
          price_list_id: i.price_list_id,
          unit_price:    i.unit_price.to_f,
          min_qty:       i.min_qty,
          discount_pct:  i.discount_pct.to_f,
          updated_at:    i.updated_at,
          product:       i.product ? { sku: i.product.sku, name: i.product.name } : nil,
          price_list:    i.price_list ? { name: i.price_list.name, list_type: i.price_list.list_type } : nil
        }
      end
    end
  end
end
