# Invoice Actions - Local Debug & Testing Guide

## Setup: Enable Console Debugging

Open browser DevTools (F12) and paste this in console:

```javascript
// Enable detailed logging for all invoice actions
window.invoiceDebug = {
  logRequest: (action, method, url, headers, body) => {
    console.group(`🔵 [${action}] ${method} ${url}`);
    console.log('Headers:', headers);
    if (body) console.log('Body:', body);
    console.groupEnd();
  },
  
  logResponse: (action, status, body) => {
    console.group(`📦 [${action}] Response (${status})`);
    console.log('Body:', body);
    console.groupEnd();
  },
  
  logError: (action, error) => {
    console.group(`❌ [${action}] Error`);
    console.error('Message:', error.message);
    console.error('Full:', error);
    console.groupEnd();
  }
};

console.log('✅ Invoice debug helpers loaded. Use window.invoiceDebug.* methods');
```

---

## Action 1: Preview PDF

**Button:** "Preview PDF"  
**Endpoint:** `GET /api/v1/sales_invoices/{id}/pdf`  
**Expected Response:**
```json
{
  "data": {
    "download_url": "https://..../signed-pdf-url-blob-key"
  }
}
```

### Test Steps:
1. ✅ Click "Preview PDF" button
2. 📍 Check console for `🔵 [PDF Preview]` logs
3. ✅ Verify response has `data.download_url`
4. ✅ Modal should open with iframe showing PDF
5. ❌ **If fails:** Check console for error message

### Common Issues:
- ❌ `Missing host to link to` → Backend missing `APP_HOST` env var
- ❌ `No download URL in response` → API not returning signed URL
- ❌ `PDF generation failed` → Backend PDF service error

---

## Action 2: Download PDF

**Button:** "Download PDF" / "Generate PDF"  
**Endpoint:** `GET /api/v1/sales_invoices/{id}/pdf`  
**Expected Response:** Same as Preview

### Test Steps:
1. ✅ Click "Download PDF" button
2. 📍 Check console logs  
3. ✅ File should download to Downloads folder
4. ✅ Button text should update to "Download PDF" (not "Generate")
5. ❌ **If fails:** Check same issues as Preview

### Debug: Check if PDF already generated
```javascript
// In console:
window.debugInvoice?.invoice?.pdf_generated_at  // Should show timestamp if generated
window.debugInvoice?.invoice?.has_pdf           // Should be true
window.debugInvoice?.invoice?.pdf_url           // Should have URL
```

---

## Action 3: Generate e-Invoice (IRN)

**Button:** "Generate e-Invoice"  
**Endpoint:** `POST /api/v1/sales_invoices/{id}/einvoice`  
**Expected Response:**
```json
{
  "data": {
    "irn": "abc123def456...",
    "ack_number": "12345",
    "ack_datetime": "2026-04-08T09:30:00Z",
    "einvoice_qr_code": "base64-image-data",
    "einvoice_status": "valid"
  }
}
```

### Test Steps:
1. ✅ Invoice status must be "ISSUED" (not Draft)
2. ✅ Click "Generate e-Invoice" button
3. 📍 Check console for `🔵 [e-Invoice]` logs
4. ✅ Button should show "Generating IRN..." initially
5. ✅ IRN should appear in "e-Invoice (IRP)" section after success
6. ✅ QR code image should display
7. ❌ **If fails:** Check error message

### Common Issues:
- ❌ "Button is disabled" → Invoice is Draft or already has IRN
- ❌ `e-Invoice generation failed` → Check backend logs for GST validation errors
- ❌ `No IRN in response` → Backend integration with GST portal failed

---

## Action 4: Generate e-Way Bill

**Button:** "Generate E-Way Bill"  
**Modal Fields:**
- Transport Mode: (Road/Rail/Air/Ship)
- Distance (km)
- Vehicle Number
- Transporter Name
- Transporter GSTIN/ID

**Endpoint:** `POST /api/v1/sales_invoices/{id}/ewaybill`  
**Request Body:**
```json
{
  "transport_mode": "1",
  "vehicle_number": "MH12AB1234",
  "transporter_name": "Fast Logistics",
  "transporter_id": "05BBBBB1111B1ZC",
  "distance_km": 150
}
```

**Expected Response:**
```json
{
  "data": {
    "ewaybill_number": "482701257623",
    "ewaybill_status": "active",
    "ewaybill_valid_upto": "2026-04-22T09:30:00Z",
    "ewaybill_generated_at": "2026-04-08T09:30:00Z"
  }
}
```

### Test Steps:
1. ✅ Invoice status must be "ISSUED"
2. ✅ Click "Generate E-Way Bill" button
3. ✅ Modal should appear with form
4. ✅ Fill in all required fields:
   - Transport Mode: Road (default is OK)
   - Distance: 150
   - Vehicle: AB1234  
   - Transporter: Test Logistics
   - GSTIN: 05AAABB0012B1Z5
5. ✅ Click "Generate" button
6. 📍 Check console for `🔵 [E-Way Bill]` logs
7. ✅ Modal should close on success
8. ✅ e-Way Bill section should show number and status
9. ❌ **If fails:** Check error in red text

### Validation:
```javascript
// Check in console:
window.debugInvoice?.invoice?.ewaybill_number   // Should have EWB number
window.debugInvoice?.invoice?.ewaybill_status   // Should be "active"
```

---

## Action 5: Void Invoice

**Button:** "Void" (red button)  
**Modal:** Void reason text field (required)  
**Endpoint:** `POST /api/v1/sales_invoices/{id}/void`  
**Request Body:**
```json
{
  "reason": "User explanation for voiding"
}
```

**Expected Response:**
```json
{
  "data": {
    "status": "void",
    "voided_at": "2026-04-08T09:30:00Z",
    "void_reason": "User explanation..."
  }
}
```

### Test Steps:
1. ✅ Invoice status must be "ISSUED" (not Draft)
2. ✅ Click "Void" button (bottom right)
3. ✅ Modal should appear asking for reason
4. ✅ Enter a reason: "Testing void action"
5. ✅ Click "Confirm Void" button
6. 📍 Check console for `🔵 [Void Invoice]` logs
7. ✅ Modal should close
8. ✅ Invoice status badge should change to "VOID" (red)
9. ✅ Void section at top should show void details
10. ❌ **If fails:** Check error message

### Validation:
```javascript
// Check in console:
window.debugInvoice?.invoice?.status           // Should be "void"
window.debugInvoice?.invoice?.voided_at        // Should have timestamp
window.debugInvoice?.invoice?.void_reason      // Should match what you entered
```

---

## Full Test Checklist

### Setup
- [ ] Invoice loaded (not Draft)
- [ ] Console open (F12)
- [ ] Network tab open to see API calls

### PDF Actions
- [ ] Preview PDF works and opens modal
- [ ] Download PDF triggers file download
- [ ] PDF URLs are signed and accessible
- [ ] Refreshes after generation

### e-Invoice (IRN)
- [ ] Button only shows if issued and no IRN
- [ ] Generates successfully
- [ ] IRN displays in summary
- [ ] QR code displays
- [ ] Status updates to "valid"

### e-Way Bill
- [ ] Button only shows if issued and no EWB
- [ ] Modal opens with form
- [ ] All fields validate
- [ ] Generates successfully
- [ ] EWB number displays
- [ ] Valid date shows

### Void
- [ ] Button only shows if issued
- [ ] Requires reason (can't submit empty)
- [ ] Successfully voids invoice
- [ ] Status changes to VOID
- [ ] Void details appear

---

## Console Debug Commands

```javascript
// See all invoice data
console.table(window.debugInvoice?.invoice);

// Check auth
console.log('Token:', window.debugInvoice?.token);
console.log('Org ID:', window.debugInvoice?.orgId);
console.log('Has Auth:', window.debugInvoice?.hasAuth);

// Check specific fields
console.log('PDF URL:', window.debugInvoice?.invoice?.pdf_url);
console.log('IRN:', window.debugInvoice?.invoice?.irn);
console.log('EWB:', window.debugInvoice?.invoice?.ewaybill_number);
console.log('Status:', window.debugInvoice?.invoice?.status);

// Check last network request
// (Filter Network tab for "pdf" or "ewaybill" or "einvoice" or "void")
```

---

## Backend Error Responses

### PDF Endpoint
```json
{
  "error": "Missing host to link to! Please provide the :host parameter, set default_url_options[:host], or set :only_path to true"
}
```
✅ **Fix:** Set `APP_HOST` environment variable in production.rb

### e-Invoice Endpoint
```json
{
  "errors": ["GSTIN validation failed for customer", "..."  ]
}
```
✅ **Fix:** Ensure customer has valid GSTIN registered

### e-Way Bill Endpoint
```json
{
  "errors": ["Vehicle number format invalid", "Transporter GSTIN required"]
}
```
✅ **Fix:** Validate all fields. See field requirements in test steps above.

### Void Endpoint
```json
{
  "errors": ["Invoice status must be 'issued' to void"]
}
```
✅ **Fix:** Only issued invoices can be voided

---

## Quick Test (Local Machine)

1. **Start backend:**
   ```bash
   cd backend
   RAILS_ENV=production bundle exec rails s
   ```

2. **Start frontend:**
   ```bash
   cd web
   npm run dev
   ```

3. **Open invoice in browser:**
   ```
   http://localhost:3000/sales-invoices/28
   ```

4. **Open console (F12)** and run all 5 actions

5. **Check Network tab** (F12 → Network) for each request:
   - Status should be 200
   - Response should have `data` object
   - No CORS errors

6. **Report any failures** with:
   - Action name
   - Response status & body (from console)
   - Error message (red text shown)
   - Network tab response

