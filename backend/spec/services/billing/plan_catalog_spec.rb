require 'rails_helper'

RSpec.describe Billing::PlanCatalog do
  describe ".for" do
    it "returns the plan hash for a valid plan" do
      plan = described_class.for("starter")
      expect(plan[:display_name]).to eq("Starter")
      expect(plan[:price_monthly_inr]).to eq(1_499)
    end

    it "raises ArgumentError for unknown plan" do
      expect { described_class.for("growth") }.to raise_error(ArgumentError, /Unknown plan/)
    end
  end

  describe ".free?" do
    it "returns true for 'free'" do
      expect(described_class.free?("free")).to be true
    end

    it "returns false for 'starter'" do
      expect(described_class.free?("starter")).to be false
    end
  end

  describe ".paid?" do
    it "returns true for starter and pro" do
      expect(described_class.paid?("starter")).to be true
      expect(described_class.paid?("pro")).to be true
    end

    it "returns false for free" do
      expect(described_class.paid?("free")).to be false
    end
  end

  describe ".valid?" do
    it "returns true for defined plans" do
      %w[free starter pro].each do |p|
        expect(described_class.valid?(p)).to be true
      end
    end

    it "returns false for unknown plans" do
      expect(described_class.valid?("growth")).to be false
      expect(described_class.valid?("enterprise")).to be false
      expect(described_class.valid?("")).to be false
    end
  end

  describe ".all_for_display" do
    it "returns an array with all three plans" do
      result = described_class.all_for_display
      expect(result.map { |p| p[:plan] }).to match_array(%w[free starter pro])
    end

    it "includes display_name for each plan" do
      result = described_class.all_for_display
      expect(result.map { |p| p[:display_name] }).to include("Free", "Starter", "Pro")
    end
  end
end
