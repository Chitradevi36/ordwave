module Beats
  class CreateBeatService
    Result = Struct.new(:success?, :beat, :errors)

    def initialize(params:, actor:, organization:, branch_id:)
      @params       = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
      @actor        = actor
      @organization = organization
      @branch_id    = branch_id
    end

    def call
      beat = Beat.new(
        name:            @params[:name],
        code:            @params[:code]&.upcase,
        notes:           @params[:notes],
        route_id:        @params[:route_id],
        active:          @params.fetch(:active, true),
        organization:    @organization,
        branch_id:       @branch_id,
        created_by:      @actor
      )

      if beat.save
        AuditLog.create!(
          actor:        @actor,
          organization: @organization,
          auditable:    beat,
          action:       'beat_created',
          changes:      { name: beat.name, code: beat.code }
        )
        Result.new(true, beat, [])
      else
        Result.new(false, nil, beat.errors.full_messages)
      end
    end
  end
end
