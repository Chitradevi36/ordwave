# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankReconciliation::NarrationNormalizer do
  describe ".call" do
    subject(:result) { described_class.call(narration) }

    context "with a UTR and invoice number" do
      let(:narration) { "NEFT INWARD/UTR:HDFC52312345678/INV/2025/001/RAVI TRADERS" }

      it "extracts the invoice number" do
        expect(result.invoice_numbers).to include("INV/2025/001")
      end

      it "extracts the UTR candidate" do
        expect(result.utr_candidates).to include("HDFC52312345678")
      end

      it "extracts tokens" do
        expect(result.tokens).to include("NEFT", "INWARD")
      end
    end

    context "with a retailer code" do
      let(:narration) { "UPI/RT001/RAVI TRADERS PAYMENT" }

      it "extracts the retailer code" do
        expect(result.customer_codes).to include("RT001")
      end
    end

    context "with a phone fragment" do
      let(:narration) { "TRANSFER FROM 9876543210 RAHUL" }

      it "extracts the phone fragment" do
        expect(result.phone_fragments).to include("9876543210")
      end
    end

    context "with empty input" do
      let(:narration) { "" }

      it { expect(result.invoice_numbers).to be_empty }
      it { expect(result.utr_candidates).to be_empty }
      it { expect(result.tokens).to be_empty }
    end

    context "with nil input" do
      let(:narration) { nil }

      it "returns an empty result without error" do
        expect { result }.not_to raise_error
      end
    end
  end
end
