module Api
  module V1
    class RoutesController < BaseController
      before_action :require_organization!

      def index
        scope    = policy_scope(Route)
        scope    = scope.where(branch_id: params[:branch_id]) if params[:branch_id].present?
        scope    = filter_by_query(scope)                      if params[:q].present?
        routes   = paginate(scope)

        render_success(
          routes.map { |r| serialize_route(r) },
          meta: pagination_meta(routes)
        )
      end

      def show
        route = Route.for_org(current_organization.id).find(params[:id])
        authorize route

        render_success(serialize_route(route, detailed: true))
      end

      def create
        authorize Route.new(organization: current_organization)

        route = Route.new(route_params.merge(organization: current_organization))

        if route.save
          render_created(serialize_route(route))
        else
          render_errors(route.errors.full_messages)
        end
      end

      def update
        route = Route.for_org(current_organization.id).find(params[:id])
        authorize route

        if route.update(route_params)
          render_success(serialize_route(route))
        else
          render_errors(route.errors.full_messages)
        end
      end

      def destroy
        route = Route.for_org(current_organization.id).find(params[:id])
        authorize route

        if route.update(active: false)
          render_success({ message: 'Route deactivated' })
        else
          render_errors(route.errors.full_messages)
        end
      end

      private

      def filter_by_query(scope)
        q = "%#{params[:q].strip}%"
        scope.where('routes.name ILIKE :q OR routes.code ILIKE :q', q: q)
      end

      def route_params
        params.require(:route).permit(:name, :code, :branch_id, :active)
      end

      def serialize_route(route, detailed: false)
        data = {
          id:        route.id,
          name:      route.name,
          code:      route.code,
          active:    route.active,
          branch_id: route.branch_id
        }
        data[:customers_count] = route.customers.not_deleted.count if detailed
        data
      end
    end
  end
end
