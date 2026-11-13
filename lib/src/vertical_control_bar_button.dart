import 'package:flutter/widgets.dart';

/// 按鈕在 vertical control bar 中的位置
enum VerticalControlBarAlignment {
  /// 上方：由狀態列下方往下排
  top,

  /// 下方：由 bar 底部往上排；bar 下半部是 tab 時改接在上方的按鈕之後
  bottom,
}

/// 放進 `VerticalControlBarPortal` 的按鈕
///
/// 由 app 依自己的設計實作（例如 App Bar 的圖示按鈕、文字按鈕）；bar 上以 [buildButton] 顯示，各自有一個外框，見 `VerticalControlBarItem`。
abstract interface class VerticalControlBarButton {
  /// 在 vertical control bar 中排在上方或下方；未指定時見 `VerticalControlBarPortal`
  VerticalControlBarAlignment? get alignment;

  /// 是否維持在 App Bar：放不進 bar 寬度的按鈕（例如文字按鈕），vertical control bar 啟用時也留在 App Bar 原本的位置
  bool get isAppBarOnly;

  /// vertical control bar 上顯示的按鈕；App Bar 沒有自己的樣式時也可以直接使用
  Widget buildButton(BuildContext context);
}
