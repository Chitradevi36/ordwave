module Api
  module V1
    class CustomersController < BaseController
      before_action :require_organization!

      def index
        scope = policy_scope(Customer)
        scope = apply_filters(scope)
        customers = paginate(scope.includes(:route, :credit_account))

        render_success(
          customers.map { |c| serialize_customer(c) },
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

      def serialize_customer(customer, detailed: false)
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
          sales_rep:         customer.sales_rep ? { id: customer.sales_rep.id, name: customer.sales_rep.name } : nil,
          credit_account:    customer.credit_account ? serialize_credit_account(customer.credit_account) : nil
        }

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
