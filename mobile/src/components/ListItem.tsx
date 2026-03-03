import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  TouchableOpacityProps,
} from 'react-native';
import { colors, spacing, typography } from '../theme';

export interface ListItemProps extends TouchableOpacityProps {
  title: string;
  subtitle?: string;
  leftElement?: React.ReactNode;
  rightElement?: React.ReactNode;
  showDivider?: boolean;
}

export function ListItem({
  title,
  subtitle,
  leftElement,
  rightElement,
  showDivider = true,
  style,
  ...props
}: ListItemProps) {
  return (
    <TouchableOpacity style={[styles.container, showDivider && styles.divider, style]} activeOpacity={0.7} {...props}>
      {leftElement && <View style={styles.left}>{leftElement}</View>}
      <View style={styles.content}>
        <Text style={styles.title} numberOfLines={1}>{title}</Text>
        {subtitle && <Text style={styles.subtitle} numberOfLines={1}>{subtitle}</Text>}
      </View>
      {rightElement && <View style={styles.right}>{rightElement}</View>}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.lg,
    backgroundColor: colors.background,
  },
  divider: {
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  left: {
    marginRight: spacing.md,
  },
  content: {
    flex: 1,
  },
  title: {
    ...typography.body,
    fontWeight: '500',
  },
  subtitle: {
    ...typography.bodySmall,
    marginTop: 2,
  },
  right: {
    marginLeft: spacing.md,
  },
});
