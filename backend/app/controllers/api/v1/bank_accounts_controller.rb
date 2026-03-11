# frozen_string_literal: true

module Api
  module V1
    class BankAccountsController < BaseController
      before_action :set_bank_account, only: %i[show update]

      def index
        accounts = policy_scope(BankAccount).active.order(:bank_name)
        render json: accounts, each_serializer: BankAccountSerializer
      end

      def show
        authorize @bank_account
        render json: @bank_account, serializer: BankAccountSerializer
      end

      def create
        @bank_account = BankAccount.new(bank_account_params)
        @bank_account.organization = Current.organization

        authorize @bank_account

        if @bank_account.save
          render json: @bank_account, serializer: BankAccountSerializer, status: :created
        else
          render json: { errors: @bank_account.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        authorize @bank_account

        if @bank_account.update(bank_account_params)
          render json: @bank_account, serializer: BankAccountSerializer
        else
          render json: { errors: @bank_account.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_bank_account
        @bank_account = policy_scope(BankAccount).find(params[:id])
      end

      def bank_account_params
        params.require(:bank_account).permit(
          :branch_id, :bank_name, :account_holder_name, :account_number,
          :ifsc_code, :account_type, :currency, :status
        )
      end
    end
  end
end
