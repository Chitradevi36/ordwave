import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { colors, spacing, borderRadius } from '../theme';

export type StatusVariant = 'success' | 'warning' | 'danger' | 'info' | 'neutral';

export interface StatusPillProps {
  label: string;
  variant?: StatusVariant;
}

const variantColors: Record<StatusVariant, { bg: string; text: string }> = {
  success: { bg: '#D1FAE5', text: colors.secondary },
  warning: { bg: '#FEF3C7', text: '#92400E' },
  danger: { bg: '#FEE2E2', text: colors.danger },
  info: { bg: '#DBEAFE', text: '#1D4ED8' },
  neutral: { bg: colors.backgroundSubtle, text: colors.textSecondary },
};

export function StatusPill({ label, variant = 'neutral' }: StatusPillProps) {
  const { bg, text } = variantColors[variant];
  return (
    <View style={[styles.pill, { backgroundColor: bg }]}>
      <Text style={[styles.label, { color: text }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  pill: {
    paddingHorizontal: spacing.sm + 2,
    paddingVertical: 3,
    borderRadius: borderRadius.full,
    alignSelf: 'flex-start',
  },
  label: {
    fontSize: 11,
    fontWeight: '600',
  },
});
