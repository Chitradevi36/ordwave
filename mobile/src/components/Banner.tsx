import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { colors, spacing, borderRadius } from '../theme';

export type BannerVariant = 'success' | 'warning' | 'danger' | 'info';

export interface BannerProps {
  message: string;
  variant?: BannerVariant;
  title?: string;
}

const variantStyles: Record<BannerVariant, { bg: string; border: string; text: string }> = {
  success: { bg: '#D1FAE5', border: colors.accent, text: colors.secondary },
  warning: { bg: '#FEF3C7', border: colors.warning, text: '#92400E' },
  danger: { bg: '#FEE2E2', border: colors.danger, text: '#991B1B' },
  info: { bg: '#DBEAFE', border: '#3B82F6', text: '#1E40AF' },
};

export function Banner({ message, variant = 'info', title }: BannerProps) {
  const vs = variantStyles[variant];
  return (
    <View style={[styles.container, { backgroundColor: vs.bg, borderLeftColor: vs.border }]}>
      {title && <Text style={[styles.title, { color: vs.text }]}>{title}</Text>}
      <Text style={[styles.message, { color: vs.text }]}>{message}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: spacing.md,
    borderRadius: borderRadius.md,
    borderLeftWidth: 4,
    marginBottom: spacing.md,
  },
  title: {
    fontWeight: '600',
    fontSize: 14,
    marginBottom: 4,
  },
  message: {
    fontSize: 13,
  },
});
