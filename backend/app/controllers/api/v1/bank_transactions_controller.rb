# frozen_string_literal: true

module Api
  module V1
    class BankTransactionsController < BaseController
      before_action :set_txn, only: %i[show confirm_match mark_as_advance ignore retry_match]

      # GET /api/v1/bank_transactions/queue
      # Returns unmatched transaction queue with AI suggestions for quick assignment
      def queue
        result = BankReconciliation::UnmatchedQueueQuery.call(
          organization:    Current.organization,
          bank_account_id: params[:bank_account_id],
          date_from:       params[:date_from].present? ? Date.parse(params[:date_from]) : nil,
          date_to:         params[:date_to].present? ? Date.parse(params[:date_to]) : nil,
          limit:           params[:limit] || 25
        )

        render json: {
          data: {
            transactions: result.transactions,
            meta: {
              total_unmatched: result.total_count,
              total_amount_unmatched: result.total_amount,
              oldest_unmatched_date: result.oldest_date,
              urgency_flag: result.total_count > 50 # If more than 50 unmatched, flag as urgent
            }
          }
        }
      end

      # GET /api/v1/bank_transactions/dashboard
      def dashboard
        summary = BankReconciliation::ImportDashboardQuery.call(
          organization:    Current.organization,
          bank_account_id: params[:bank_account_id],
          date_from:       params[:date_from],
          date_to:         params[:date_to]
        )

        render json: {
          data: {
            total_credits_imported: summary.total_credits_imported,
            total_amount_imported:  summary.total_amount_imported,
            auto_matched:  { count: summary.auto_matched_count,  amount: summary.auto_matched_amount },
            needs_review:  { count: summary.needs_review_count,  amount: summary.needs_review_amount },
            unmatched:     { count: summary.unmatched_count,     amount: summary.unmatched_amount },
            confirmed:     { count: summary.confirmed_count,     amount: summary.confirmed_amount },
            duplicates:    { count: summary.duplicates_count },
            ignored:       { count: summary.ignored_count },
            recent_imports: summary.recent_imports
          }
        }
      end

      # GET /api/v1/bank_transactions?status=suggested&bank_account_id=1
      def index
        txns = policy_scope(BankTransaction)
                 .includes(:matched_customer, :matched_invoice, candidates: %i[customer sales_invoice])
                 .order(transaction_date: :desc)

        txns = txns.where(status: params[:status])                    if params[:status].present?
        txns = txns.where(bank_account_id: params[:bank_account_id]) if params[:bank_account_id].present?
        txns = txns.where(direction: params[:direction])              if params[:direction].present?

        txns = txns.page(params[:page]).per(params[:per_page] || 25)

        render json: txns, each_serializer: BankTransactionSerializer,
               meta: pagination_meta(txns)
      end

      def show
        authorize @txn
        render json: @txn, serializer: BankTransactionSerializer
      end

      # POST /api/v1/bank_transactions/:id/quick_assign
      # Executes one of the suggested actions from the unmatched queue
      # Body: { action_type: 'mark_as_advance', customer_id: X }
      def quick_assign
        authorize @txn, :confirm_match? # Same permissions as confirm_match

        result = BankReconciliation::QuickAssignService.call(
          bank_transaction: @txn,
          action_type: params.require(:action_type),
          customer_id: params[:customer_id],
          invoice_id: params[:invoice_id],
          user: Current.user
        )

        if result.success?
          render json: {
            data: @txn.reload,
            message: result.message
          }, serializer: BankTransactionSerializer
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/bank_transactions/:id/confirm_match
      # Body: { allocations: [{ invoice_id: X, amount: Y }, ...] }
      def confirm_match
        authorize @txn, :confirm_match?

        allocations = (params[:allocations] || []).map do |a|
          { invoice_id: a[:invoice_id].to_i, amount: a[:amount].to_d }
        end

        result = BankReconciliation::PostingService.call(
          bank_transaction: @txn,
          allocations:      allocations,
          reviewed_by:      Current.user
        )

        if result.success?
          render json: @txn.reload, serializer: BankTransactionSerializer
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/bank_transactions/:id/mark_as_advance
      # Creates an AdvancePayment for the full transaction amount
      def mark_as_advance
        authorize @txn, :mark_as_advance?

        customer = Customer.find_by!(
          organization: Current.organization,
          id:           params.require(:customer_id)
        )

        ActiveRecord::Base.transaction do
          payment = Payment.create!(
            organization:     Current.organization,
            branch:           @txn.bank_account.branch,
            customer:         customer,
            amount:           @txn.amount,
            payment_mode:     :bank_transfer,
            received_date:    @txn.txn_date,
            reference_number: @txn.utr_number.presence || @txn.reference_number,
            notes:            "Advance payment from bank reconciliation. Narration: #{@txn.narration}",
            created_by:       Current.user
          )

          AdvancePayment.create!(
            organization:   Current.organization,
            customer:       customer,
            amount:         @txn.amount,
            source_payment: payment,
            notes:          "Marked as advance from bank recon txn ##{@txn.id}"
          )

          @txn.update!(
            status:              :matched,
            matched_customer_id: customer.id,
            matched_payment_id:  payment.id,
            reviewed_by_id:      Current.user.id,
            processed_at:        Time.current
          )
        end

        render json: @txn.reload, serializer: BankTransactionSerializer
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: [e.message] }, status: :unprocessable_entity
      end

      # POST /api/v1/bank_transactions/:id/ignore
      def ignore
        authorize @txn, :ignore?

        @txn.update!(
          status:         :ignored,
          reviewed_by_id: Current.user.id,
          processed_at:   Time.current
        )

        render json: @txn, serializer: BankTransactionSerializer
      end

      # POST /api/v1/bank_transactions/:id/retry_match
      def retry_match
        authorize @txn, :retry_match?

        @txn.update!(status: :unmatched, match_score: nil, match_rule: nil,
                     matched_customer_id: nil, matched_invoice_id: nil)

        result = BankReconciliation::Matcher.call(@txn, Current.organization)

        render json: @txn.reload, serializer: BankTransactionSerializer,
               status: :ok,
               meta:   { new_status: result.status }
      end

      private

      def set_txn
        @txn = policy_scope(BankTransaction)
                 .includes(candidates: %i[customer sales_invoice])
                 .find(params[:id])
      end
    end
  end
end
