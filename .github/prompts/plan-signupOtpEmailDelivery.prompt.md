# Plan: OTP Email Delivery for Signup

## Provider Comparison

| Provider | Best for | Free tier | Price at scale | Rails gem | India deliverability |
|---|---|---|---|---|---|
| **Postmark** ⭐ | Transactional OTPs | 100/month | $1.50/1K | `postmark-rails` | Excellent |
| **SendGrid** | High volume | 100/day | $0.60/1K | `sendgrid-ruby` | Good |
| **AWS SES** | Cost-sensitive, AWS-native | 62K/month (EC2) | $0.10/1K | `aws-sdk-ses` | Good |
| **Mailgun** | Developers | 1K/month (EU) | $0.80/1K | `mailgun-ruby` | Good |

**Recommendation: Postmark** — purpose-built for transactional emails (OTPs, invites, receipts). Best deliverability for time-sensitive messages, simplest Rails integration, and your volume is low. If you're already on AWS, SES is the budget choice.

---

## Implementation Plan

### Step 1: Add the gem

In `Gemfile`, after the `bcrypt` gem line:

```ruby
# Email delivery
gem 'postmark-rails', '~> 0.22'
```

### Step 2: Configure delivery in each environment

**`config/environments/production.rb`** — add inside `Rails.application.configure do`:
```ruby
config.action_mailer.delivery_method = :postmark
config.action_mailer.postmark_settings = { api_token: ENV['POSTMARK_API_TOKEN'] }
config.action_mailer.default_url_options = { host: ENV['APP_HOST'] }
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
```

**`config/environments/development.rb`** — use `letter_opener` or Postmark sandbox:
```ruby
config.action_mailer.delivery_method = :letter_opener  # gem 'letter_opener', group: :development
config.action_mailer.perform_deliveries = true
config.action_mailer.default_url_options = { host: 'localhost:3000' }
```

### Step 3: Update `ApplicationMailer`

In `app/mailers/application_mailer.rb`:
```ruby
class ApplicationMailer < ActionMailer::Base
  default from: "OrdWave <no-reply@yourdomain.com>"
  layout "mailer"
end
```

### Step 4: Create `SignupMailer`

New file `app/mailers/signup_mailer.rb`:
```ruby
class SignupMailer < ApplicationMailer
  def send_otp(pending_registration)
    @otp = pending_registration.otp_code
    @email = pending_registration.email
    @expires_in = '10 minutes'

    mail(
      to: @email,
      subject: "Your OrdWave verification code: #{@otp}",
      message_stream: 'outbound'  # Postmark stream name
    )
  end
end
```

### Step 5: Create the email templates

**`app/views/signup_mailer/send_otp.html.erb`**:
```erb
<h2>Your verification code</h2>
<p>Use the code below to verify your email and create your OrdWave account.</p>

<div style="font-size: 36px; font-weight: bold; letter-spacing: 8px; margin: 24px 0;">
  <%= @otp %>
</div>

<p>This code expires in <strong><%= @expires_in %></strong>.</p>
<p>If you didn't request this, you can safely ignore this email.</p>
```

**`app/views/signup_mailer/send_otp.text.erb`**:
```erb
Your OrdWave verification code: <%= @otp %>

This code expires in <%= @expires_in %>.

If you didn't request this, ignore this email.
```

### Step 6: Uncomment the call in `InitiateService`

In `app/services/signup/initiate_service.rb` at lines 28–29, replace:
```ruby
# TODO: Send OTP via email
# SignupMailer.send_otp(pending).deliver_later
```
with:
```ruby
SignupMailer.send_otp(pending).deliver_later
```

Sidekiq is already configured, so `deliver_later` routes through it automatically — no changes needed to background job setup.

### Step 7: Add credentials

```bash
# Run in terminal to edit encrypted credentials:
rails credentials:edit

# Add:
postmark:
  api_token: your_postmark_server_api_token
```

Then reference as `Rails.application.credentials.postmark[:api_token]` in the env config, or use a plain `ENV['POSTMARK_API_TOKEN']` if you prefer dotenv.

### Step 8: Domain verification (Postmark setup)

1. Create a Postmark account → create a Server → copy the **Server API Token**
2. Go to Sender Signatures → verify `no-reply@yourdomain.com`
3. Add the SPF + DKIM DNS records Postmark provides to your domain

---

## Verification Steps

1. `bundle exec rails console` → `SignupMailer.send_otp(PendingRegistration.last).deliver_now` — check Postmark activity log
2. Hit `POST /api/v1/signup/initiate` → confirm email arrives within ~2s
3. Check Sidekiq dashboard (`/sidekiq`) to confirm mail jobs are processing

## Summary of Changes

| Type | File | Action |
|---|---|---|
| Gem | `Gemfile` | Add `postmark-rails` |
| Config | `config/environments/production.rb` | Add Postmark delivery settings |
| Config | `config/environments/development.rb` | Add `letter_opener` for local dev |
| Mailer | `app/mailers/application_mailer.rb` | Update `from:` address |
| Mailer | `app/mailers/signup_mailer.rb` | Create `SignupMailer#send_otp` |
| View | `app/views/signup_mailer/send_otp.html.erb` | Create HTML email template |
| View | `app/views/signup_mailer/send_otp.text.erb` | Create plain-text template |
| Service | `app/services/signup/initiate_service.rb` | Uncomment `deliver_later` call |
| Credentials | `config/credentials.yml.enc` | Add `postmark.api_token` |
