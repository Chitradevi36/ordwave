import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { colors, spacing, borderRadius, typography } from '../theme';
import { Banner } from './Banner';
import { PrimaryButton } from './PrimaryButton';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface CreditMetrics {
  credit_limit?:   number;
  outstanding?:    number;
  available?:      number;
  overdue_days?:   number;
  order_total?:    number;
}

export interface CreditResultData {
  decision:         'ok' | 'hold' | 'blocked';
  reasons:          string[];
  metrics:          CreditMetrics;
  actions_required: {
    collection_required?: boolean;
    prepayment_required?: number[];
    approval_required?:   boolean;
  };
}

export interface CreditResultBannerProps {
  credit:       CreditResultData;
  orderNumber?: string;
  onRecordCollection?: () => void;
  onRequestLimitChange?: () => void;
  onViewOrder?: () => void;
  onSaveAsDraft?: () => void;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function fmtINR(n: number | undefined): string {
  if (n === undefined || n === null) return '—';
  return `₹${n.toLocaleString('en-IN', { maximumFractionDigits: 0 })}`;
}

function MetricRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.metricRow}>
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={styles.metricValue}>{value}</Text>
    </View>
  );
}

// ─── Main Component ───────────────────────────────────────────────────────────

export function CreditResultBanner({
  credit,
  orderNumber,
  onRecordCollection,
  onRequestLimitChange,
  onViewOrder,
  onSaveAsDraft,
}: CreditResultBannerProps) {
  const [showMetrics, setShowMetrics] = useState(credit.decision !== 'ok');

  // ── OK ────────────────────────────────────────────────────────────────────
  if (credit.decision === 'ok') {
    return (
      <View style={styles.container}>
        <Banner
          variant="success"
          title="Credit check passed"
          message={
            orderNumber
              ? `Order ${orderNumber} submitted successfully.`
              : 'Order submitted successfully.'
          }
        />
        {onViewOrder && (
          <PrimaryButton title="View Order" onPress={onViewOrder} />
        )}
      </View>
    );
  }

  // ── HOLD ──────────────────────────────────────────────────────────────────
  if (credit.decision === 'hold') {
    return (
      <View style={styles.container}>
        <Banner
          variant="warning"
          title="Order sent for approval"
          message="This order is on hold and requires manager approval before proceeding."
        />

        {credit.reasons.length > 0 && (
          <View style={styles.reasonsBox}>
            <Text style={styles.reasonsTitle}>Reasons</Text>
            {credit.reasons.map((r, i) => (
              <Text key={i} style={styles.reasonItem}>• {r}</Text>
            ))}
          </View>
        )}

        <TouchableOpacity
          style={styles.metricsToggle}
          onPress={() => setShowMetrics(v => !v)}
        >
          <Text style={styles.metricsToggleText}>
            {showMetrics ? '▲ Hide details' : '▼ Show credit details'}
          </Text>
        </TouchableOpacity>

        {showMetrics && (
          <View style={styles.metricsBox}>
            <MetricRow label="Credit Limit"  value={fmtINR(credit.metrics.credit_limit)} />
            <MetricRow label="Outstanding"   value={fmtINR(credit.metrics.outstanding)} />
            <MetricRow label="Available"     value={fmtINR(credit.metrics.available)} />
            <MetricRow label="Overdue Days"  value={credit.metrics.overdue_days ? `${credit.metrics.overdue_days} days` : 'None'} />
            <MetricRow label="Order Total"   value={fmtINR(credit.metrics.order_total)} />
          </View>
        )}

        <Text style={styles.nextStepsText}>
          A branch manager or owner will review this order. You will be notified once a decision is made.
        </Text>

        {onViewOrder && (
          <PrimaryButton title="View Order (On Hold)" onPress={onViewOrder} />
        )}
        {onRecordCollection && credit.actions_required.collection_required && (
          <TouchableOpacity style={styles.secondaryButton} onPress={onRecordCollection}>
            <Text style={styles.secondaryButtonText}>Record Collection</Text>
          </TouchableOpacity>
        )}
      </View>
    );
  }

  // ── BLOCKED ───────────────────────────────────────────────────────────────
  const hasPrepayment  = (credit.actions_required.prepayment_required?.length ?? 0) > 0;
  const hasCollection  = credit.actions_required.collection_required;
  const limitTooLow    = (credit.metrics.available ?? 0) < (credit.metrics.order_total ?? 0);

  let primaryLabel   = 'Edit & Save as Draft';
  let primaryAction  = onSaveAsDraft ?? (() => undefined);

  if (hasPrepayment) {
    primaryLabel  = 'Use Advance Payment';
    primaryAction = onSaveAsDraft ?? (() => undefined); // stub
  } else if (hasCollection) {
    primaryLabel  = 'Record Collection';
    primaryAction = onRecordCollection ?? onSaveAsDraft ?? (() => undefined);
  } else if (limitTooLow && onRequestLimitChange) {
    primaryLabel  = 'Request Credit Limit Increase';
    primaryAction = onRequestLimitChange;
  }

  return (
    <View style={styles.container}>
      <Banner
        variant="danger"
        title="Order blocked by credit policy"
        message="This order cannot be submitted until the issues below are resolved."
      />

      {credit.reasons.length > 0 && (
        <View style={[styles.reasonsBox, styles.reasonsBoxDanger]}>
          <Text style={[styles.reasonsTitle, styles.reasonsTitleDanger]}>Blocking reasons</Text>
          {credit.reasons.map((r, i) => (
            <Text key={i} style={[styles.reasonItem, styles.reasonItemDanger]}>• {r}</Text>
          ))}
        </View>
      )}

      <TouchableOpacity
        style={styles.metricsToggle}
        onPress={() => setShowMetrics(v => !v)}
      >
        <Text style={styles.metricsToggleText}>
          {showMetrics ? '▲ Hide credit details' : '▼ View credit details'}
        </Text>
      </TouchableOpacity>

      {showMetrics && (
        <View style={styles.metricsBox}>
          <MetricRow label="Credit Limit"  value={fmtINR(credit.metrics.credit_limit)} />
          <MetricRow label="Outstanding"   value={fmtINR(credit.metrics.outstanding)} />
          <MetricRow label="Available"     value={fmtINR(credit.metrics.available)} />
          <MetricRow label="Overdue Days"  value={credit.metrics.overdue_days ? `${credit.metrics.overdue_days} days` : 'None'} />
          <MetricRow label="Order Total"   value={fmtINR(credit.metrics.order_total)} />
        </View>
      )}

      <PrimaryButton title={primaryLabel} onPress={primaryAction} />
      {onSaveAsDraft && primaryAction !== onSaveAsDraft && (
        <TouchableOpacity style={styles.secondaryButton} onPress={onSaveAsDraft}>
          <Text style={styles.secondaryButtonText}>Save as Draft</Text>
        </TouchableOpacity>
      )}
    </View>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    gap: spacing.sm,
  },
  reasonsBox: {
    backgroundColor: '#FEF3C7',
    borderRadius: borderRadius.md,
    padding: spacing.sm,
    marginBottom: spacing.xs,
  },
  reasonsBoxDanger: {
    backgroundColor: '#FEE2E2',
  },
  reasonsTitle: {
    fontWeight: '600',
    fontSize: 13,
    color: '#92400E',
    marginBottom: 4,
  },
  reasonsTitleDanger: {
    color: '#991B1B',
  },
  reasonItem: {
    fontSize: 13,
    color: '#92400E',
    lineHeight: 20,
  },
  reasonItemDanger: {
    color: '#991B1B',
  },
  metricsToggle: {
    alignSelf: 'flex-start',
    paddingVertical: 4,
  },
  metricsToggleText: {
    color: colors.primary,
    fontSize: 13,
    textDecorationLine: 'underline',
  },
  metricsBox: {
    backgroundColor: colors.backgroundSubtle ?? '#F9FAFB',
    borderRadius: borderRadius.md,
    padding: spacing.sm,
    borderWidth: 1,
    borderColor: colors.border ?? '#E5E7EB',
    gap: 6,
  },
  metricRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  metricLabel: {
    fontSize: 12,
    color: colors.textSecondary ?? '#6B7280',
  },
  metricValue: {
    fontSize: 13,
    fontWeight: '600',
    color: colors.textPrimary ?? '#111827',
  },
  nextStepsText: {
    fontSize: 12,
    color: colors.textSecondary ?? '#6B7280',
    fontStyle: 'italic',
  },
  secondaryButton: {
    alignItems: 'center',
    paddingVertical: spacing.sm,
    borderWidth: 1,
    borderColor: colors.border ?? '#E5E7EB',
    borderRadius: borderRadius.md,
    marginTop: 4,
  },
  secondaryButtonText: {
    fontSize: 14,
    color: colors.textPrimary ?? '#111827',
    fontWeight: '500',
  },
});
