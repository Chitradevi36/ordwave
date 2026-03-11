import 'package:flutter/material.dart';

/// OrdWave design tokens — mirrors the web Tailwind config.
/// Primary brand: deep forest green (#1B4332)
class OlColors {
  OlColors._();

  // ── Primary (deep green) ─────────────────────────────────────────────────
  static const Color primary   = Color(0xFF1B4332);
  static const Color primary50 = Color(0xFFECF4F0);
  static const Color primary100 = Color(0xFFD1E7DC);
  static const Color primary200 = Color(0xFFA3CFBA);
  static const Color primary300 = Color(0xFF75B797);
  static const Color primary400 = Color(0xFF52A07A);
  static const Color primary500 = Color(0xFF2D6A4F);
  static const Color primary600 = Color(0xFF1B5E3B);
  static const Color primary700 = Color(0xFF1B4332); // same as primary
  static const Color primary800 = Color(0xFF143426);
  static const Color primary900 = Color(0xFF0D2419);

  // ── Secondary (medium green accent) ─────────────────────────────────────
  static const Color secondary   = Color(0xFF2D6A4F);
  static const Color secondary50 = Color(0xFFEBF5EF);

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color background       = Color(0xFFFFFFFF);
  static const Color backgroundSubtle = Color(0xFFF9FAFB);
  static const Color surface          = Color(0xFFFFFFFF);
  static const Color surfaceCard      = Color(0xFFF9FAFB);
  static const Color surfaceSubtle    = Color(0xFFF9FAFB);  // alias

  // ── Borders ───────────────────────────────────────────────────────────────
  static const Color border      = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary  = Color(0xFF9CA3AF);
  static const Color textDisabled  = Color(0xFFD1D5DB);  // alias

  // ── Aliases ───────────────────────────────────────────────────────────────
  static const Color primaryLight  = primary50;   // #ECF4F0
  static const Color errorLight    = error50;     // #FEF2F2

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success    = Color(0xFF16A34A);
  static const Color success50  = Color(0xFFF0FDF4);
  static const Color warning    = Color(0xFFD97706);
  static const Color warning50  = Color(0xFFFFFBEB);
  static const Color error      = Color(0xFFDC2626);
  static const Color error50    = Color(0xFFFEF2F2);
  static const Color info       = Color(0xFF2563EB);
  static const Color info50     = Color(0xFFEFF6FF);

  // ── Credit Status ─────────────────────────────────────────────────────────
  static const Color creditOk       = success;
  static const Color creditOk50     = success50;
  static const Color creditHold     = warning;
  static const Color creditHold50   = warning50;
  static const Color creditBlocked  = error;
  static const Color creditBlocked50 = error50;

  // ── Order Status ──────────────────────────────────────────────────────────
  static Color orderStatusColor(String status) {
    switch (status) {
      case 'draft':         return textTertiary;
      case 'submitted':     return info;
      case 'on_hold':       return warning;
      case 'approved':      return success;
      case 'dispatched':    return primary;
      case 'delivered':     return success;
      case 'partially_delivered': return warning;
      case 'cancelled':     return error;
      default:              return textSecondary;
    }
  }

  static Color orderStatusBg(String status) {
    switch (status) {
      case 'draft':         return backgroundSubtle;
      case 'submitted':     return info50;
      case 'on_hold':       return warning50;
      case 'approved':      return success50;
      case 'dispatched':    return primary50;
      case 'delivered':     return success50;
      case 'partially_delivered': return warning50;
      case 'cancelled':     return error50;
      default:              return backgroundSubtle;
    }
  }
}
