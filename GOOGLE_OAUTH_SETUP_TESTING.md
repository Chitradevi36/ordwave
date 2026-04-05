# Google OAuth Phase 1 - Setup & Testing Instructions

**Date:** March 26, 2026  
**Objective:** Get Google OAuth working end-to-end locally

---

## Step 1: Get Google OAuth Credentials (~15 minutes)

### 1a. Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Click "Create Project"
3. Name: `OrderLane Pro` (or similar)
4. Create

### 1b. Enable Google+ API
1. Search for "Google+ API" in the search bar
2. Click "Google+ API"
3. Click "Enable"

### 1c. Create OAuth 2.0 Credential
1. Go to "Credentials" in left sidebar
2. Click "Create Credentials" → "OAuth client ID"
3. Application type: "Web application"
4. Name: `OrderLane Web`
5. **Authorized JavaScript origins:**
   - `http://localhost:3000`
   - `http://localhost:3001`
6. **Authorized redirect URIs:**
   - `http://localhost:3000`
7. Create
8. **Copy the Client ID** (looks like: `123456.apps.googleusercontent.com`)

---

## Step 2: Configure Environment Variables (~5 minutes)

### Backend (.env)
Create/update `backend/.env`:
```bash
GOOGLE_OAUTH_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com
DEVISE_JWT_SECRET_KEY=your-jwt-secret-key
```

### Frontend (.env.local)
Create/update `web/.env.local`:
```bash
NEXT_PUBLIC_GOOGLE_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com
NEXT_PUBLIC_API_URL=http://localhost:3001
```

**Replace** `YOUR_CLIENT_ID` with the actual Client ID from Step 1c.

---

## Step 3: Install Dependencies (~10 minutes)

### Backend
```bash
cd backend
bundle install
```

This installs `google-auth-library-ruby` gem.

### Frontend
```bash
cd web
npm install
```

This installs `@react-oauth/google` package.

---

## Step 4: Run Database Migration (~5 minutes)

```bash
cd backend
rails db:migrate RAILS_ENV=development
```

This creates `oauth_provider` and `oauth_uid` columns on users table.

---

## Step 5: Start Servers (~2 minutes)

### Terminal 1: Backend (Rails)
```bash
cd backend
rails s -p 3001
```

Expected output:
```
* Puma starting in single mode
* Version 6.x.x
* Listening on http://127.0.0.1:3001
```

### Terminal 2: Frontend (Next.js)
```bash
cd web
npm run dev
```

Expected output:
```
  ▲ Next.js 14.2.35
  - Local:        http://localhost:3000
  - Environments: .env.local
```

---

## Step 6: Manual Testing (~15 minutes)

### 6a. Open Login Page
1. Open browser to `http://localhost:3000/login`
2. You should see:
   - "OrdWave" heading
   - **"Sign in with Google" button** (new!)
   - Divider line
   - Email/password form (existing)

### 6b. Test with Existing User
**Scenario:** User already exists in system with matching email

1. Go to Rails console:
   ```bash
   cd backend && rails c
   ```

2. Create a test user:
   ```ruby
   user = User.create!(
     email: 'test@gmail.com',
     first_name: 'Test',
     last_name: 'User',
     password: 'password123',
     phone: '9876543210',
     plan: 'starter',
     active: true
   )
   ```

3. Back in browser, click "Sign in with Google"

4. **Google consent screen** will appear
   - Select an account with email `test@gmail.com`
   - Click "Continue"

5. **Expected result:**
   - Redirects to `/dashboard`
   - localStorage contains `auth_token`
   - User data is populated

### 6c. Test with Non-existent User
**Scenario:** User email doesn't exist in system

1. In same browser/Google consent, select a **different Gmail account** (or logout first)

2. Click "Sign in with Google" again

3. **Expected result:**
   - Redirected back to login
   - Error message: **"User not found. Please contact an admin..."**

### 6d. Verify Token in Browser
1. Open Developer Tools (F12)
2. Go to "Application" → "Local Storage"
3. Look for `auth_token` key
4. Value should be a JWT token (3 parts separated by dots)

---

## Step 7: Verify Network Traffic (~5 minutes)

### Check API Call
1. Open Developer Tools → "Network" tab
2. Click "Sign in with Google"
3. Look for POST request to `/api/v1/auth/google_login`
4. Request body should show `id_token: ...`
5. Response status should be:
   - **200** if user found
   - **401** if user not found

### Example Successful Response
```json
{
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "email": "test@gmail.com",
      "first_name": "Test",
      "full_name": "Test User",
      "organization_id": 1
    }
  }
}
```

---

## Step 8: Test Regression (Email/Password Login)

Ensure existing login still works:

1. Click "Or continue with email"
2. Enter email and password for existing user
3. Click "Sign in"
4. Should redirect to `/dashboard` (same as Google)

---

## Troubleshooting

### Issue: "Sign in with Google" Button Not Visible

**Check:** 
```bash
cd web && npm ls @react-oauth/google
```

Should show version `0.12.1`. If missing:
```bash
npm install @react-oauth/google@0.12.1
```

**Check ENV:**
```bash
echo $NEXT_PUBLIC_GOOGLE_CLIENT_ID
```

Should not be empty.

**Solution:** Restart dev server after env changes:
```bash
Ctrl+C in Terminal 2
npm run dev
```

---

### Issue: "Invalid Google Token" Error

**Check Backend Logs:**
```bash
# In backend terminal, look for error messages
```

**Likely Causes:**
1. `GOOGLE_OAUTH_CLIENT_ID` in backend `.env` doesn't match frontend
2. Token already expired (unlikely <1 minute)
3. Google API credentials disabled in Console

**Solution:**
- Verify both `.env` files have **identical** Client ID
- Check Google Cloud Console → Credentials → Are active?

---

### Issue: "User Not Found" - Even for Existing User

**Check:**
1. User email must **exactly match** Google email (case-insensitive)
2. User must be `active = true` and `deleted_at = null`

**Debug:**
```bash
cd backend && rails c
User.find_by(email: 'test@gmail.com').inspect
```

Should show user record. If nil, create user first.

---

### Issue: Redirects to Login After "Success"

**Check:**
- Is `auth_token` in localStorage? (see Step 6d)
- Does token look valid? (3 parts separated by dots)

**Check Backend:**
```bash
# In backend log, you should see:
# "POST /api/v1/auth/google_login"
# Response: 200
```

If response is 401, user not found (expected for non-existent user).

---

## Next Steps After Testing

1. **Update plan** document with findings
2. **Prepare Phase 2** for Microsoft OAuth (next week)
3. **Deploy to staging** for QA testing
4. **Customer comms** - "Sign in with Google now available!"

---

## Quick Reference Commands

```bash
# Backend: Check migrations
rails db:migrate:status

# Backend: Reset DB (if needed)
rails db:drop db:create db:migrate

# Frontend: Clear cache
rm -rf .next node_modules
npm install
npm run dev

# Check logs in real-time
tail -f log/development.log

# Test API endpoint directly
curl -X POST http://localhost:3001/api/v1/auth/google_login \
  -H "Content-Type: application/json" \
  -d '{"id_token":"YOUR_TOKEN"}'
```

---

**Estimated Total Time:** ~60 minutes  
**Ready to Test:** Yes ✅

**Questions? Check:**
- `GOOGLE_OAUTH_IMPLEMENTATION.md` for full spec
- Backend logs: `backend/log/development.log`
- Frontend console: F12 → Console tab
