/**
 * Shared Zod schemas for form validation.
 *
 * These match the backend model validations so that client-side validation
 * mirrors server-side rules. Import individual schemas where needed:
 *
 *   import { customerSchema } from "@/lib/schemas";
 *   const form = useForm({ resolver: zodResolver(customerSchema) });
 */
import { z } from "zod";

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Non-empty trimmed string. */
const requiredString = (label: string) =>
  z.string().trim().min(1, `${label} is required`);

/** Positive number. */
const positiveNumber = (label: string) =>
  z.coerce.number().min(0, `${label} must be ≥ 0`);

// ── Customer ─────────────────────────────────────────────────────────────────

export const customerSchema = z.object({
  name: requiredString("Name"),
  code: requiredString("Code")
    .max(20, "Code must be ≤ 20 characters")
    .regex(/^[A-Za-z0-9_-]+$/, "Code can only contain letters, numbers, hyphens and underscores"),
  channel: z.string().optional(),
  tier: z.enum(["platinum", "gold", "silver", "bronze"]).optional(),
  phone: z
    .string()
    .trim()
    .regex(/^\+?\d{7,15}$/, "Invalid phone number")
    .optional()
    .or(z.literal("")),
  email: z.string().email("Invalid email").optional().or(z.literal("")),
  credit_limit: positiveNumber("Credit limit").optional().default(0),
  gstin: z
    .string()
    .trim()
    .regex(/^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}$/, "Invalid GSTIN format")
    .optional()
    .or(z.literal("")),
  route_id: z.coerce.number().positive().optional().nullable(),
  branch_id: z.coerce.number().positive("Branch is required"),
});

export type CustomerFormData = z.infer<typeof customerSchema>;

// ── Product ──────────────────────────────────────────────────────────────────

export const productSchema = z.object({
  name: requiredString("Product name"),
  sku: requiredString("SKU")
    .max(30, "SKU must be ≤ 30 characters"),
  hsn_code: z.string().trim().optional().or(z.literal("")),
  unit_price: z.coerce.number().min(0, "Price must be ≥ 0"),
  gst_rate: z.coerce.number().min(0).max(100, "GST rate must be 0–100"),
  category_id: z.coerce.number().positive().optional().nullable(),
  uom_id: z.coerce.number().positive().optional().nullable(),
  status: z.enum(["active", "discontinued"]).default("active"),
});

export type ProductFormData = z.infer<typeof productSchema>;

// ── Sales Order ──────────────────────────────────────────────────────────────

const orderLineSchema = z.object({
  product_id: z.coerce.number().positive("Product is required"),
  qty: z.coerce.number().positive("Qty must be > 0"),
  unit_price: z.coerce.number().min(0, "Price must be ≥ 0"),
  discount_pct: z.coerce.number().min(0).max(100).default(0),
});

export const salesOrderSchema = z.object({
  customer_id: z.coerce.number().positive("Customer is required"),
  branch_id: z.coerce.number().positive("Branch is required"),
  delivery_date: z.string().optional(),
  notes: z.string().trim().max(2000).optional().or(z.literal("")),
  lines: z.array(orderLineSchema).min(1, "At least one line item is required"),
});

export type SalesOrderFormData = z.infer<typeof salesOrderSchema>;

// ── Payment ──────────────────────────────────────────────────────────────────

export const paymentSchema = z.object({
  customer_id: z.coerce.number().positive("Customer is required"),
  amount: z.coerce.number().positive("Amount must be > 0"),
  payment_mode: z.enum(["cash", "cheque", "upi", "neft", "rtgs", "razorpay", "other"]),
  received_date: requiredString("Received date"),
  reference_number: z.string().trim().optional().or(z.literal("")),
  notes: z.string().trim().max(2000).optional().or(z.literal("")),
});

export type PaymentFormData = z.infer<typeof paymentSchema>;

// ── Login ────────────────────────────────────────────────────────────────────

export const loginSchema = z.object({
  email: z.string().trim().email("Valid email is required"),
  password: requiredString("Password").min(8, "Password must be at least 8 characters"),
});

export type LoginFormData = z.infer<typeof loginSchema>;
