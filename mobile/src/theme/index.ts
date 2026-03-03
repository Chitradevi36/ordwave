export const colors = {
  primary: '#1B4332',
  secondary: '#2D6A4F',
  accent: '#52B788',
  background: '#FFFFFF',
  backgroundSubtle: '#F8FAF8',
  textPrimary: '#1E293B',
  textSecondary: '#64748B',
  danger: '#DC2626',
  warning: '#D97706',
  border: '#E2E8F0',
  white: '#FFFFFF',
  black: '#000000',
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
};

export const typography = {
  h1: { fontSize: 28, fontWeight: '700' as const, color: colors.textPrimary },
  h2: { fontSize: 22, fontWeight: '700' as const, color: colors.textPrimary },
  h3: { fontSize: 18, fontWeight: '600' as const, color: colors.textPrimary },
  body: { fontSize: 14, fontWeight: '400' as const, color: colors.textPrimary },
  bodySmall: { fontSize: 12, fontWeight: '400' as const, color: colors.textSecondary },
  label: { fontSize: 13, fontWeight: '500' as const, color: colors.textPrimary },
};

export const borderRadius = {
  sm: 4,
  md: 8,
  lg: 12,
  xl: 16,
  full: 9999,
};

export const shadows = {
  sm: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  md: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
};
