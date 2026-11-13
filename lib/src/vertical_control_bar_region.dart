import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 系統回報的 vertical control bar 可用範圍
///
/// 讀取 iOS 27.1 的 `UIView.LayoutRegion.bar(onEdge:extent:)`：右側直欄扣掉動態島、狀態列與即時動態後可以放按鈕的範圍，
/// 狀態區變高或變矮時（例如出現即時動態）再送出新的範圍。座標以 Flutter view 為準（logical pixel）。
/// 系統沒有這個 API 時（iOS 27.1 以前）stream 直接結束。
abstract final class VerticalControlBarRegion {
  static const _channel = EventChannel('vertical_control_bar/bar_region');

  /// 右側直欄的可用範圍；只有 iOS 有原生的實作
  static final Stream<Rect> stream = _channel.receiveBroadcastStream().map(rectFrom);

  /// 把原生送來的範圍（`left`、`top`、`width`、`height`）轉成 [Rect]
  @visibleForTesting
  static Rect rectFrom(Object? event) {
    final region = event! as Map<Object?, Object?>;

    return Rect.fromLTWH(
      (region['left']! as num).toDouble(),
      (region['top']! as num).toDouble(),
      (region['width']! as num).toDouble(),
      (region['height']! as num).toDouble(),
    );
  }
}
