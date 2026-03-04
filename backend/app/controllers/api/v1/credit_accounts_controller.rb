module Api
  module V1
    class CreditAccountsController < BaseController
      before_action :require_organization!

      def show
        credit_account = CreditAccount.where(organization: current_organization)
                                      .find(params[:id])
        authorize credit_account

        ageing = Credit::AgeingCalculator.new(customer: credit_account.customer).call

        render_success({
          id:               credit_account.id,
          customer_id:      credit_account.customer_id,
          credit_limit:     credit_account.credit_limit,
          current_balance:  credit_account.current_balance,
          available_credit: credit_account.available_credit,
          overdue_amount:   credit_account.overdue_amount,
          overdue_days:     credit_account.overdue_days,
          ageing:           ageing
        })
      end

      def update
        credit_account = CreditAccount.where(organization: current_organization)
                                      .find(params[:id])
        authorize credit_account

        if credit_account.update(credit_account_params)
          render_success({
            id:               credit_account.id,
            credit_limit:     credit_account.credit_limit,
            current_balance:  credit_account.current_balance,
            available_credit: credit_account.available_credit,
            overdue_amount:   credit_account.overdue_amount,
            overdue_days:     credit_account.overdue_days
          })
        else
          render_errors(credit_account.errors.full_messages)
        end
      end

      # PATCH /api/v1/credit_accounts/:id/flags
      def update_flags
        credit_account = CreditAccount.where(organization: current_organization)
                                      .find(params[:id])
        authorize credit_account, :update_flags?

        previous_flags = {
          collection_first: credit_account.collection_first,
          hold_required:    credit_account.hold_required,
          watchlist:        credit_account.watchlist
        }

        if credit_account.update(flag_params)
          changed = flag_params.to_h.select { |k, v| previous_flags[k.to_sym] != v }
          unless changed.empty?
            Credit::AuditLogger.log(
              actor:        current_user,
              organization: current_organization,
              auditable:    credit_account,
              action:       'flag_changed',
              changes:      { from: previous_flags, to: flag_params.to_h },
              reason:       params[:reason]
            )
          end
          render_success({
            id:               credit_account.id,
            collection_first: credit_account.collection_first,
            hold_required:    credit_account.hold_required,
            watchlist:        credit_account.watchlist
          })
        else
          render_errors(credit_account.errors.full_messages)
        end
      end

      private

      def credit_account_params
        params.require(:credit_account).permit(:credit_limit, :current_balance, :overdue_amount, :overdue_days)
      end

      def flag_params
        params.require(:credit_account).permit(:collection_first, :hold_required, :watchlist)
      end
    end
  end
end
