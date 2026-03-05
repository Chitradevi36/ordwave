module Api
  module V1
    class VehiclesController < BaseController
      before_action :require_organization!
      before_action :set_vehicle, only: %i[show update destroy]

      # GET /api/v1/vehicles
      def index
        vehicles = policy_scope(Vehicle).includes(:default_driver)
        vehicles = vehicles.by_type(params[:vehicle_type]) if params[:vehicle_type].present?
        vehicles = vehicles.where(status: params[:status])  if params[:status].present?
        vehicles = paginate(vehicles.order(created_at: :desc))

        render_success(vehicles.map { |v| serialize_vehicle(v) },
                       meta: pagination_meta(vehicles))
      end

      # GET /api/v1/vehicles/:id
      def show
        authorize @vehicle
        render_success(serialize_vehicle(@vehicle))
      end

      # POST /api/v1/vehicles
      def create
        authorize Vehicle.new(organization: current_organization), :create?

        vehicle = Vehicle.new(vehicle_params.merge(organization: current_organization))
        if vehicle.save
          Credit::AuditLogger.log(
            actor:        current_user,
            organization: current_organization,
            auditable:    vehicle,
            action:       'vehicle_created',
            changes:      { registration_number: vehicle.registration_number }
          )
          render_created(serialize_vehicle(vehicle))
        else
          render_errors(vehicle.errors.full_messages)
        end
      end

      # PATCH /api/v1/vehicles/:id
      def update
        authorize @vehicle
        if @vehicle.update(vehicle_params)
          Credit::AuditLogger.log(
            actor:        current_user,
            organization: current_organization,
            auditable:    @vehicle,
            action:       'vehicle_updated',
            changes:      @vehicle.previous_changes.except('updated_at')
          )
          render_success(serialize_vehicle(@vehicle))
        else
          render_errors(@vehicle.errors.full_messages)
        end
      end

      # DELETE /api/v1/vehicles/:id
      def destroy
        authorize @vehicle
        @vehicle.soft_delete!
        Credit::AuditLogger.log(
          actor:        current_user,
          organization: current_organization,
          auditable:    @vehicle,
          action:       'vehicle_deleted',
          changes:      { deleted_at: @vehicle.deleted_at }
        )
        render_success({ message: 'Vehicle deleted' })
      rescue ActiveRecord::RecordInvalid => e
        render_errors([e.message])
      end

      private

      def set_vehicle
        @vehicle = policy_scope(Vehicle).find(params[:id])
      end

      def vehicle_params
        params.require(:vehicle).permit(
          :registration_number, :vehicle_type, :capacity_kg, :capacity_units,
          :default_driver_id, :insurance_expiry, :fitness_expiry, :permit_expiry,
          :status, :notes
        )
      end

      def serialize_vehicle(v)
        {
          id:                    v.id,
          registration_number:   v.registration_number,
          vehicle_type:          v.vehicle_type,
          capacity_kg:           v.capacity_kg,
          capacity_units:        v.capacity_units,
          status:                v.status,
          insurance_expiry:      v.insurance_expiry,
          fitness_expiry:        v.fitness_expiry,
          permit_expiry:         v.permit_expiry,
          notes:                 v.notes,
          default_driver:        v.default_driver ? { id: v.default_driver.id, name: v.default_driver.full_name } : nil,
          created_at:            v.created_at,
          updated_at:            v.updated_at
        }
      end
    end
  end
end
