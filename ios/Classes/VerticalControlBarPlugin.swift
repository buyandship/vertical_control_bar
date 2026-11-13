import Flutter
import UIKit

/// 把 iPhone Duo 右側 vertical bar 的可用範圍送給 Dart（`VerticalControlBarRegion`）
///
/// 範圍由 iOS 27.1 的 `UIView.LayoutRegion.bar(onEdge:extent:)` 提供：直欄扣掉動態島、狀態列與即時動態後可以放按鈕的部分。
/// 以 Objective-C runtime 呼叫，舊版 SDK 也能編譯；系統沒有這個 API 時 stream 直接結束。
public final class VerticalControlBarPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let eventChannelName = "vertical_control_bar/bar_region"

  private var sink: FlutterEventSink?
  private var probe: BarRegionProbeView?
  private var lastRegion: [String: Double]?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = VerticalControlBarPlugin()
    let events = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    // 啟用失敗時 Dart 只會回報 FlutterError、不會通知 listener，以結束 stream 表示沒有範圍
    guard BarRegionProbeView.isAvailable else {
      events(FlutterEndOfEventStream)
      return nil
    }
    sink = events
    if let lastRegion = lastRegion {
      events(lastRegion)
    }
    installProbeWhenPossible()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  /// 註冊時 window 可能還沒有 root view，等到有 Flutter 的 view 再掛上
  private func installProbeWhenPossible() {
    guard probe == nil else {
      return
    }
    guard let host = Self.hostView() else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
        self?.installProbeWhenPossible()
      }
      return
    }
    let probe = BarRegionProbeView()
    guard probe.pin(to: host) else {
      sink?(FlutterEndOfEventStream)
      return
    }
    probe.onChange = { [weak self] frame in
      self?.emit(frame)
    }
    self.probe = probe
  }

  private func emit(_ frame: CGRect) {
    let region: [String: Double] = [
      "left": Double(frame.minX),
      "top": Double(frame.minY),
      "width": Double(frame.width),
      "height": Double(frame.height),
    ]
    guard region != lastRegion else {
      return
    }
    lastRegion = region
    sink?(region)
  }

  /// 顯示 Flutter 畫面的 view，範圍以它的座標回報（UIKit 的 point 與 Flutter 的 logical pixel 相同）
  private static func hostView() -> UIView? {
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene,
        windowScene.activationState == .foregroundActive || windowScene.activationState == .foregroundInactive
      else {
        continue
      }
      let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first
      if let view = window?.rootViewController?.view {
        return view
      }
    }
    return nil
  }
}

/// 不顯示內容、不接收觸控，以 Auto Layout 貼齊系統的 bar layout guide；layout guide 改變時（例如出現即時動態）自己的位置跟著改變，藉此得知新的範圍
final class BarRegionProbeView: UIView {
  /// bar 的厚度；只用到範圍沿著直欄的位置，與實際的寬度無關
  private static let barExtent: CGFloat = 44

  private static let regionClassName = "UIViewLayoutRegion"
  private static let barRegionSelector = NSSelectorFromString("layoutRegionForBarOnEdge:extent:")
  private static let layoutGuideSelector = NSSelectorFromString("layoutGuideForLayoutRegion:")

  private typealias BarRegionFunction = @convention(c) (AnyClass, Selector, UInt, CGFloat) -> Unmanaged<AnyObject>?

  var onChange: ((CGRect) -> Void)?

  private var isReportScheduled = false

  static var isAvailable: Bool {
    guard let regionClass = NSClassFromString(regionClassName) else {
      return false
    }

    return class_getClassMethod(regionClass, barRegionSelector) != nil && UIView.instancesRespond(to: layoutGuideSelector)
  }

  // 只有位置改變時不會呼叫 layoutSubviews，也要從 center 得知
  override var center: CGPoint {
    didSet {
      scheduleReport()
    }
  }

  override var bounds: CGRect {
    didSet {
      scheduleReport()
    }
  }

  /// 加到 [host] 底下並貼齊右側 bar 的 layout guide；系統沒有提供時回傳 false
  func pin(to host: UIView) -> Bool {
    guard let guide = Self.barLayoutGuide(in: host) else {
      return false
    }
    isUserInteractionEnabled = false
    isAccessibilityElement = false
    translatesAutoresizingMaskIntoConstraints = false
    host.insertSubview(self, at: 0)
    NSLayoutConstraint.activate([
      leadingAnchor.constraint(equalTo: guide.leadingAnchor),
      trailingAnchor.constraint(equalTo: guide.trailingAnchor),
      topAnchor.constraint(equalTo: guide.topAnchor),
      bottomAnchor.constraint(equalTo: guide.bottomAnchor),
    ])
    return true
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    scheduleReport()
  }

  /// Auto Layout 分別設定 center 與 bounds，中間的 frame 不正確（例如 y 為負值）；等這一輪排版結束再回報
  private func scheduleReport() {
    guard !isReportScheduled else {
      return
    }
    isReportScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      self.isReportScheduled = false
      guard self.superview != nil, self.frame.height > 0 else {
        return
      }
      self.onChange?(self.frame)
    }
  }

  private static func barLayoutGuide(in host: UIView) -> UILayoutGuide? {
    guard let regionClass = NSClassFromString(regionClassName),
      let method = class_getClassMethod(regionClass, barRegionSelector),
      host.responds(to: layoutGuideSelector)
    else {
      return nil
    }
    let barRegion = unsafeBitCast(method_getImplementation(method), to: BarRegionFunction.self)
    guard let region = barRegion(regionClass, barRegionSelector, UIRectEdge.right.rawValue, barExtent)?.takeUnretainedValue() else {
      return nil
    }

    return host.perform(layoutGuideSelector, with: region)?.takeUnretainedValue() as? UILayoutGuide
  }
}
