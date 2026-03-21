# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeliveryFailureNotificationJob, type: :job do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization: organization, phone: '+91-9876543210', email: 'customer@example.com') }
  let(:order) { create(:sales_order, organization: organization, customer: customer, total_amount: 5000) }
  let(:trip) { create(:delivery_trip, organization: organization) }
  let(:stop) { create(:trip_stop, delivery_trip: trip, sales_order: order) }
  let(:reschedule) do
    create(:reschedule_delivery,
           organization: organization, 
           trip_stop: stop,
           sales_order: order,
           customer: customer,
           failure_code: 'customer_not_available',
           next_retry_date: Date.current + 3.days,
           status: 'pending')
  end

  describe '#perform' do
    context 'with valid reschedule delivery' do
      it 'sends SMS notification to customer' do
        allow(TwilioClient).to receive(:enabled?).and_return(true)
        expect(TwilioClient).to receive(:send_sms).with(
          phone_number: customer.phone,
          message: include('rescheduled')
        ).and_return(double(sid: 'SM1234567890'))

        DeliveryFailureNotificationJob.perform(reschedule.id)
        
        # Verify notification_data was updated
        expect(reschedule.reload.notification_data['failure_notification_sent_at']).to be_present
      end

      it 'sends email notification to customer' do
        expect(DeliveryMailer).to receive(:delivery_failed_notification)
          .with(order, customer, reschedule.next_retry_date, organization)
          .and_return(double(deliver_later: true))

        DeliveryFailureNotificationJob.perform(reschedule.id)
      end

      it 'creates in-app notification' do
        allow(TwilioClient).to receive(:enabled?).and_return(false)
        allow(DeliveryMailer).to receive(:delivery_failed_notification).and_return(double(deliver_later: true))
        
        customer.update(main_contact_user_id: create(:user, organization: organization).id)
        
        expect {
          DeliveryFailureNotificationJob.perform(reschedule.id)
        }.to change { Notification.count }.by(1)
        
        notification = Notification.last
        expect(notification.title).to include('Delivery Update')
        expect(notification.notification_type).to eq('delivery_failed')
      end

      it 'prevents duplicate notifications on same day' do
        # First notification
        allow(TwilioClient).to receive(:enabled?).and_return(true)
        expect(TwilioClient).to receive(:send_sms).once

        DeliveryFailureNotificationJob.perform(reschedule.id)
        
        # Second attempt on same day
        expect(TwilioClient).not_to receive(:send_sms)
        DeliveryFailureNotificationJob.perform(reschedule.id)
      end
    end

    context 'with missing customer' do
      before { reschedule.update(customer: nil) }

      it 'skips notification gracefully' do
        expect(TwilioClient).not_to receive(:send_sms)
        expect {
          DeliveryFailureNotificationJob.perform(reschedule.id)
        }.not_to raise_error
      end
    end

    context 'with Twilio disabled' do
      before { allow(TwilioClient).to receive(:enabled?).and_return(false) }

      it 'falls back to email only' do
        expect(TwilioClient).not_to receive(:send_sms)
        expect(DeliveryMailer).to receive(:delivery_failed_notification).and_return(double(deliver_later: true))

        DeliveryFailureNotificationJob.perform(reschedule.id)
      end
    end

    context 'with missing phone' do
      before { customer.update(phone: nil) }

      it 'sends email but not SMS' do
        allow(TwilioClient).to receive(:enabled?).and_return(true)
        expect(TwilioClient).not_to receive(:send_sms)
        expect(DeliveryMailer).to receive(:delivery_failed_notification).and_return(double(deliver_later: true))

        DeliveryFailureNotificationJob.perform(reschedule.id)
      end
    end

    context 'different failure codes' do
      it 'builds message for customer_not_available' do
        allow(TwilioClient).to receive(:enabled?).and_return(true)
        expect(TwilioClient).to receive(:send_sms).with(
          phone_number: customer.phone,
          message: include("not available")
        )

        DeliveryFailureNotificationJob.perform(reschedule.id)
      end

      it 'builds message for address_not_found' do
        reschedule.update(failure_code: 'address_not_found')
        allow(TwilioClient).to receive(:enabled?).and_return(true)
        expect(TwilioClient).to receive(:send_sms).with(
          phone_number: customer.phone,
          message: include("couldn't locate")
        )

        DeliveryFailureNotificationJob.perform(reschedule.id)
      end
    end

    context 'error handling' do
      it 'logs errors and retries' do
        allow(TwilioClient).to receive(:enabled?).and_raise(StandardError.new('SMS service down'))
        
        expect {
          DeliveryFailureNotificationJob.perform(reschedule.id)
        }.to raise_error(StandardError)
      end
    end
  end
end
