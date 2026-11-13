import 'package:flutter/material.dart';

/// vertical control bar 的顏色
///
/// 以 [ThemeData.extensions] 提供；沒有提供時使用 [VerticalControlBarThemeData.fallback]。
@immutable
class VerticalControlBarThemeData extends ThemeExtension<VerticalControlBarThemeData> {
  /// 沒有在 theme 提供時使用的顏色
  static const fallback = VerticalControlBarThemeData(
    backgroundColor: Colors.white,
    outlineColor: Color(0xFFE0E0E0),
    indicatorColor: Color(0xFFEEEEEE),
  );

  /// bar 與按鈕外框的底色
  final Color backgroundColor;

  /// bar 的分隔線與按鈕外框的線條
  final Color outlineColor;

  /// `VerticalControlBarGroup` 中選取中按鈕的背景，比照 Material 的 navigation indicator
  final Color indicatorColor;

  const VerticalControlBarThemeData({
    required this.backgroundColor,
    required this.outlineColor,
    required this.indicatorColor,
  });

  static VerticalControlBarThemeData of(BuildContext context) {
    return Theme.of(context).extension<VerticalControlBarThemeData>() ?? fallback;
  }

  BorderSide get outlineSide => BorderSide(color: outlineColor);

  @override
  VerticalControlBarThemeData copyWith({
    Color? backgroundColor,
    Color? outlineColor,
    Color? indicatorColor,
  }) {
    return VerticalControlBarThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      outlineColor: outlineColor ?? this.outlineColor,
      indicatorColor: indicatorColor ?? this.indicatorColor,
    );
  }

  @override
  VerticalControlBarThemeData lerp(
    covariant VerticalControlBarThemeData? other,
    double t,
  ) {
    if (other == null) {
      return this;
    }

    return VerticalControlBarThemeData(
      backgroundColor: Color.lerp(
        backgroundColor,
        other.backgroundColor,
        t,
      )!,
      outlineColor: Color.lerp(
        outlineColor,
        other.outlineColor,
        t,
      )!,
      indicatorColor: Color.lerp(
        indicatorColor,
        other.indicatorColor,
        t,
      )!,
    );
  }
}
