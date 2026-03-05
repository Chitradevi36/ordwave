require 'csv'

module Api
  module V1
    class CustomersController < BaseController
      before_action :require_organization!

      def index
        scope     = policy_scope(Customer)
        scope     = apply_filters(scope)
        customers = paginate(scope.includes(:route, :credit_account))

        # Batch-compute order exposure when requested — avoids N+1 on list pages.
        credit_usage_map = {}
        if params[:include_credit_usage] == 'true'
          branch_ids = customers.map(&:branch_id).uniq
          branches   = Branch.where(id: branch_ids).index_by(&:id)
          customers.group_by(&:branch_id).each do |bid, group|
            next unless (branch = branches[bid])
            batch = Credit::RetailerCreditUsageService.batch(
              branch:       branch,
              retailer_ids: group.map(&:id)
            )
            credit_usage_map.merge!(batch)
          end
        end

        render_success(
          customers.map { |c| serialize_customer(c, credit_usage: credit_usage_map[c.id]) },
          meta: pagination_meta(customers)
        )
      end

      def show
        customer = Customer.not_deleted
                           .where(organization: current_organization)
                           .includes(:addresses, :contacts, :credit_account, :route)
                           .find(params[:id])
        authorize customer

        render_success(serialize_customer(customer, detailed: true))
      end

      def create
        authorize Customer.new(organization: current_organization)

        result = Customers::CreateCustomerService.new(
          params:       customer_params,
          organization: current_organization,
          branch_id:    customer_params[:branch_id]
        ).call

        if result.success?
          render_created(serialize_customer(result.customer, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      def update
        customer = Customer.not_deleted
                           .where(organization: current_organization)
                           .find(params[:id])
        authorize customer

        result = Customers::UpdateCustomerService.new(
          customer: customer,
          params:   customer_params
        ).call

        if result.success?
          render_success(serialize_customer(result.customer, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      def destroy
        customer = Customer.not_deleted
                           .where(organization: current_organization)
                           .find(params[:id])
        authorize customer

        customer.soft_delete!
        render_success({ message: 'Customer deleted' })
      end

      # GET /api/v1/customers/:id/credit_usage?branch_id=
      # Returns full credit consumption breakdown (invoice outstanding + order exposure).
      def credit_usage
        customer = find_customer
        authorize customer, :credit_usage?

        branch_id = params[:branch_id].presence || customer.branch_id
        branch    = current_organization.branches.find(branch_id)

        usage = Credit::RetailerCreditUsageService.call(
          retailer: customer,
          branch:   branch
        )

        render_success(usage)
      end

      def check_duplicate
        authorize Customer.new(organization: current_organization), :index?
        field      = params[:field].to_s
        value      = params[:value].to_s.strip
        org_id     = current_organization.id
        exclude_id = params[:exclude_id]

        match = case field
                when 'name'  then Customer.dup_by_name(value, org_id)
                when 'phone' then Customer.dup_by_phone(value, org_id)
                when 'gstin' then Customer.dup_by_gstin(value, org_id)
                else Customer.none
                end

        match = match.where.not(id: exclude_id) if exclude_id.present?
        found = match.first
        render json: { exists: found.present?, match: found&.name }
      end

      def block
        customer = find_customer
        authorize customer, :block?
        customer.block!
        render_success(serialize_customer(customer))
      end

      def unblock
        customer = find_customer
        authorize customer, :unblock?
        customer.unblock!
        render_success(serialize_customer(customer))
      end

      def deactivate
        customer = find_customer
        authorize customer, :deactivate?
        customer.deactivate!
        render_success(serialize_customer(customer))
      end

      # GET /api/v1/customers/sample_csv
      def sample_csv
        authorize Customer.new(organization: current_organization), :bulk_import?

        csv_data = CSV.generate do |csv|
          csv << %w[name code channel tier phone email gstin pan
                    credit_limit credit_days route_code branch_code]
          csv << ['Rajesh Stores', 'CUST-001', 'general_trade', 'gold',
                  '9876543210', 'rajesh@example.com', '', '', '50000', '30', '', 'HQ']
          csv << ['Metro Mart', 'CUST-002', 'modern_trade', 'platinum',
                  '9876543211', '', '', '', '100000', '45', '', 'HQ']
        end

        response.headers['Content-Disposition'] = 'attachment; filename="sample_customers.csv"'
        render plain: csv_data, content_type: 'text/csv; charset=utf-8'
      end

      def bulk_import
        authorize Customer.new(organization: current_organization), :bulk_import?

        unless params[:file].present?
          return render_errors(['file is required'], status: :bad_request)
        end

        result = Customers::BulkImportService.new(
          file:         params[:file],
          organization: current_organization
        ).call

        render_success(
          {
            success_count: result.success_count,
            skipped_rows:  result.skipped_rows,
            failed_rows:   result.failed_rows,
            message:       "#{result.success_count} customers imported successfully"
          }
        )
      end

      # GET /api/v1/customers/export_csv
      def export_csv
        authorize Customer.new(organization: current_organization), :index?

        customers = policy_scope(Customer)
                      .includes(:route, :credit_account)
                      .order(name: :asc)
        customers = customers.where('customers.name ILIKE ? OR customers.code ILIKE ? OR customers.phone ILIKE ?',
                                   "%#{params[:q]}%", "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?
        customers = customers.where(channel: params[:channel]) if params[:channel].present?
        customers = customers.where(tier:    params[:tier])    if params[:tier].present?
        customers = customers.where(status:  params[:status])  if params[:status].present?

        csv_data = CSV.generate do |csv|
          csv << %w[code name channel tier status phone email gstin pan
                    credit_limit credit_days route_name route_code]
          customers.find_each do |c|
            csv << [
              c.code,
              c.name,
              c.channel,
              c.tier,
              c.status,
              c.phone,
              c.email,
              c.gstin,
              c.pan,
              c.credit_limit,
              c.credit_days,
              c.route&.name,
              c.route&.code
            ]
          end
        end

        filename = "customers_#{current_organization.slug}_#{Date.current.iso8601}.csv"
        response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
        render plain: csv_data, content_type: 'text/csv; charset=utf-8'
      end

      private

      def apply_filters(scope)
        scope = scope.by_channel(params[:channel])             if params[:channel].present?
        scope = scope.by_route(params[:route_id])              if params[:route_id].present?
        scope = scope.by_tier(params[:tier])                   if params[:tier].present?
        scope = scope.by_customer_type(params[:customer_type]) if params[:customer_type].present?
        scope = scope.by_sales_rep(params[:sales_rep_id])      if params[:sales_rep_id].present?
        scope = scope.where(branch_id: params[:branch_id])     if params[:branch_id].present?
        scope = scope.by_status(params[:status])               if params[:status].present?
        scope = apply_credit_status_filter(scope)              if params[:credit_status].present?
        scope = scope.no_route                                 if params[:no_route] == 'true'
        scope = filter_by_query(scope)                         if params[:q].present?
        scope
      end

      def apply_credit_status_filter(scope)
        case params[:credit_status]
        when 'overdue'     then scope.overdue_customers
        when 'near_limit'  then scope.near_credit_limit
        else scope
        end
      end

      def filter_by_query(scope)
        q = "%#{params[:q].strip}%"
        scope.where('customers.name ILIKE :q OR customers.code ILIKE :q OR customers.phone ILIKE :q', q: q)
      end

      def find_customer
        Customer.not_deleted.where(organization: current_organization).find(params[:id])
      end

      def customer_params
        params.require(:customer).permit(
          :name, :code, :channel, :tier, :route_id, :branch_id, :sales_rep_id,
          :credit_limit, :credit_days, :credit_block_rule, :opening_balance,
          :gstin, :pan, :phone, :email, :status,
          :customer_type, :visit_frequency,
          tag_list: [],
          addresses_attributes: %i[id label line1 line2 city state postal_code country latitude longitude _destroy],
          contacts_attributes:  %i[id name phone email designation is_primary _destroy]
        )
      end

      def serialize_customer(customer, detailed: false, credit_usage: nil)
        data = {
          id:                customer.id,
          name:              customer.name,
          code:              customer.code,
          customer_type:     customer.customer_type,
          channel:           customer.channel,
          tier:              customer.tier,
          status:            customer.status,
          phone:             customer.phone,
          email:             customer.email,
          gstin:             customer.gstin,
          pan:               customer.pan,
          credit_limit:      customer.credit_limit,
          credit_days:       customer.credit_days,
          credit_block_rule: customer.credit_block_rule,
          opening_balance:   customer.opening_balance,
          visit_frequency:   customer.visit_frequency,
          tag_list:          customer.tag_list || [],
          branch_id:         customer.branch_id,
          route:             customer.route ? { id: customer.route.id, name: customer.route.name, code: customer.route.code } : nil,
          sales_rep:         customer.sales_rep ? { id: customer.sales_rep.id, name: customer.sales_rep.full_name } : nil,
          credit_account:    customer.credit_account ? serialize_credit_account(customer.credit_account) : nil,
        }

        # Include order-exposure enrichment when batch data is supplied.
        if credit_usage
          ca_balance = customer.credit_account&.current_balance.to_f
          data[:credit_usage_summary] = {
            order_exposure:    credit_usage[:order_exposure],
            hold_exposure:     credit_usage[:hold_exposure],
            credit_used_total: (ca_balance + credit_usage[:order_exposure]).round(2),
          }
        end

        if detailed
          data[:addresses] = customer.addresses.map { |a| serialize_address(a) }
          data[:contacts]  = customer.contacts.map  { |c| serialize_contact(c) }
        end

        data
      end

      def serialize_credit_account(ca)
        {
          id:              ca.id,
          credit_limit:    ca.credit_limit,
          current_balance: ca.current_balance,
          available_credit: ca.available_credit,
          overdue_amount:  ca.overdue_amount,
          overdue_days:    ca.overdue_days
        }
      end

      def serialize_address(address)
        {
          id:          address.id,
          label:       address.label,
          line1:       address.line1,
          line2:       address.line2,
          city:        address.city,
          state:       address.state,
          postal_code: address.postal_code,
          country:     address.country,
          latitude:    address.latitude,
          longitude:   address.longitude
        }
      end

      def serialize_contact(contact)
        {
          id:          contact.id,
          name:        contact.name,
          phone:       contact.phone,
          email:       contact.email,
          designation: contact.designation,
          is_primary:  contact.is_primary
        }
      end
    end
  end
end
