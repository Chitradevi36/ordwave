import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  SafeAreaView,
  ScrollView,
  TextInput,
  ActivityIndicator,
  Alert,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { colors, spacing, typography, borderRadius } from '../theme';
import { Card } from '../components/Card';
import { PrimaryButton } from '../components/PrimaryButton';
import { FormField } from '../components/FormField';
import { AppBar } from '../components/AppBar';

const API_BASE = 'http://localhost:3001/api/v1';

interface SalesOrderLine {
  id: number;
  product_id: number;
  product_name: string;
  ordered_qty: number;
  delivered_qty: number;
  unit_price: number;
}

interface TripStop {
  id: number;
  sequence: number;
  delivery_trip: { id: number };
  sales_order: {
    id: number;
    order_number: string;
    customer: { name: string };
    total_amount: number;
    lines?: SalesOrderLine[];
  };
}

interface CompleteStopScreenProps {
  stop: TripStop;
  tripId: number;
  onBack: () => void;
  onCompleted: () => void;
}

const OUTCOMES = [
  { key: 'delivered',        label: 'Fully Delivered' },
  { key: 'partial_delivery', label: 'Partial Delivery' },
  { key: 'failed',           label: 'Failed' },
] as const;

const EXCEPTION_CODES = [
  'customer_not_available',
  'address_not_found',
  'refused_by_customer',
  'damaged_goods',
  'payment_not_ready',
  'vehicle_breakdown',
  'other',
];

const PROOF_TYPES = [
  { key: 'photo',     label: 'Photo' },
  { key: 'signature', label: 'Signature' },
  { key: 'otp',       label: 'OTP' },
  { key: 'override',  label: 'Override (No Proof)' },
] as const;

export default function CompleteStopScreen({
  stop,
  tripId,
  onBack,
  onCompleted,
}: CompleteStopScreenProps) {
  const [outcome, setOutcome]           = useState<string>('delivered');
  const [proofType, setProofType]       = useState<string>('photo');
  const [otp, setOtp]                   = useState('');
  const [overrideReason, setOverrideReason] = useState('');
  const [exceptionCode, setExceptionCode]   = useState('');
  const [deliveryNotes, setDeliveryNotes]   = useState('');
  const [submitting, setSubmitting]     = useState(false);

  // Per-line delivered quantities (default to ordered qty)
  const lines: SalesOrderLine[] = stop.sales_order.lines ?? [];
  const [deliveredQtys, setDeliveredQtys] = useState<Record<number, string>>(
    Object.fromEntries(lines.map((l) => [l.id, String(l.ordered_qty)]))
  );

  async function handleSubmit() {
    if (outcome === 'failed' && !exceptionCode) {
      Alert.alert('Validation', 'Please select an exception code for a failed stop.');
      return;
    }
    if (proofType === 'override' && !overrideReason.trim()) {
      Alert.alert('Validation', 'Override reason is required.');
      return;
    }

    const idempotencyKey = `${stop.id}-${Date.now()}`;

    const deliveredLines = lines.map((l) => ({
      sales_order_line_id: l.id,
      delivered_qty:       Number(deliveredQtys[l.id] ?? 0),
    }));

    setSubmitting(true);
    try {
      const token  = await AsyncStorage.getItem('auth_token');
      const orgId  = await AsyncStorage.getItem('organization_id');

      const res = await fetch(
        `${API_BASE}/delivery_trips/${tripId}/trip_stops/${stop.id}/complete`,
        {
          method:  'POST',
          headers: {
            Authorization:      `Bearer ${token}`,
            'X-Organization-Id': orgId ?? '',
            'Content-Type':      'application/json',
          },
          body: JSON.stringify({
            idempotency_key: idempotencyKey,
            trip_stop: {
              outcome,
              proof_type:      proofType,
              otp_code:        otp        || undefined,
              override_reason: overrideReason || undefined,
              exception_code:  exceptionCode || undefined,
              delivery_notes:  deliveryNotes || undefined,
              delivered_lines: outcome !== 'failed' ? deliveredLines : [],
            },
          }),
        }
      );

      const json = await res.json();
      if (res.ok) {
        onCompleted();
      } else {
        Alert.alert('Error', (json.errors ?? []).join('\n') || 'Failed to complete stop.');
      }
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <SafeAreaView style={styles.container}>
      <AppBar
        title={`Stop ${stop.sequence} — ${stop.sales_order.customer.name}`}
        leftAction={<TouchableOpacity onPress={onBack}><Text style={styles.backBtn}>‹ Back</Text></TouchableOpacity>}
      />

      <ScrollView contentContainerStyle={styles.scroll}>
        {/* Order summary */}
        <Card style={styles.section}>
          <Text style={styles.sectionTitle}>Order</Text>
          <View style={styles.row}>
            <Text style={styles.label}>Order No.</Text>
            <Text style={styles.value}>{stop.sales_order.order_number}</Text>
          </View>
          <View style={styles.row}>
            <Text style={styles.label}>Customer</Text>
            <Text style={styles.value}>{stop.sales_order.customer.name}</Text>
          </View>
          <View style={[styles.row, { borderBottomWidth: 0 }]}>
            <Text style={styles.label}>Amount</Text>
            <Text style={[styles.value, styles.bold]}>
              ₹{Number(stop.sales_order.total_amount).toLocaleString('en-IN', { maximumFractionDigits: 0 })}
            </Text>
          </View>
        </Card>

        {/* Outcome */}
        <Card style={styles.section}>
          <Text style={styles.sectionTitle}>Outcome *</Text>
          <View style={styles.chipRow}>
            {OUTCOMES.map((o) => (
              <TouchableOpacity
                key={o.key}
                style={[styles.chip, outcome === o.key && styles.chipActive]}
                onPress={() => setOutcome(o.key)}
              >
                <Text style={[styles.chipText, outcome === o.key && styles.chipTextActive]}>
                  {o.label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </Card>

        {/* Exception code — only for failed */}
        {outcome === 'failed' && (
          <Card style={styles.section}>
            <Text style={styles.sectionTitle}>Exception Code *</Text>
            <View style={styles.chipRow}>
              {EXCEPTION_CODES.map((code) => (
                <TouchableOpacity
                  key={code}
                  style={[styles.chip, exceptionCode === code && styles.chipDanger]}
                  onPress={() => setExceptionCode(code)}
                >
                  <Text style={[styles.chipText, exceptionCode === code && styles.chipTextActive]}>
                    {code.replace(/_/g, ' ')}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </Card>
        )}

        {/* Delivered quantities */}
        {outcome !== 'failed' && lines.length > 0 && (
          <Card style={styles.section}>
            <Text style={styles.sectionTitle}>Delivered Quantities</Text>
            {lines.map((line) => (
              <View key={line.id} style={styles.lineRow}>
                <View style={styles.lineInfo}>
                  <Text style={styles.lineName} numberOfLines={1}>{line.product_name}</Text>
                  <Text style={styles.lineOrdered}>Ordered: {line.ordered_qty}</Text>
                </View>
                <TextInput
                  style={styles.qtyInput}
                  keyboardType="number-pad"
                  value={deliveredQtys[line.id] ?? String(line.ordered_qty)}
                  onChangeText={(val) => setDeliveredQtys({ ...deliveredQtys, [line.id]: val })}
                />
              </View>
            ))}
          </Card>
        )}

        {/* Proof of delivery */}
        <Card style={styles.section}>
          <Text style={styles.sectionTitle}>Proof of Delivery</Text>
          <View style={styles.chipRow}>
            {PROOF_TYPES.map((p) => (
              <TouchableOpacity
                key={p.key}
                style={[styles.chip, proofType === p.key && styles.chipActive]}
                onPress={() => setProofType(p.key)}
              >
                <Text style={[styles.chipText, proofType === p.key && styles.chipTextActive]}>
                  {p.label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          {proofType === 'otp' && (
            <FormField label="OTP Code" style={{ marginTop: spacing.md }}>
              <TextInput
                style={styles.input}
                keyboardType="number-pad"
                maxLength={6}
                placeholder="Enter 6-digit OTP"
                value={otp}
                onChangeText={setOtp}
              />
            </FormField>
          )}

          {proofType === 'override' && (
            <FormField label="Override Reason *" style={{ marginTop: spacing.md }}>
              <TextInput
                style={[styles.input, styles.textArea]}
                multiline
                numberOfLines={3}
                placeholder="Why no standard proof?"
                value={overrideReason}
                onChangeText={setOverrideReason}
              />
            </FormField>
          )}
        </Card>

        {/* Notes */}
        <Card style={styles.section}>
          <Text style={styles.sectionTitle}>Delivery Notes</Text>
          <TextInput
            style={[styles.input, styles.textArea]}
            multiline
            numberOfLines={3}
            placeholder="e.g. Left with security guard"
            value={deliveryNotes}
            onChangeText={setDeliveryNotes}
          />
        </Card>

        <PrimaryButton
          label={submitting ? 'Submitting…' : 'Complete Stop'}
          onPress={handleSubmit}
          disabled={submitting}
          style={styles.submitBtn}
        />
      </ScrollView>

      {submitting && (
        <View style={styles.overlay}>
          <ActivityIndicator size="large" color={colors.primary} />
        </View>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  backBtn:       { color: colors.white, fontSize: 16, paddingRight: spacing.sm },
  container:      { flex: 1, backgroundColor: colors.backgroundSubtle },
  scroll:         { padding: spacing.lg, paddingBottom: 60 },
  section:        { marginBottom: spacing.md },
  sectionTitle:   { ...typography.label, fontWeight: '600', marginBottom: spacing.sm, color: colors.textSecondary, textTransform: 'uppercase', fontSize: 11, letterSpacing: 0.5 },
  row:            { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: spacing.xs, borderBottomWidth: 1, borderBottomColor: colors.border },
  label:          { ...typography.bodySmall },
  value:          { ...typography.body },
  bold:           { fontWeight: '700' },
  chipRow:        { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  chip:           { paddingHorizontal: spacing.md, paddingVertical: spacing.xs, borderRadius: borderRadius.full, backgroundColor: colors.border },
  chipActive:     { backgroundColor: colors.primary },
  chipDanger:     { backgroundColor: colors.danger },
  chipText:       { ...typography.bodySmall, fontWeight: '500', textTransform: 'capitalize' },
  chipTextActive: { color: colors.white },
  input:          { borderWidth: 1, borderColor: colors.border, borderRadius: borderRadius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.sm, ...typography.body, backgroundColor: colors.white },
  textArea:       { minHeight: 80, textAlignVertical: 'top' },
  lineRow:        { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.sm, borderBottomWidth: 1, borderBottomColor: colors.border, gap: spacing.sm },
  lineInfo:       { flex: 1 },
  lineName:       { ...typography.label },
  lineOrdered:    { ...typography.bodySmall, color: colors.textSecondary },
  qtyInput:       { width: 60, borderWidth: 1, borderColor: colors.border, borderRadius: borderRadius.sm, paddingHorizontal: spacing.sm, paddingVertical: spacing.xs, textAlign: 'center', ...typography.body, backgroundColor: colors.white },
  submitBtn:      { marginTop: spacing.md },
  overlay:        { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(255,255,255,0.7)', alignItems: 'center', justifyContent: 'center' },
});
