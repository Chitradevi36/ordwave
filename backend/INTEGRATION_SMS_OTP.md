# SMS/OTP Integration Guide - OrdWave

## Overview

This guide covers the SMS/OTP integration for the OrdWave delivery app using **Twilio** for SMS delivery and **BCrypt** for secure OTP storage.

## Features Implemented

✅ **OTP Delivery Verification** - Drivers verify delivery with OTP sent to their phone  
✅ **SMS Service** - Centralized SMS sending with Twilio  
✅ **OTP Logging** - All SMS messages logged for audit trail  
✅ **Rate Limiting** - 5 OTP verification attempts, 10-minute expiry  
✅ **Error Handling** - Graceful fallback and detailed error messages  

---

## Setup Instructions

### 1. Add Environment Variables

Update `.env` with your Twilio credentials:

```bash
# Twilio SMS Configuration
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_PHONE_NUMBER=+1234567890  # Your Twilio phone number
```

Get these from: https://www.twilio.com/console

### 2. Install Dependencies

```bash
cd backend
bundle add twilio-ruby
```

Or add to `Gemfile`:

```ruby
gem "twilio-ruby", "~> 6.10"
```

### 3. Run Database Migration

```bash
cd backend
rails db:migrate
```

This creates the `sms_logs` table to track all SMS delivery.

### 4. Verify Setup

Test the SMS service:

```ruby
# In Rails console
sms = SMSService.new
sms.send_custom_sms("+919876543210", "Test SMS from OrdWave")
```

---

## API Endpoints

### Send OTP to Driver

**Endpoint:** `POST /api/v1/delivery_trips/:trip_id/trip_stops/:stop_id/send_otp`

**Authorization:** Bearer token required

**Body:**
```json
{
  "reason": "delivery_verification"
}
```

**Response (200):**
```json
{
  "otp_sent": true,
  "message": "OTP sent to +919876543210",
  "expires_in_seconds": 600,
  "attempts_remaining": 5
}
```

**Error Response (422):**
```json
{
  "error": "Driver phone number not available"
}
```

---

### Verify OTP Code

**Endpoint:** `POST /api/v1/delivery_trips/:trip_id/trip_stops/:stop_id/verify_otp`

**Authorization:** Bearer token required

**Body:**
```json
{
  "otp": "123456"
}
```

**Request Validations:**
- OTP must be exactly 6 digits
- OTP must not be expired (10 minutes)
- Maximum 5 verification attempts

**Response (200):**
```json
{
  "verified": true,
  "message": "OTP verified successfully",
  "proof_id": 42
}
```

**Error Responses:**
```json
{
  "error": "OTP has expired. Please request a new one."
}
```

```json
{
  "error": "Invalid OTP. 3 attempts remaining."
}
```

---

## Frontend Integration

### Using the OTP Hook

```typescript
import { useDeliveryOTP } from "@/lib/hooks/use_delivery_otp";

function DeliveryStopOTPModal({ stopId, onVerified }) {
  const {
    otpSending,
    otpVerifying,
    otpError,
    attemptsRemaining,
    sendOTP,
    verifyOTP,
    resetOTP,
    getOTPTimeRemaining,
  } = useDeliveryOTP(stopId);

  const handleSendOTP = async () => {
    const sent = await sendOTP();
    if (sent) {
      // Show success message
      alert("OTP sent to driver's phone");
    }
  };

  const handleVerifyOTP = async (code: string) => {
    const verified = await verifyOTP(code);
    if (verified) {
      onVerified();
      resetOTP();
    }
  };

  return (
    <div>
      <button onClick={handleSendOTP} disabled={otpSending}>
        {otpSending ? "Sending..." : "Send OTP"}
      </button>

      {otpError && <p className="text-red-600">{otpError}</p>}

      <input
        type="text"
        maxLength={6}
        placeholder="Enter 6-digit OTP"
        onChange={(e) => {
          if (e.target.value.length === 6) {
            handleVerifyOTP(e.target.value);
          }
        }}
      />

      <p className="text-sm text-gray-500">
        Attempts remaining: {attemptsRemaining}
      </p>
    </div>
  );
}
```

---

## SMS Service Methods

### Send Delivery OTP

```ruby
sms = SMSService.new
sms.send_delivery_otp("+919876543210", "123456", stop_id: 42)
```

**Parameters:**
- `phone_number` (String) - Driver's phone with country code
- `otp_code` (String) - 6-digit code
- `delivery_stop_id` (Integer, optional) - For context logging

---

### Send Delivery Alert

```ruby
sms.send_delivery_alert(
  "+919876543210",
  "TRIP-001",
  "https://app.ordwave.com/trips/1"
)
```

Notifies driver of new trip assignment.

---

### Send Payment Reminder

```ruby
sms.send_payment_reminder(
  "+919876543210",
  "INV-1001",
  amount = 5000.0,
  "https://app.ordwave.com/pay/inv-1001"
)
```

Sends payment due reminder to customers.

---

### Send Custom SMS

```ruby
sms.send_custom_sms("+919876543210", "Custom message here")
```

For one-off messages.

---

## Phone Number Format

The service automatically normalizes Indian phone numbers:

```ruby
# All these formats work:
sms.send_delivery_otp("+919876543210", "123456")  # With country code
sms.send_delivery_otp("09876543210", "123456")    # India with leading 0
sms.send_delivery_otp("9876543210", "123456")     # India without leading 0

# Result: +919876543210
```

---

## SMS Logging

All SMS messages are logged to `sms_logs` table for audit trail:

```ruby
# View all delivery OTPs sent
SMSLog.by_type('delivery_otp').today

# View payment reminders
SMSLog.by_type('payment_reminder').week

# Find by Twilio SID
SMSLog.find_by(twilio_sid: 'SM1234567890...')
```

**Schema:**
```
sms_logs
├── phone_number (string) - Recipient
├── message_body (text) - Message content
├── message_type (string) - Type of SMS
├── twilio_sid (string) - Twilio message ID
├── metadata (jsonb) - Extra context
├── sent_at (datetime) - When sent
└── created_at (datetime)
```

---

## Error Handling

### Twilio Configuration Error

```
Missing SMS configuration: TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, ...
```

**Fix:** Add missing env vars to `.env`

---

### SMS Send Failed

```
Failed to send SMS to +919876543210: ...
```

**Possible causes:**
- Invalid phone number format
- Twilio API rate limit
- Account balance exceeded
- Network error

**Debug:**
```ruby
# Test SMS service
sms = SMSService.new
sms.send_custom_sms("+919876543210", "Test message")
```

---

## Testing

### Unit Tests

```ruby
# spec/services/sms_service_spec.rb
describe SMSService do
  it "normalizes Indian phone numbers" do
    sms = SMSService.new
    
    expect(sms.send(:normalise_phone_number, "09876543210")).to eq("+919876543210")
    expect(sms.send(:normalise_phone_number, "9876543210")).to eq("+919876543210")
    expect(sms.send(:normalise_phone_number, "+919876543210")).to eq("+919876543210")
  end

  it "sends delivery OTP" do
    sms = SMSService.new
    
    expect {
      sms.send_delivery_otp("+919876543210", "123456")
    }.not_to raise_error
  end
end
```

---

## Monitoring & Analytics

### SMS Cost Tracking

Add this to your dashboard to track SMS spend:

```ruby
# app/services/sms_analytics.rb
class SMSAnalytics
  def self.daily_count(date = Date.today)
    SMSLog.where(created_at: date.beginning_of_day..date.end_of_day).count
  end

  def self.by_type_count(type)
    SMSLog.by_type(type).count
  end

  def self.failed_count
    SMSLog.where('metadata->>?', 'failed').count
  end

  def self.monthly_cost
    # Assuming $0.0075 per SMS
    daily_count * 0.0075 * 30
  end
end
```

---

## Troubleshooting

### OTP Not Received

1. **Check driver phone number** - Ensure it's correctly stored in system
2. **Check SMS logs** - `SMSLog.order(created_at: :desc).first` to see what was sent
3. **Check Twilio logs** - https://www.twilio.com/console/sms/logs
4. **Verify country code** - SMS to India must start with +91

---

### OTP Expired

The OTP is valid for **10 minutes** after sending. If customer needs new OTP:

```
POST /api/v1/delivery_trips/:trip_id/trip_stops/:stop_id/send_otp
```

---

### "Too Many Attempts"

Maximum **5 OTP verification attempts** per request. If all used:

1. Request new OTP
2. This resets the attempt counter

---

## Next Steps

🔜 **SMS Delivery Status Tracking** - Track delivery/bounce status  
🔜 **Two-Way SMS** - Receipt of SMS from drivers  
🔜 **SMS Templates** - Pre-built templates for common scenarios  
🔜 **Bulk SMS** - Send to multiple drivers at once  
🔜 **SMS Scheduling** - Schedule SMS for future time  

---

## Support

For issues with Twilio, visit: https://support.twilio.com
For issues with this integration, check the logs:

```bash
# Backend
tail -f log/development.log | grep -i sms

# Database
rails db:execute "SELECT * FROM sms_logs ORDER BY created_at DESC LIMIT 10;"
```
