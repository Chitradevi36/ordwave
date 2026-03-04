import React, { useState, useEffect } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
  SafeAreaView, ActivityIndicator,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { colors, spacing, typography, borderRadius, shadows } from '../theme';
import { Card } from '../components/Card';
import { StatusPill } from '../components/StatusPill';

// ─── Types ────────────────────────────────────────────────────────────────────
interface Address {
  id: number; label: string; line1: string; line2?: string;
  city: string; state: string; postal_code: string; country: string;
}
interface Contact {
  id: number; name: string; phone?: string; email?: string;
  designation?: string; is_primary: boolean;
}
interface CreditAccount {
  id: number; credit_limit: number; current_balance: number;
  available_credit: number; overdue_amount: number; overdue_days: number;
}
interface CustomerDetail {
  id: number; name: string; code: string; channel: string; tier: string; status: string;
  phone: string | null; email: string | null; gstin: string | null; pan: string | null;
  credit_limit: number;
  route: { id: number; name: string; code: string } | null;
  credit_account: CreditAccount | null;
  addresses: Address[];
  contacts: Contact[];
}

interface CustomerDetailScreenProps {
  customerId: number;
  onBack: () => void;
}

const CHANNEL_LABELS: Record<string, string> = {
  general_trade: 'General Trade', modern_trade: 'Modern Trade', horeca: 'HoReCa',
  pharmacy: 'Pharmacy', electronics: 'Electronics', wholesale: 'Wholesale', distributor: 'Distributor',
};

type Tab = 'overview' | 'contacts' | 'addresses' | 'credit';

// ─── Row helper ───────────────────────────────────────────────────────────────
function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={rowStyles.row}>
      <Text style={rowStyles.label}>{label}</Text>
      <Text style={rowStyles.value}>{value || '—'}</Text>
    </View>
  );
}
const rowStyles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  label: { ...typography.bodySmall, color: colors.textSecondary },
  value: { ...typography.body, fontWeight: '500', maxWidth: '65%', textAlign: 'right' },
});

// ─── Screen ───────────────────────────────────────────────────────────────────
export default function CustomerDetailScreen({ customerId, onBack }: CustomerDetailScreenProps) {
  const [customer, setCustomer] = useState<CustomerDetail | null>(null);
  const [loading,  setLoading]  = useState(false);
  const [blocking, setBlocking] = useState(false);
  const [tab,      setTab]      = useState<Tab>('overview');

  const loadCustomer = async () => {
    setLoading(true);
    try {
      const token = await AsyncStorage.getItem('auth_token');
      const orgId = await AsyncStorage.getItem('org_id');
      if (!token || !orgId) return;

      const res  = await fetch(`http://localhost:3001/api/v1/customers/${customerId}`, {
        headers: { Authorization: `Bearer ${token}`, 'X-Organization-Id': orgId },
      });
      const json = await res.json();
      if (res.ok) setCustomer(json.data);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadCustomer(); }, [customerId]); // eslint-disable-line react-hooks/exhaustive-deps

  const handleBlockToggle = async () => {
    if (!customer) return;
    const action = customer.status === 'blocked' ? 'unblock' : 'block';
    setBlocking(true);
    try {
      const token = await AsyncStorage.getItem('auth_token');
      const orgId = await AsyncStorage.getItem('org_id');
      if (!token || !orgId) return;
      const res = await fetch(`http://localhost:3001/api/v1/customers/${customerId}/${action}`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'X-Organization-Id': orgId },
      });
      if (res.ok) {
        setCustomer((prev: CustomerDetail | null) => prev ? { ...prev, status: action === 'block' ? 'blocked' : 'active' } : prev);
      }
    } finally {
      setBlocking(false);
    }
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.centered}>
          <ActivityIndicator size="large" color={colors.accent} />
        </View>
      </SafeAreaView>
    );
  }

  if (!customer) {
    return (
      <SafeAreaView style={styles.container}>
        <TouchableOpacity style={styles.backBtn} onPress={onBack}>
          <Text style={styles.backText}>← Back</Text>
        </TouchableOpacity>
        <View style={styles.centered}>
          <Text style={styles.emptyText}>Customer not found.</Text>
        </View>
      </SafeAreaView>
    );
  }

  const ca = customer.credit_account;
  const utilPct = ca && ca.credit_limit > 0
    ? Math.min(100, Math.round((ca.current_balance / ca.credit_limit) * 100))
    : 0;

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView>
        {/* Back + Title */}
        <View style={styles.headerArea}>
          <TouchableOpacity onPress={onBack} style={styles.backBtn}>
            <Text style={styles.backText}>← Customers</Text>
          </TouchableOpacity>
          <View style={styles.titleRow}>
            <View style={{ flex: 1 }}>
              <Text style={styles.customerName}>{customer.name}</Text>
              <Text style={styles.customerCode}>{customer.code}</Text>
            </View>
            <View style={{ alignItems: 'flex-end', gap: spacing.xs }}>
              <StatusPill
                label={customer.status.charAt(0).toUpperCase() + customer.status.slice(1)}
                variant={customer.status === 'active' ? 'success' : customer.status === 'blocked' ? 'danger' : 'neutral'}
              />
              <TouchableOpacity
                onPress={handleBlockToggle}
                disabled={blocking}
                style={[styles.blockBtn, customer.status === 'blocked' && styles.unblockBtn]}
              >
                <Text style={styles.blockBtnText}>
                  {blocking ? '…' : customer.status === 'blocked' ? 'Unblock' : 'Block'}
                </Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>

        {/* Blocked Banner */}
        {customer.status === 'blocked' && (
          <View style={styles.blockedBanner}>
            <Text style={styles.blockedText}>🚫  This customer is blocked. No new orders can be placed.</Text>
          </View>
        )}

        {/* Overdue Banner */}
        {ca && ca.overdue_amount > 0 && (
          <View style={styles.overdueBanner}>
            <Text style={styles.overdueText}>
              ⚠️  Overdue: ₹{ca.overdue_amount.toLocaleString('en-IN')} · {ca.overdue_days} days
            </Text>
          </View>
        )}

        {/* Tabs */}
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.tabBar}
        >
          {(['overview', 'contacts', 'addresses', 'credit'] as Tab[]).map((t) => (
            <TouchableOpacity
              key={t}
              style={[styles.tabBtn, tab === t && styles.tabBtnActive]}
              onPress={() => setTab(t)}
            >
              <Text style={[styles.tabText, tab === t && styles.tabTextActive]}>
                {t.charAt(0).toUpperCase() + t.slice(1)}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>

        <View style={styles.tabContent}>
          {/* OVERVIEW */}
          {tab === 'overview' && (
            <Card>
              <InfoRow label="Channel" value={CHANNEL_LABELS[customer.channel] ?? customer.channel} />
              <InfoRow label="Tier"    value={customer.tier.charAt(0).toUpperCase() + customer.tier.slice(1)} />
              <InfoRow label="Route"   value={customer.route ? `${customer.route.name} (${customer.route.code})` : '—'} />
              <InfoRow label="Phone"   value={customer.phone ?? '—'} />
              <InfoRow label="Email"   value={customer.email ?? '—'} />
              {customer.gstin ? <InfoRow label="GSTIN" value={customer.gstin} /> : null}
              {customer.pan   ? <InfoRow label="PAN"   value={customer.pan}   /> : null}
            </Card>
          )}

          {/* CONTACTS */}
          {tab === 'contacts' && (
            customer.contacts.length === 0
              ? <Text style={styles.emptyText}>No contacts added.</Text>
              : customer.contacts.map((c) => (
                <Card key={c.id} style={styles.listCard}>
                  <View style={styles.contactHeader}>
                    <Text style={styles.contactName}>{c.name}</Text>
                    {c.is_primary && <StatusPill label="Primary" variant="success" />}
                  </View>
                  {c.designation ? <Text style={styles.contactSub}>{c.designation}</Text> : null}
                  {c.phone ? <Text style={styles.contactSub}>📞 {c.phone}</Text> : null}
                  {c.email ? <Text style={styles.contactSub}>✉️  {c.email}</Text> : null}
                </Card>
              ))
          )}

          {/* ADDRESSES */}
          {tab === 'addresses' && (
            customer.addresses.length === 0
              ? <Text style={styles.emptyText}>No addresses added.</Text>
              : customer.addresses.map((a) => (
                <Card key={a.id} style={styles.listCard}>
                  <StatusPill
                    label={a.label.charAt(0).toUpperCase() + a.label.slice(1)}
                    variant="neutral"
                  />
                  <Text style={styles.addressLine}>{a.line1}{a.line2 ? `, ${a.line2}` : ''}</Text>
                  <Text style={styles.addressSub}>{a.city}, {a.state} {a.postal_code}</Text>
                </Card>
              ))
          )}

          {/* CREDIT */}
          {tab === 'credit' && (
            ca ? (
              <View style={{ gap: spacing.md }}>
                {/* Stats grid */}
                <View style={styles.creditGrid}>
                  <CreditStat label="Limit"     value={`₹${ca.credit_limit.toLocaleString('en-IN')}`} />
                  <CreditStat label="Available" value={`₹${ca.available_credit.toLocaleString('en-IN')}`} positive />
                  <CreditStat label="Balance"   value={`₹${ca.current_balance.toLocaleString('en-IN')}`} />
                  <CreditStat label="Overdue"   value={`₹${ca.overdue_amount.toLocaleString('en-IN')}`} danger={ca.overdue_amount > 0} />
                </View>

                {/* Utilisation bar */}
                <Card>
                  <View style={styles.utilRow}>
                    <Text style={styles.utilLabel}>Credit Utilisation</Text>
                    <Text style={styles.utilPct}>{utilPct}%</Text>
                  </View>
                  <View style={styles.barBg}>
                    <View
                      style={[
                        styles.barFill,
                        {
                          width: `${utilPct}%`,
                          backgroundColor: utilPct >= 90 ? colors.danger : utilPct >= 70 ? colors.warning : colors.accent,
                        },
                      ]}
                    />
                  </View>
                  {ca.overdue_days > 0 && (
                    <Text style={styles.overdueDays}>{ca.overdue_days} days overdue</Text>
                  )}
                </Card>
              </View>
            ) : (
              <Text style={styles.emptyText}>No credit account.</Text>
            )
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

function CreditStat({ label, value, positive, danger }: {
  label: string; value: string; positive?: boolean; danger?: boolean;
}) {
  return (
    <Card style={creditStatStyles.card}>
      <Text style={creditStatStyles.label}>{label}</Text>
      <Text style={[creditStatStyles.value, danger && { color: colors.danger }, positive && { color: colors.accent }]}>
        {value}
      </Text>
    </Card>
  );
}
const creditStatStyles = StyleSheet.create({
  card: { flex: 1, minWidth: '45%', margin: spacing.xs },
  label: { ...typography.bodySmall, marginBottom: 4 },
  value: { fontSize: 16, fontWeight: '700', color: colors.textPrimary },
});

// ─── Styles ───────────────────────────────────────────────────────────────────
const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.backgroundSubtle },
  centered:  { flex: 1, justifyContent: 'center', alignItems: 'center', padding: spacing.xl },
  headerArea: { padding: spacing.lg },
  backBtn:    { marginBottom: spacing.md },
  backText:   { ...typography.bodySmall, color: colors.accent, fontWeight: '600' },
  titleRow:   { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.sm },
  customerName: { ...typography.h3 },
  customerCode: { ...typography.bodySmall, marginTop: 2 },

  overdueBanner: {
    marginHorizontal: spacing.lg,
    marginBottom: spacing.md,
    padding: spacing.md,
    borderRadius: borderRadius.md,
    backgroundColor: '#FEE2E2',
    borderWidth: 1,
    borderColor: '#FECACA',
  },
  overdueText: { fontSize: 13, fontWeight: '600', color: colors.danger },

  blockedBanner: {
    marginHorizontal: spacing.lg,
    marginBottom: spacing.md,
    padding: spacing.md,
    borderRadius: borderRadius.md,
    backgroundColor: '#FEF3C7',
    borderWidth: 1,
    borderColor: '#FDE68A',
  },
  blockedText: { fontSize: 13, fontWeight: '600', color: '#92400E' },

  blockBtn: {
    paddingHorizontal: spacing.sm + 2,
    paddingVertical: 4,
    borderRadius: borderRadius.sm,
    backgroundColor: '#FEE2E2',
    borderWidth: 1,
    borderColor: '#FECACA',
  },
  unblockBtn: {
    backgroundColor: '#D1FAE5',
    borderColor: '#6EE7B7',
  },
  blockBtnText: { fontSize: 11, fontWeight: '600', color: colors.danger },

  tabBar: {
    paddingHorizontal: spacing.lg,
    gap: spacing.sm,
    marginBottom: spacing.sm,
  },
  tabBtn: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs + 2,
    borderRadius: borderRadius.full,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.background,
    marginRight: spacing.sm,
  },
  tabBtnActive: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  tabText: { fontSize: 13, fontWeight: '500', color: colors.textSecondary },
  tabTextActive: { color: colors.white },

  tabContent: { paddingHorizontal: spacing.lg, paddingBottom: spacing.xxl },

  listCard:  { marginBottom: spacing.md, ...shadows.sm },
  emptyText: { ...typography.body, color: colors.textSecondary, textAlign: 'center', marginTop: spacing.xl },

  contactHeader: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: spacing.xs },
  contactName:   { ...typography.label, fontWeight: '600' },
  contactSub:    { ...typography.bodySmall, marginTop: 2 },

  addressLine: { ...typography.body, marginTop: spacing.sm },
  addressSub:  { ...typography.bodySmall, marginTop: 2 },

  creditGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },

  utilRow:  { flexDirection: 'row', justifyContent: 'space-between', marginBottom: spacing.sm },
  utilLabel: { ...typography.bodySmall },
  utilPct:   { ...typography.bodySmall, fontWeight: '600' },
  barBg:    { height: 8, borderRadius: borderRadius.full, backgroundColor: colors.border, overflow: 'hidden' },
  barFill:  { height: 8, borderRadius: borderRadius.full },
  overdueDays: { ...typography.bodySmall, color: colors.danger, marginTop: spacing.sm },
});
