module Api
  module V1
    class HsnSacCodesController < BaseController
      before_action :require_organization!
      before_action :set_hsn_sac_code, only: %i[show update destroy rate_change]

      # GET /api/v1/hsn_sac_codes
      def index
        codes = policy_scope(HsnSacCode)
        codes = apply_filters(codes)
        codes = codes.order(code: :asc, effective_from: :desc)
        paginated = paginate(codes)

        render_success(serialize_collection(paginated), meta: pagination_meta(paginated))
      end

      # GET /api/v1/hsn_sac_codes/:id
      def show
        render_success(serialize(@hsn_sac_code))
      end

      # GET /api/v1/hsn_sac_codes/lookup?code=XXXXXX
      def lookup
        authorize HsnSacCode, :lookup?

        result = Products::HsnLookupService.lookup(params[:code])
        render_success(result)
      end

      # POST /api/v1/hsn_sac_codes
      def create
        authorize HsnSacCode

        code = HsnSacCode.new(code_params)
        if code.save
          render_created(serialize(code))
        else
          render_errors(code.errors)
        end
      end

      # PATCH/PUT /api/v1/hsn_sac_codes/:id
      def update
        if @hsn_sac_code.update(code_params)
          render_success(serialize(@hsn_sac_code))
        else
          render_errors(@hsn_sac_code.errors)
        end
      end

      # DELETE /api/v1/hsn_sac_codes/:id
      # Soft-deactivates: sets active=false and closes the effective window.
      def destroy
        today = Date.current
        if @hsn_sac_code.update(active: false, effective_to: today)
          render_success({ message: 'HSN/SAC code deactivated successfully' })
        else
          render_errors(@hsn_sac_code.errors)
        end
      end

      # POST /api/v1/hsn_sac_codes/:id/rate_change
      # Closes the current record and creates a successor with the new rate.
      def rate_change
        new_rate           = params.require(:gst_rate).to_d
        new_effective_from = Date.parse(params.require(:effective_from).to_s)

        ActiveRecord::Base.transaction do
          # Close existing record
          @hsn_sac_code.update!(effective_to: new_effective_from - 1.day)

          # Create new record with updated rate
          successor = HsnSacCode.create!(
            code:           @hsn_sac_code.code,
            code_type:      @hsn_sac_code.code_type,
            description:    @hsn_sac_code.description,
            chapter:        @hsn_sac_code.chapter,
            gst_rate:       new_rate,
            effective_from: new_effective_from,
            active:         true
          )
          authorize successor, :rate_change?

          render_created(serialize(successor))
        end
      rescue ActionController::ParameterMissing => e
        render_errors([e.message], status: :bad_request)
      rescue ArgumentError => e
        render_errors([e.message], status: :unprocessable_entity)
      rescue ActiveRecord::RecordInvalid => e
        render_errors(e.record.errors)
      end

      # POST /api/v1/hsn_sac_codes/bulk_import
      def bulk_import
        authorize HsnSacCode, :bulk_import?

        unless params[:file].present?
          return render_errors(['file is required'], status: :bad_request)
        end

        result = HsnSacCodes::BulkImportService.new(file: params[:file]).call

        render_success(
          {
            success_count: result.success_count,
            failed_rows:   result.failed_rows,
            message:       "#{result.success_count} records imported successfully"
          }
        )
      end

      private

      def set_hsn_sac_code
        @hsn_sac_code = HsnSacCode.find(params[:id])
        authorize @hsn_sac_code
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'HSN/SAC code not found' }, status: :not_found
      end

      def code_params
        params.require(:hsn_sac_code).permit(
          :code, :code_type, :description, :chapter,
          :gst_rate, :effective_from, :effective_to, :active
        )
      end

      # ---------------------------------------------------------------------------
      # Filters
      # ---------------------------------------------------------------------------
      def apply_filters(scope)
        scope = scope.where('code ILIKE ? OR description ILIKE ?',
                            "%#{params[:q]}%", "%#{params[:q]}%") if params[:q].present?
        scope = scope.with_type(params[:code_type])                if params[:code_type].present?
        scope = scope.with_rate(params[:gst_rate])                 if params[:gst_rate].present?
        scope = (params[:current] == 'true' ? scope.current : scope)
        scope = (params[:active]  == 'false' ? scope.inactive : scope.active) unless params[:active].nil?
        scope
      end

      # ---------------------------------------------------------------------------
      # Serializers
      # ---------------------------------------------------------------------------
      def serialize(record)
        {
          id:             record.id,
          code:           record.code,
          code_type:      record.code_type,
          description:    record.description,
          chapter:        record.chapter,
          gst_rate:       record.gst_rate,
          cgst_rate:      record.cgst_rate,
          sgst_rate:      record.sgst_rate,
          igst_rate:      record.igst_rate,
          active:         record.active,
          current_rate:   record.current_rate?,
          effective_from: record.effective_from,
          effective_to:   record.effective_to,
          created_at:     record.created_at,
          updated_at:     record.updated_at
        }
      end

      def serialize_collection(records)
        records.map { |r| serialize(r) }
      end
    end
  end
end
