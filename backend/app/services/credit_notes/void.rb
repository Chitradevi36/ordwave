module CreditNotes
  # Voids an issued CreditNote (owner only).
  # Does NOT reverse inventory movements — those are permanently recorded in the ledger.
  # Marks the credit note as void with a required reason.
  #
  class Void
    Result = Struct.new(:success?, :credit_note, :errors)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, credit_note:, reason:)
      @actor       = actor
      @credit_note = credit_note
      @reason      = reason
    end

    def call
      unless @credit_note.issued?
        return Result.new(false, @credit_note, ["Only issued credit notes can be voided (current: #{@credit_note.status})"])
      end

      if @reason.blank?
        return Result.new(false, @credit_note, ['Void reason is required'])
      end

      ActiveRecord::Base.transaction do
        @credit_note.update!(
          status:     'void',
          voided_at:  Time.current,
          void_reason: @reason
        )

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @credit_note.organization,
          auditable:    @credit_note,
          action:       'credit_note_voided',
          changes:      {
            credit_note_number: @credit_note.credit_note_number,
            void_reason:        @reason
          }
        )

        Result.new(true, @credit_note, [])
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, @credit_note, [e.message])
    end
  end
end
