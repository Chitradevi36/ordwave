module Returns
  # Transitions a submitted ReturnRequest into qc_in_progress.
  #
  class StartQc
    Result = Struct.new(:success?, :return_request, :errors)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, return_request:)
      @actor          = actor
      @return_request = return_request
    end

    def call
      unless @return_request.submitted?
        return Result.new(false, @return_request, ['Only submitted returns can start QC'])
      end

      ActiveRecord::Base.transaction do
        @return_request.transition_to!('qc_in_progress')

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @return_request.organization,
          auditable:    @return_request,
          action:       'return_qc_started',
          changes:      { status: 'qc_in_progress' }
        )

        Result.new(true, @return_request, [])
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, @return_request, [e.message])
    end
  end
end
