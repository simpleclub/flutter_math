/// Utilities for calculating vertical alignment offsets to visually center
/// operators relative to numbers (at the math axis).
///
/// KaTeX font metrics assign different heights and depths to different
/// character types. Operators are designed to sit at the "math axis" which
/// is centered vertically relative to numbers.
///
/// Characters that get centered (at math axis):
/// - Binary operators: +, -, ×, ÷, ·, ± (AtomType.bin)
/// - Relations: =, ≠, <, >, ≤, ≥ (AtomType.rel)
///
/// Characters that stay at baseline (NOT centered):
/// - Numbers: 0-9 (tall, height ~0.64)
/// - Variables: x, y, a, b, etc. (AtomType.ord) - share baseline with numbers
/// - All other ordinary characters

/// Constants and calculations for visual alignment of math characters.
///
/// Reference metrics (from KaTeX Main-Regular font):
/// - Numbers (0-9): height=0.64444, depth=0
/// - Plus (+): height=0.58333, depth=0.08333
/// - Minus (−): height=0.58333, depth=0.08333
/// - Equals (=): height=0.36687, depth=-0.13313
///
/// Reference metrics (from KaTeX Math-Italic font):
/// - Variable x: height=0.43056, depth=0
/// - Variable y: height=0.43056, depth=0.19444
class AlignmentConstants {
  AlignmentConstants._();

  /// Reference height for numbers (0-9) in Main-Regular font (em units)
  static const double numberHeight = 0.64444;

  /// Reference depth for numbers (0-9) in Main-Regular font (em units)
  static const double numberDepth = 0.0;

  /// Visual center of numbers from baseline (em units)
  /// Calculated as: (height - depth) / 2 = (0.64444 - 0) / 2 = 0.32222
  static const double numberVisualCenter = (numberHeight - numberDepth) / 2;

  /// Threshold below which we consider a character "short" and apply centering
  /// Characters with height >= this value are considered tall enough (like numbers)
  static const double heightThreshold = numberHeight - 0.05;

  /// Calculate vertical offset to align a character's visual center with
  /// the number's visual center.
  ///
  /// [charHeight] - The character's height from font metrics (em units)
  /// [charDepth] - The character's depth from font metrics (em units)
  ///
  /// Returns the offset in em units. Positive values shift the character UP.
  static double calculateAlignmentOffset({
    required double charHeight,
    required double charDepth,
  }) {
    // Character's visual center from baseline
    // For a character that extends from -depth to +height,
    // the visual center is at (height - depth) / 2 from the baseline
    final charVisualCenter = (charHeight - charDepth) / 2;

    // Offset needed to align with number's visual center
    // Positive offset = shift up (character center is below number center)
    return numberVisualCenter - charVisualCenter;
  }

  /// Check if a character should have centering applied based on its height.
  /// Numbers and tall characters should NOT be centered.
  static bool shouldApplyCentering(double charHeight) {
    return charHeight < heightThreshold;
  }
}
