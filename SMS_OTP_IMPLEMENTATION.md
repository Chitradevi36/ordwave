# SMS/OTP Implementation Summary

## ✅ What's Been Implemented

### Backend Components

#### 1. **SMS Service** (`app/services/sms_service.rb`)
- Twilio integration with full error handling
- Multiple SMS types:
  - `send_delivery_otp()` - OTP for delivery verification
  - `send_registration_otp()` - Account verification OTP
  - `send_delivery_alert()` - Trip assignment notifications
  - `send_payment_reminder()` - Invoice payment reminders
  - `send_custom_sms()` - Generic SMS sending
- Automatic Indian phone number normalization
- Background job for SMS logging

#### 2. **Database Models & Migration**
- `SMSLog` model - Tracks all SMS delivery
  - `app/models/sms_log.rb`
  - `db/migrate/*_create_sms_logs.rb`
- Updated `DeliveryProof` model with OTP tracking
  - `db/migrate/*_add_otp_tracking_to_delivery_proofs.rb`
  - Adds: `otp_sent_at`, `otp_attempts`, `otp_proof_type`

#### 3. **API Endpoints** (`app/controllers/api/v1/delivery_otp_controller.rb`)
```
POST /api/v1/delivery_trips/:trip_id/trip_stops/:stop_id/send_otp
POST /api/v1/delivery_trips/:trip_id/trip_stops/:stop_id/verify_otp
```

#### 4. **Background Job** (`app/jobs/log_sms_job.rb`)
- Asynchronously logs SMS delivery for audit trail
- Integrates with Sidekiq job queue

### Frontend Components

#### 1. **OTP Hook** (`lib/hooks/use_delivery_otp.ts`)
- React hook for OTP management
- `sendOTP()` - Send OTP to driver
- `verifyOTP(code)` - Verify OTP submission
- `resetOTP()` - Reset OTP state
- `getOTPTimeRemaining()` - Show countdown timer
- Manages: sending state, verification state, errors, attempt tracking

#### 2. **Integration Points (Ready for Implementation)**
- `app/delivery/[id]/page.tsx` - Already has OTP UI logic
- `app/inventory/stock/[id]/page.tsx` - Can add OTP for stock updates
- Custom delivery verification flows

### Configuration

#### Updated Files:
- `backend/Gemfile` - Added `twilio-ruby` gem
- `backend/config/routes.rb` - Added OTP endpoints
- `backend/.env.example` - Twilio credentials template

---

## 🚀 How to Get Started

### Step 1: Get Twilio Account (5 minutes)

1. Go to https://www.twilio.com/console
2. Sign up (free trial available)
3. Get your credentials:
   - `TWILIO_ACCOUNT_SID`
   - `TWILIO_AUTH_TOKEN`
   - `TWILIO_PHONE_NUMBER` (e.g., +1234567890)

### Step 2: Update Environment Variables

```bash
# backend/.env
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_PHONE_NUMBER=+1234567890
```

### Step 3: Install Dependencies

```bash
cd backend
bundle install  # Installs twilio-ruby gem
```

### Step 4: Run Migrations

```bash
rails db:migrate
```

This creates:
- `sms_logs` table
- Adds OTP tracking columns to `delivery_proofs`

### Step 5: Test SMS Service

```ruby
# In Rails console
$ rails c
sms = SMSService.new
sms.send_custom_sms("+919876543210", "Test from OrdWave")
```

---

## 📊 API Usage Examples

### Send OTP to Driver

```javascript
// Frontend - using the hook
const { sendOTP } = useDeliveryOTP(stopId);

const handleSend = async () => {
  const success = await sendOTP();
  if (success) {
    console.log("OTP sent!");
  }
};
```

### Verify OTP

```javascript
// Frontend - verify 6-digit code
const { verifyOTP } = useDeliveryOTP(stopId);

const handleVerify = async (code) => {
  const verified = await verifyOTP(code);
  if (verified) {
    console.log("Delivery verified!");
  }
};
```

### In Backend (Ruby)

```ruby
# Send OTP to driver
sms = SMSService.new
sms.send_delivery_otp("+919876543210", "123456", delivery_stop_id: 42)

# Send payment reminder
sms.send_payment_reminder(
  "+919876543210",
  "INV-001",
  5000.0,
  "https://app.ordwave.com/pay/inv-001"
)
```

---

## 🔒 Security Features

✅ **OTP Security**
- OTPs stored as BCrypt hashes (never plain text)
- 10-minute expiry
- Maximum 5 verification attempts
- Rate limiting built-in

✅ **Data Privacy**
- Only phone number and OTP hash stored
- Phone numbers masked in logs
- Full audit trail of all OTP actions

✅ **Error Handling**
- Graceful Twilio API failures
- Detailed error messages for debugging
- SMS delivery tracking via Twilio SID

---

## 📁 File Structure

```
backend/
├── app/
│   ├── controllers/api/v1/
│   │   └── delivery_otp_controller.rb
│   ├── jobs/
│   │   └── log_sms_job.rb
│   ├── models/
│   │   └── sms_log.rb
│   └── services/
│       └── sms_service.rb
├── db/
│   └── migrate/
│       ├── *_create_sms_logs.rb
│       └── *_add_otp_tracking_to_delivery_proofs.rb
├── Gemfile (updated)
├── config/routes.rb (updated)
└── INTEGRATION_SMS_OTP.md

web/
├── lib/
│   └── hooks/
│       └── use_delivery_otp.ts
└── app/
    └── delivery/
        └── [id]/
            └── page.tsx (ready for OTP UI integration)
```

---

## ✨ Next: Frontend Integration

The UI for OTP verification is already partially in place. To fully integrate:

### 1. Update Delivery Stop Modal

```tsx
import { useDeliveryOTP } from "@/lib/hooks/use_delivery_otp";

function DeliveryStopModal({ stopId, onSuccess }) {
  const { sendOTP, verifyOTP, otpError, attemptsRemaining } = 
    useDeliveryOTP(stopId);

  const handleSendClick = async () => {
    await sendOTP();
    showNotification("OTP sent to driver");
  };

  const handleOTPSubmit = async (code) => {
    const verified = await verifyOTP(code);
    if (verified) {
      onSuccess();
    }
  };

  return (
    <Modal>
      <button onClick={handleSendClick}>Send OTP</button>
      <OTPInput onComplete={handleOTPSubmit} />
      {otpError && <p className="error">{otpError}</p>}
      <p>Attempts: {attemptsRemaining}/5</p>
    </Modal>
  );
}
```

### 2. Add OTP Verification Step

In the delivery completion flow:
1. Driver selects "OTP" proof type
2. Click "Send OTP" → SMS sent
3. Driver enters 6-digit OTP
4. On verification → Delivery marked complete

---

## 🧪 Testing Checklist

- [ ] Twilio credentials working
- [ ] SMS sends successfully (check Twilio logs)
- [ ] OTP generated and stored in DB
- [ ] OTP verification works (valid code)
- [ ] OTP verification fails (invalid code)
- [ ] OTP expiry works (after 10 minutes)
- [ ] Attempt limit enforced (max 5)
- [ ] SMS logs recorded in database
- [ ] Frontend hook sends OTP
- [ ] Frontend hook verifies OTP

---

## 📞 Support & Troubleshooting

**SMS not sending?**
- Check Twilio account balance
- Verify phone number format (+91...)
- Check env vars are set
- Review Twilio logs: https://www.twilio.com/console/sms/logs

**OTP not received on phone?**
- Verify driver phone number in system
- Check if in Twilio trial (requires number verification)
- Try from Twilio console directly

**Database migration failed?**
```bash
rails db:rollback
rails db:migrate
```

---

## 🎯 Features Available Now

✅ Send OTP via SMS  
✅ Verify OTP with retry logic  
✅ Track SMS delivery  
✅ Audit trail of all OTP actions  
✅ Phone number normalization  
✅ Error handling & logging  

## 🚀 Features Coming Soon

🔜 SMS delivery status tracking (bounces, failures)  
🔜 Two-way SMS (receive SMS from drivers)  
🔜 SMS templates management  
🔜 Bulk SMS sending  
🔜 SMS scheduling  
🔜 WhatsApp integration  

---

## 💡 Tips

- Use Twilio trial for testing ($15 free credit)
- Test with actual phone number (SMS won't send in some scenarios)
- Monitor SMS costs (typically $0.0075 per SMS in India)
- Store driver phone numbers with +91 country code
- Review SMS logs regularly for delivery issues

---

**Questions?** Check the detailed guide: `INTEGRATION_SMS_OTP.md`
