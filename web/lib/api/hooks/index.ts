// Barrel export for all React Query hooks.
// Import from "@/lib/api/hooks" instead of individual files.

export { useApprovals, useApproveOrder } from "./useApprovals";
export type { HeldOrder, CreditRequest, ApprovalsData } from "./useApprovals";

export { useBankAccounts } from "./useBankAccounts";

export { useBankStatementImports } from "./useBankStatementImports";

export { useBankTransactions } from "./useBankTransactions";

export {
  useBillingSubscription,
  useBillingInvoices,
  useBillingActions,
} from "./useBilling";

export { useCustomers, useCustomer, useBlockCustomer, useCreateCustomer, useUpdateCustomer } from "./useCustomers";
export type { Customer, CustomersParams, CustomersResponse, CreditAccount, CreditUsageSummary } from "./useCustomers";

export { useDashboardData } from "./useDashboard";
export type { DashboardData, DashboardAlert } from "./useDashboard";

export { useNotifications } from "./useNotifications";

export { useOrders } from "./useOrders";
export type { Order, OrdersParams, OrdersResponse } from "./useOrders";

export { usePayments, usePayment, useCreatePayment, useConfirmPayment } from "./usePayments";
export type { Payment, PaymentsParams, PaymentsResponse } from "./usePayments";

export { usePlanInfo } from "./usePlanInfo";

export { useProducts, useProduct, useCreateProduct, useUpdateProduct, useDiscontinueProduct } from "./useProducts";
export type { Product, ProductsParams, ProductsResponse } from "./useProducts";

export { useRetailerRisk } from "./useRetailerRisk";

export { useSalesInvoices, useSalesInvoice, useVoidInvoice } from "./useSalesInvoices";
export type { SalesInvoice, InvoicesParams, InvoicesResponse } from "./useSalesInvoices";
