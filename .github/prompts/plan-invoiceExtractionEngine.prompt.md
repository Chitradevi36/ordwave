# Plan: Invoice Extraction Engine for OrderLane

**TL;DR:** Build a multi-format invoice extraction system with 6 format-specific parsers (JSON/Tally/Zoho/CSV/Excel/PDF), normalize to a unified database schema, and integrate with existing OrderLane sales_invoices workflow. Each parser handles format-specific quirks while outputting consistent keys. Use PostgreSQL for extracted data with audit logging for compliance.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Invoice Upload API Endpoint                      │
└────────────┬────────────────────────────────────────────────┘
             │
             ├─ File Format Detection (MIME + extension)
             │
        ┌────▼─────────────────────────────────────────┐
        │    Invoice Extraction Router                         │
        │  (determines which parser to use)              │
        └────┬─────────────┬────────┬──────┬──────┬─────┘
             │             │        │      │      │
      ┌──────▼────┐  ┌─────▼──┐ ┌──▼───┐ ┌─▼──┐ ┌─▼──┐
      │  JSON     │  │ Tally  │ │Zoho  │ │CSV │ │PDF │
      │  Parser   │  │ Parser │ │Parser│ │Prs │ │Prs │
      └───────────┘  └────────┘ └──────┘ └────┘ └────┘
             │             │        │      │      │
             └─────────────┴────────┴──────┴──────┘
                           │
                ┌──────────▼──────────┐
                │  Unified Normalizer  │
                │ (consistent keys)    │
                └──────────┬───────────┘
                           │
        ┌──────────────────▼───────────────────┐
        │  Database Layer (PostgreSQL)          │
        │  - invoices table (extracted data)    │
        │  - extraction_logs (audit trail)      │
        │  - line_items table (items)           │
        └───────────────────────────────────────┘
```

---

## Data Model: Consistent Unified Schema

### Primary Keys (ALL Parsers Output These)

```typescript
interface UnifiedInvoiceData {
  // Identifiers (consistent across all formats)
  source_format: "json" | "tally" | "zoho" | "csv" | "excel" | "pdf";
  source_type: "amazon" | "flipkart" | "jiomart" | "local_b2b" | "generic";
  invoice_number: string;                    // Required
  invoice_date: string;                      // ISO 8601
  tax_invoice_type?: "tax_invoice" | "credit_note" | "debit_note";

  // Seller Information
  seller: {
    name: string;
    gstin: string | null;
    pan: string | null;
    address: string;
    city: string;
    state: string;
    pincode: string;
    country: string;
    phone?: string;
    email?: string;
  };

  // Buyer Information
  buyer: {
    name: string;
    gstin: string | null;
    pan: string | null;
    address: string;
    city: string;
    state: string;
    pincode: string;
    country: string;
    phone?: string;
    email?: string;
  };

  // Tax & Place Info
  place_of_supply: string;                   // State code (TN, KA, etc.)
  gst_treatment: "intra_state" | "inter_state" | "deemed_export" | "exempt";

  // Line Items
  line_items: Array<{
    sl_no: number;
    description: string;
    hsn_sac: string;                         // HSN code (6 digits) or SAC code
    quantity: number;
    unit: string;                            // units (pcs, kg, etc.)
    unit_price: number;                      // Price per unit
    taxable_value: number;                   // After discount
    
    // Tax Breakdown (Mutually exclusive - depends on location)
    cgst_rate?: number;
    cgst_amount?: number;
    sgst_rate?: number;
    sgst_amount?: number;
    igst_rate?: number;
    igst_amount?: number;
    
    total_tax_amount?: number;
    total_amount: number;                    // Including tax
    
    // Optional Fields (if available)
    discount_rate?: number;
    discount_amount?: number;
    cess_rate?: number;
    cess_amount?: number;
  }>;

  // Totals
  totals: {
    taxable_value: number;
    cgst_total?: number;
    sgst_total?: number;
    igst_total?: number;
    cess_total?: number;
    total_tax_amount: number;
    roundoff_amount?: number;
    total_invoice_value: number;
  };

  // Payment & Business Terms
  currency: string;                          // Default: INR
  due_date?: string;
  payment_terms?: string;
  notes?: string;
  reference_number?: string;                 // PO, order ID, etc.

  // Metadata
  extraction_timestamp: string;              // ISO 8601
  extraction_confidence: number;             // 0-100%
  extraction_warnings?: string[];
  raw_source_url?: string;                   // For later audit
}
```

---

## 1. JSON Parser Template

**Handles:** Amazon B2B, Flipkart B2B, Local B2B, Generic Tax Invoices

### Input Variations
```javascript
// Format A: Amazon/Flipkart (line_items with tax rates)
{
  invoice_number: "MKT-179329740",
  invoice_date: "2025-09-15",
  seller: {...},
  buyer: {...},
  line_items: [{
    description: "...",
    quantity: 2,
    unit_price: 0.38,
    igst_rate: 18,
    igst_amount: 0.14
  }]
}

// Format B: Local B2B (cgst + sgst)
{
  line_items: [{
    cgst_rate: 6,
    cgst_amount: 100,
    sgst_rate: 6,
    sgst_amount: 100
  }]
}
```

### Parser Implementation Plan
```ruby
# backend/app/services/invoice_extraction/parsers/json_parser.rb

class JsonParser
  attr_reader :data, :source_type
  
  def initialize(raw_json, source_type: detect_source)
    @data = JSON.parse(raw_json)
    @source_type = source_type  # amazon, flipkart, local_b2b, etc.
  end
  
  def extract
    {
      source_format: "json",
      source_type: @source_type,
      invoice_number: data['invoice_number'] || data['reference_number'],
      invoice_date: parse_date(data['invoice_date'] || data['date']),
      seller: extract_party(data['seller']),
      buyer: extract_party(data['buyer']),
      place_of_supply: data['place_of_supply'],
      gst_treatment: determine_gst_treatment,
      line_items: extract_line_items,
      totals: extract_totals,
      extraction_timestamp: Time.current.iso8601,
      extraction_confidence: 95  # JSON is highly reliable
    }
  end
  
  private
  
  def detect_source
    case data
    when data['invoice_type'] == 'tax_invoice'
      if data['seller']['name'].include?('Amazon')
        :amazon
      elsif data['seller']['name'].include?('Flipkart')
        :flipkart
      else
        :local_b2b
      end
    end
  end
  
  def extract_line_items
    (data['line_items'] || []).map.with_index do |item, idx|
      {
        sl_no: idx + 1,
        description: item['description'],
        hsn_sac: item['hsn_sac'],
        quantity: item['quantity'].to_f,
        unit_price: item['unit_price'].to_f,
        taxable_value: item['taxable_value'].to_f,
        cgst_rate: item['cgst_rate'],
        cgst_amount: item['cgst_amount'],
        sgst_rate: item['sgst_rate'],
        sgst_amount: item['sgst_amount'],
        igst_rate: item['igst_rate'],
        igst_amount: item['igst_amount'],
        total_amount: item['total_amount'].to_f
      }
    end
  end
  
  def extract_totals
    {
      taxable_value: data['totals']['taxable_value'].to_f,
      cgst_total: data['totals']['cgst']&.to_f,
      sgst_total: data['totals']['sgst']&.to_f,
      igst_total: data['totals']['igst']&.to_f,
      total_tax_amount: calculate_total_tax,
      total_invoice_value: data['totals']['total_invoice_value'].to_f
    }
  end
end
```

---

## 2. Tally Parser Template

**Handles:** Tally JSON export format (ledger-based accounting format)

### Input Structure
```javascript
{
  header: {
    version: "1",
    request_type: "Import",
    type: "Voucher",
    company: "My Company Pvt Ltd"
  },
  body: {
    voucher: {
      voucher_type: "Sales",
      date: "20260122",
      voucher_number: "INV-2026-001",
      party_name: "R Chitra Devi",
      party_gstin: "33AAAAA0000A1Z5",
      place_of_supply: "Tamil Nadu",
      ledger_entries: [
        {
          ledger_name: "R Chitra Devi",
          is_debit: true,
          amount: 20000.0
        },
        {
          ledger_name: "Sales - Consulting",
          is_debit: false,
          amount: 16949.15,
          inventory_allocations: [{
            stock_item_name: "Consulting Services",
            hsn_or_sac: "998319",
            rate: 5000,
            quantity: 1
          }]
        }
      ]
    }
  }
}
```

### Parser Logic
- Extract invoice_number from `voucher.voucher_number`
- Parse date from Tally format "YYYYMMDD" → ISO 8601
- Buyer from `voucher.party_name`
- Line items reconstructed from `inventory_allocations` 
- Tax extracted from separate ledger entries (Output GST, etc.)

---

## 3. Zoho Parser Template

**Handles:** Zoho Invoice exports (REST API format)

### Key Differences from Tally
- Line items have `tax_id`, `tax_name`, `tax_percentage` (separate fields)
- Address split into `billing_address` + `shipping_address` objects
- Multiple address fields (attention, address, city, state, zip, country)
- Tax calculated as percentage on rate

### Extraction Logic
```python
# Reconstructed line items:
line_item = {
  description: item['name'],
  hsn_sac: item['hsn_or_sac'],
  quantity: item['quantity'],
  unit_price: item['rate'],
  taxable_value: item['rate'] * item['quantity'],
  total_tax_amount: (item['rate'] * item['quantity']) * (item['tax_percentage'] / 100),
  total_amount: (item['rate'] * item['quantity']) * (1 + item['tax_percentage'] / 100)
}

# Tax treatment based on place_of_supply:
place_of_supply = item['place_of_supply']  # "TN" format
if intra_state(place_of_supply):
  cgst_rate = tax_percentage / 2
  sgst_rate = tax_percentage / 2
else:
  igst_rate = tax_percentage
```

---

## 4. CSV Parser Template

**Handles:** Jiomart Invoice Report, Marketplace exports

### Input Structure (Jiomart Example)
- Headers: 85+ columns (Seller GSTIN, Order ID, Product Title, HSN Code, IGST Rate, IGST Amount, etc.)
- Multiple rows = multiple line items for same invoice
- Need to group by `Buyer Invoice ID` to create single invoice records

### Parsing Strategy
```python
# Step 1: Validate CSV headers have required GST fields
required_headers = [
  'Buyer Invoice ID',
  'Buyer Invoice Date',
  'Buyer Invoice Amount',
  'HSN Code',
  'Item Quantity',
  'IGST Rate',
  'IGST Amount',
  'CGST Rate',
  'CGST Amount'
]

# Step 2: Group rows by Buyer Invoice ID
invoices_grouped = rows.group_by { |row| row['Buyer Invoice ID'] }

# Step 3: For each invoice group, aggregate:
for invoice_id, line_rows in invoices_grouped:
  invoice = {
    invoice_number: invoice_id,
    invoice_date: line_rows[0]['Buyer Invoice Date'],
    line_items: line_rows.map_with_index do |row, idx|
      {
        sl_no: idx + 1,
        description: row['Product Title/Description'],
        hsn_sac: row['HSN Code'],
        quantity: row['Item Quantity'],
        unit_price: row['Buyer Invoice Amount'] / row['Item Quantity'],
        taxable_value: row['Taxable Value (Final Invoice Amount -Taxes)'],
        igst_rate: row['IGST Rate'],
        igst_amount: row['IGST Amount'],
        cgst_rate: row['CGST Rate'],
        cgst_amount: row['CGST Amount'],
        sgst_rate: row['SGST Rate'],
        sgst_amount: row['SGST Amount'],
        total_amount: row['Final Invoice Amount']
      }
    },
    totals: aggregate_totals(line_rows)
  }
```

---

## 5. Excel Parser Template

**Handles:** Flipkart seller reports, Kithab sales reports

### Tech Stack
```ruby
# Use gem 'roo' for Excel parsing (supports .xlsx, .xls, .csv)
require 'roo'

class ExcelParser
  def initialize(file_path)
    @excel = Roo::Spreadsheet.open(file_path)
    @sheet = @excel.sheet(0)  # First sheet
  end
  
  def extract
    headers = @sheet.row(1)  # First row = headers
    
    # Detect sheet type (Flipkart vs Kithab vs generic)
    sheet_type = detect_sheet_format(headers)
    
    # Parse based on format
    case sheet_type
    when :flipkart_seller_report
      parse_flipkart_format
    when :kithab_report
      parse_kithab_format
    else
      parse_generic_invoice_format
    end
  end
  
  private
  
  def parse_flipkart_format
    # Flipkart: Columns Order ID, Order Item ID, Order Date, Product, Qty, Price, IGST, CGST, SGST
    # Group by Order ID → create invoice per order
  end
  
  def parse_kithab_format
    # Kithab: Columns Invoice, Date, Customer, Description, HSN, Qty, Rate, Tax
    # Convert directly to line items
  end
end
```

---

## 6. PDF Parser Template

**Handles:** Unstructured PDF invoices (AC GST, Generic, etc.)

### Tech Stack
```python
# backend/Gemfile additions
gem 'pdf-reader'         # For PDF text extraction
gem 'pdfplumber'         # Python library (call via subprocess)
```

### Strategy
1. **Template Matching:** Detect invoice type from header/footer patterns
2. **Zone Extraction:** Define rectangular zones for different invoice elements
3. **Regex Pattern Matching:** Extract values with context-aware patterns

### Implementation Approach

```python
# backend/app/services/invoice_extraction/parsers/pdf_parser.rb

class PdfParser
  INVOICE_TEMPLATES = {
    ac_gst: AcGstTemplate,
    generic_indian: GenericIndianTemplate,
    amazon_print: AmazonPrintTemplate
  }
  
  def initialize(pdf_path)
    @pdf_path = pdf_path
    @raw_text = extract_text_pdfplumber
    @template = detect_template
  end
  
  def extract
    raise "Unknown invoice template" unless @template
    @template.extract(raw_text)
  end
  
  private
  
  def extract_text_pdfplumber
    # Call Python pdfplumber via subprocess
    cmd = %(python3 -c "
import pdfplumber
with pdfplumber.open('#{@pdf_path}') as pdf:
  for page in pdf.pages:
    print(page.extract_text())
")
    `#{cmd}`
  end
  
  def detect_template
    case @raw_text
    when /AC GST|AC Tax Invoice/i
      INVOICE_TEMPLATES[:ac_gst]
    when /GSTIN.*IGST|Tax Invoice/i
      INVOICE_TEMPLATES[:generic_indian]
    else
      INVOICE_TEMPLATES[:generic_indian]  # Fallback
    end
  end
end
```

### Template Example: AC GST Invoice
```ruby
class AcGstTemplate
  def self.extract(text)
    {
      invoice_number: extract_invoice_number(text),
      invoice_date: extract_invoice_date(text),
      seller: extract_seller_section(text),
      buyer: extract_buyer_section(text),
      line_items: extract_line_items_table(text),
      totals: extract_totals_section(text),
      extraction_confidence: calculate_confidence(text)
    }
  end
  
  private
  
  def self.extract_invoice_number(text)
    text.match(/Invoice\s*#?\s*:?\s*([A-Z0-9\-\/]+)/i)&.[](1)
  end
  
  def self.extract_invoice_date(text)
    date_pattern = /Invoice Date\s*:?\s*(\d{1,2}[-\/]\d{1,2}[-\/]\d{4})/i
    match = text.match(date_pattern)
    return nil unless match
    Date.strptime(match[1], '%d-%m-%Y').iso8601
  end
  
  def self.extract_line_items_table(text)
    # Find table by HSN/SAC column header
    # Extract rows between table headers and totals section
    # CSV parsing of extracted table text
  end
end
```

---

## Database Schema

### PostgreSQL Tables

```sql
-- Main invoices table
CREATE TABLE extracted_invoices (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id),
  
  -- Identifiers
  source_format VARCHAR(20),  -- json, tally, zoho, csv, excel, pdf
  source_type VARCHAR(20),    -- amazon, flipkart, jiomart, local_b2b, generic
  invoice_number VARCHAR(255) NOT NULL,
  invoice_date DATE NOT NULL,
  tax_invoice_type VARCHAR(50),
  
  -- Seller
  seller_name VARCHAR(255),
  seller_gstin VARCHAR(20),
  seller_pan VARCHAR(10),
  seller_address TEXT,
  seller_state VARCHAR(2),
  
  -- Buyer
  buyer_name VARCHAR(255),
  buyer_gstin VARCHAR(20),
  buyer_address TEXT,
  buyer_state VARCHAR(2),
  
  -- Tax Info
  place_of_supply VARCHAR(2),
  gst_treatment VARCHAR(50),
  
  -- Totals
  taxable_value DECIMAL(12,2),
  cgst_total DECIMAL(12,2),
  sgst_total DECIMAL(12,2),
  igst_total DECIMAL(12,2),
  total_tax_amount DECIMAL(12,2),
  total_invoice_value DECIMAL(12,2),
  
  -- Metadata
  extraction_timestamp TIMESTAMP DEFAULT NOW(),
  extraction_confidence NUMERIC(3,0),  -- 0-100
  extraction_warnings TEXT,
  raw_json_data JSONB,  -- Full extracted data
  
  -- Status & Audit
  status VARCHAR(50) DEFAULT 'extracted',  -- extracted, validated, reconciled, synced
  mapped_to_sales_invoice_id BIGINT REFERENCES sales_invoices(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(organization_id, invoice_number, invoice_date)
);

-- Line items table
CREATE TABLE extracted_invoice_line_items (
  id BIGSERIAL PRIMARY KEY,
  extracted_invoice_id BIGINT NOT NULL REFERENCES extracted_invoices(id) ON DELETE CASCADE,
  
  sl_no INTEGER,
  description VARCHAR(500),
  hsn_sac VARCHAR(20),
  quantity DECIMAL(10,3),
  unit VARCHAR(50),
  unit_price DECIMAL(12,2),
  taxable_value DECIMAL(12,2),
  cgst_rate NUMERIC(5,2),
  cgst_amount DECIMAL(12,2),
  sgst_rate NUMERIC(5,2),
  sgst_amount DECIMAL(12,2),
  igst_rate NUMERIC(5,2),
  igst_amount DECIMAL(12,2),
  total_tax_amount DECIMAL(12,2),
  total_amount DECIMAL(12,2),
  
  created_at TIMESTAMP DEFAULT NOW()
);

-- Extraction audit log
CREATE TABLE extraction_audit_logs (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id),
  
  file_name VARCHAR(255),
  file_size INTEGER,
  source_format VARCHAR(20),
  
  status VARCHAR(50),  -- success, failed, partial
  error_message TEXT,
  extraction_duration_ms INTEGER,
  
  extracted_invoices_count INTEGER,
  extracted_line_items_count INTEGER,
  
  created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_extracted_invoices_org_date ON extracted_invoices(organization_id, invoice_date);
CREATE INDEX idx_extracted_invoices_number ON extracted_invoices(organization_id, invoice_number);
CREATE INDEX idx_extraction_logs_org ON extraction_audit_logs(organization_id, created_at);
```

---

## Backend Implementation Structure

```
backend/
├── app/
│   ├── services/
│   │   └── invoice_extraction/
│   │       ├── extractor.rb              # Main orchestrator
│   │       ├── format_detector.rb        # Detect file format
│   │       ├── parsers/
│   │       │   ├── base_parser.rb
│   │       │   ├── json_parser.rb
│   │       │   ├── tally_parser.rb
│   │       │   ├── zoho_parser.rb
│   │       │   ├── csv_parser.rb
│   │       │   ├── excel_parser.rb
│   │       │   └── pdf_parser.rb
│   │       ├── templates/
│   │       │   ├── invoice_template.rb
│   │       │   ├── ac_gst_template.rb
│   │       │   └── generic_template.rb
│   │       ├── normalizers/
│   │       │   ├── unified_normalizer.rb
│   │       │   └── tax_normalizer.rb
│   │       └── validators/
│   │           ├── schema_validator.rb
│   │           └── business_rules_validator.rb
│   ├── models/
│   │   ├── extracted_invoice.rb
│   │   └── extraction_audit_log.rb
│   ├── controllers/
│   │   └── api/
│   │       └── v1/
│   │           └── invoice_extractions_controller.rb
├── app/
│   ├── services/
│   │   └── python_services/
│   │       └── pdf_extractor.py          # PDF text extraction
```

---

## API Endpoint

```ruby
# POST /api/v1/invoice_extractions
# 
# Multipart form with file upload
# Returns: extracted invoice data + extraction_id for auditing

# Response:
{
  status: "success",
  extraction_id: "uuid",
  extracted_invoices: [
    {
      invoice_number: "INV-2026-001",
      invoice_date: "2026-01-22",
      seller: {...},
      buyer: {...},
      line_items: [...],
      totals: {...},
      extraction_confidence: 95,
      warnings: []
    }
  ],
  audit_log: {
    file_name: "Invoice-577428.pdf",
    source_format: "pdf",
    extracted_invoices_count: 1,
    extracted_line_items_count: 5,
    extraction_duration_ms: 1250,
    created_at: "2026-03-21T10:30:00Z"
  }
}
```

---

## Validation & Error Handling

### Validation Layers
1. **Schema Validation:** Ensure all required fields present
2. **Business Rules:** GSTIN format, date validity, tax calculations
3. **Data Quality:** Confidence scoring based on field completeness

### Confidence Scoring
```python
confidence_score = (
  (required_fields_found / total_required) * 40 +
  (optional_fields_found / total_optional) * 20 +
  (tax_calculations_verified) * 20 +
  (format_consistency_check) * 20
) * 100
```

---

## Integration with OrderLane

### Mapping to SalesInvoice
```ruby
extracted_invoice.map_to_sales_invoice!(current_organization) do
  {
    invoice_number: extracted_invoice.invoice_number,
    invoice_date: extracted_invoice.invoice_date,
    customer_id: find_or_create_customer(extracted_invoice.buyer),
    line_items: extracted_invoice.line_items,
    total_amount: extracted_invoice.totals.total_invoice_value,
    gst_rate: calculate_effective_gst_rate,
    status: 'recognized_via_extraction'
  }
end
```

---

## Phase Implementation (Priority Order)

| Phase | Component | Effort | Timeline |
|-------|-----------|--------|----------|
| **1** | JSON Parser (Amazon, Flipkart, Local) | 2 days | Week 1 |
| **1** | Database Schema + Models | 1 day | Week 1 |
| **1** | API Endpoint + Upload | 1.5 days | Week 1 |
| **2** | CSV Parser (Jiomart) | 1 day | Week 2 |
| **2** | Excel Parser (Flipkart, Kithab) | 1.5 days | Week 2 |
| **3** | PDF Parser (AC GST, Generic) | 3 days | Week 2-3 |
| **3** | Tally + Zoho Parsers | 1.5 days | Week 3 |
| **4** | Validation & Error Handling | 1 day | Week 3 |
| **4** | SalesInvoice Sync Integration | 1.5 days | Week 3-4 |
| **5** | Frontend Upload UI | 2 days | Week 4 |
| **5** | Testing + Documentation | 2 days | Week 4 |

**Total Effort:** ~18-20 days (3 weeks with team)

---

## Key Decisions Made

✅ **PostgreSQL for extracted data** - Structured querying, audit capability  
✅ **Separate parsers per format** - Handles quirks without generic bloat  
✅ **pdfplumber for PDF extraction** - Balance of accuracy & maintainability  
✅ **Unified schema with optional fields** - Flexibility + consistency  
✅ **95-100% confidence for JSON, 70-90% for PDF** - Realistic expectations  
✅ **Audit logging mandatory** - Compliance & debugging
