require 'rails_helper'

RSpec.describe OnboardingProgress, type: :model do
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:user) }
  end

  describe '#mark_step_complete!' do
    let(:progress) { create(:onboarding_progress) }

    it 'marks a step as complete' do
      progress.mark_step_complete!('add_first_product')
      
      expect(progress.step_completed?('add_first_product')).to be true
    end

    it 'marks onboarding as completed when all steps are done' do
      OnboardingProgress::CHECKLIST_STEPS.each do |step|
        progress.mark_step_complete!(step)
      end

      expect(progress.completed).to be true
      expect(progress.completed_at).to be_present
    end
  end

  describe '#completion_percentage' do
    let(:progress) { create(:onboarding_progress) }

    it 'returns 0 when no steps are complete' do
      expect(progress.completion_percentage).to eq(0)
    end

    it 'returns correct percentage' do
      progress.mark_step_complete!('add_first_product')
      
      expected = (1.0 / OnboardingProgress::CHECKLIST_STEPS.size * 100).round
      expect(progress.completion_percentage).to eq(expected)
    end
  end
end
