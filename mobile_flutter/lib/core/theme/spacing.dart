/// M8.1 — Design spacing constants for consistent layout across all screens.
///
/// Usage:
/// ```dart
/// import '../../../core/theme/spacing.dart';
///
/// Padding(
///   padding: OlSpacing.screenPadding,
///   child: Column(
///     children: [
///       SomeCard(),
///       SizedBox(height: OlSpacing.cardGap),
///       AnotherCard(),
///     ],
///   ),
/// );
/// ```
library;

import 'package:flutter/material.dart';

abstract final class OlSpacing {
  // ── Screen edges ─────────────────────────────────────────────────────────
  /// Standard horizontal/vertical padding for page content (16 dp).
  static const double edge = 16.0;

  /// Tighter screen edge for compact views (12 dp).
  static const double edgeSmall = 12.0;

  /// Wide screen edge for hero sections (20 dp).
  static const double edgeLarge = 20.0;

  /// Standard EdgeInsets for full screen padding.
  static const EdgeInsets screenPadding = EdgeInsets.all(edge);

  /// Horizontal-only screen padding.
  static const EdgeInsets hPadding = EdgeInsets.symmetric(horizontal: edge);

  // ── Gaps between cards / sections ─────────────────────────────────────────
  /// Gap between sibling card widgets (12 dp).
  static const double cardGap = 12.0;

  /// Gap between items in a list (8 dp).
  static const double listItemGap = 8.0;

  /// Section separator (24 dp).
  static const double sectionGap = 24.0;

  // ── Internal card padding ─────────────────────────────────────────────────
  /// Standard padding inside a card (16 dp all sides).
  static const EdgeInsets cardPadding = EdgeInsets.all(edge);

  /// Card padding with slightly more vertical space.
  static const EdgeInsets cardPaddingV = EdgeInsets.symmetric(
    horizontal: edge,
    vertical: 20.0,
  );

  // ── Status chip ───────────────────────────────────────────────────────────
  /// Horizontal padding for status badge chips.
  static const EdgeInsets chipPadding =
      EdgeInsets.symmetric(horizontal: 10, vertical: 4);

  // ── AppBar ────────────────────────────────────────────────────────────────
  /// Standard AppBar elevation (0 for flat; use shadow via decoration instead).
  static const double appBarElevation = 0.0;

  // ── Form ─────────────────────────────────────────────────────────────────
  /// Vertical gap between form fields (16 dp).
  static const double formFieldGap = 16.0;

  /// Border radius for input fields and cards.
  static const double radius = 10.0;
  static const double radiusLg = 14.0;
  static BorderRadius get borderRadius => BorderRadius.circular(radius);
  static BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
}
