import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:foldable/foldable.dart';

import 'vertical_control_bar_button.dart';
import 'vertical_control_bar_region.dart';
import 'vertical_control_bar_theme.dart';

/// bar 從右側直欄再往內延伸的寬度，讓按鈕與直欄內的狀態列對齊在同一條中線
const double _bezelInset = 12;

/// 系統沒有回報 bar 的可用範圍時（iOS 27.1 以前），按鈕外框開始排列的高度
///
/// 與只顯示時鐘時系統回報的範圍相同（iPhone Duo 外螢幕 174pt）；有即時動態時狀態區會變高，見 [VerticalControlBarRegion]。
const double _fallbackItemsTop = 174;

const double _itemHeight = 56;

/// 單獨按鈕外框的大小，與 Material 的最小點擊範圍相同
const double _itemButtonSize = kMinInteractiveDimension;

/// iPhone Duo 的 vertical control bar
///
/// 依 Apple 的 iPhone Duo 設計：外螢幕、以及內螢幕橫向時，系統把狀態列移到畫面右側的直欄，
/// 原本在上方／下方的 bar 也轉成直向放進這一欄；內螢幕直向時維持一般的橫向 bar。
/// 上半部放 App Bar 的按鈕（返回／關閉在最上方），下半部放 tab；
/// 沒有 tab 的頁面，按鈕也可以放到下半部，見 [VerticalControlBarPortal]。
///
/// app 需以 iOS 27.1 以上的 SDK 編譯，否則在 iPhone Duo 上會以一般 iPhone 的比例顯示，不會進入這個姿態。
class VerticalControlBar {
  /// 目前的裝置與姿態是否使用 vertical control bar
  ///
  /// 系統把狀態列移到右側直欄時，上方沒有 safe area、只有右側有；內螢幕直向與其他 iPhone 上方都有 safe area。
  /// [VerticalControlBarSupport] 關閉時一律不使用。
  /// 需在 bar 尚未扣掉寬度的 context 判斷。
  static bool isDeviceLayoutOf(BuildContext context) {
    if (!VerticalControlBarSupport.isEnabledOf(context) || !DuoMediaQuery.isFoldableOf(context)) {
      return false;
    }
    final viewPadding = MediaQuery.viewPaddingOf(context);

    return viewPadding.top == 0 && viewPadding.left == 0 && viewPadding.right > 0;
  }

  /// bar 的寬度：右側 safe area（狀態列所在的直欄）再往內延伸 [_bezelInset]
  ///
  /// 需在 bar 尚未扣掉寬度的 context 取得。
  static double widthOf(BuildContext context) {
    return MediaQuery.viewPaddingOf(context).right + _bezelInset;
  }

  /// [context] 所在的頁面是否把 bar 的按鈕移到 vertical control bar
  ///
  /// 只有 [VerticalControlBarScope] 底下的頁面（[PageRoute]）會啟用；dialog、bottom sheet 等維持原本的 bar。
  static bool isEnabledOf(BuildContext context) {
    final scope = VerticalControlBarScope.maybeOf(context);
    if (scope == null || !scope.isEnabled) {
      return false;
    }

    return ModalRoute.of(context) is PageRoute;
  }

  /// 按鈕外框開始排列的高度，以 bar 的上緣（與螢幕上緣對齊）為準
  ///
  /// 依系統回報的可用範圍，讓按鈕排在動態島、狀態列與即時動態下方，範圍改變時一起移動；系統沒有回報時使用固定的高度。
  static double itemsTopOf(BuildContext context) {
    return VerticalControlBarSupport.barRegionOf(context)?.top ?? _fallbackItemsTop;
  }
}

/// 是否支援 iPhone Duo 的 vertical control bar（例如由 Remote Config 控制），並提供系統回報的 bar 可用範圍
///
/// 上層沒有這個 widget 時視為不支援。切換時與姿態改變一樣，頁面的 State 不會重建。
/// 需放在 `FoldableProvider` 底下：只有折疊裝置才讀取系統回報的範圍。
class VerticalControlBarSupport extends StatefulWidget {
  final bool isEnabled;

  /// 系統回報的 bar 可用範圍；未指定時在 iOS 讀取 [VerticalControlBarRegion.stream]，測試與 preview 可傳入假的範圍
  final Stream<Rect>? barRegionStream;

  final Widget child;

  const VerticalControlBarSupport({
    super.key,
    required this.isEnabled,
    this.barRegionStream,
    required this.child,
  });

  static bool isEnabledOf(BuildContext context) {
    return InheritedModel.inheritFrom<_VerticalControlBarSupportScope>(
          context,
          aspect: _SupportAspect.isEnabled,
        )?.isEnabled ??
        false;
  }

  /// 系統回報的 bar 可用範圍（Flutter view 的座標），沒有回報時為 null
  static Rect? barRegionOf(BuildContext context) {
    return InheritedModel.inheritFrom<_VerticalControlBarSupportScope>(
      context,
      aspect: _SupportAspect.barRegion,
    )?.barRegion;
  }

  @override
  State<VerticalControlBarSupport> createState() => _VerticalControlBarSupportState();
}

class _VerticalControlBarSupportState extends State<VerticalControlBarSupport> {
  StreamSubscription<Rect>? subscription;
  Stream<Rect>? listeningStream;
  Rect? barRegion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    syncSubscription();
  }

  @override
  void didUpdateWidget(VerticalControlBarSupport oldWidget) {
    super.didUpdateWidget(oldWidget);

    syncSubscription();
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  /// 只在啟用時讀取；未指定 [VerticalControlBarSupport.barRegionStream] 時只有 iOS 的折疊裝置有原生的實作
  Stream<Rect>? regionStream() {
    final barRegionStream = widget.barRegionStream;
    if (!widget.isEnabled) {
      return null;
    }
    if (barRegionStream != null) {
      return barRegionStream;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS || !DuoMediaQuery.isFoldableOf(context)) {
      return null;
    }

    return VerticalControlBarRegion.stream;
  }

  void syncSubscription() {
    final stream = regionStream();
    if (stream == listeningStream) {
      return;
    }
    subscription?.cancel();
    listeningStream = stream;
    barRegion = null;
    // 讀取失敗或 stream 結束時保留目前的範圍，沒有範圍時使用固定的高度
    subscription = stream?.listen(
      (region) {
        if (region != barRegion) {
          setState(() {
            barRegion = region;
          });
        }
      },
      onError: (Object error) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return _VerticalControlBarSupportScope(
      isEnabled: widget.isEnabled,
      barRegion: barRegion,
      child: widget.child,
    );
  }
}

enum _SupportAspect { isEnabled, barRegion }

class _VerticalControlBarSupportScope extends InheritedModel<_SupportAspect> {
  final bool isEnabled;
  final Rect? barRegion;

  const _VerticalControlBarSupportScope({
    required this.isEnabled,
    required this.barRegion,
    required super.child,
  });

  @override
  bool updateShouldNotify(_VerticalControlBarSupportScope oldWidget) {
    return isEnabled != oldWidget.isEnabled || barRegion != oldWidget.barRegion;
  }

  // 範圍改變時只更新按鈕，不重建依 isEnabled 排版的頁面
  @override
  bool updateShouldNotifyDependent(
    _VerticalControlBarSupportScope oldWidget,
    Set<_SupportAspect> dependencies,
  ) {
    return (dependencies.contains(_SupportAspect.isEnabled) && isEnabled != oldWidget.isEnabled) || (dependencies.contains(_SupportAspect.barRegion) && barRegion != oldWidget.barRegion);
  }
}

/// 提供 vertical control bar 的區域給底下的頁面
///
/// - tab 的容器為每個 tab 提供：bar 常駐，下半部是 tab
/// - [VerticalControlBarInset] 為其他頁面提供：頁面有按鈕時才在右側留出 bar
class VerticalControlBarScope extends InheritedWidget {
  /// 目前的裝置與姿態是否使用 vertical control bar，見 [VerticalControlBar.isDeviceLayoutOf]
  final bool isEnabled;

  /// 底下的頁面是否為目前顯示中的頁面（例如非目前的 tab 時為 false）
  final bool isActive;

  /// bar 區域的位置，按鈕會對齊到這裡
  final LayerLink link;

  /// bar 底部（扣掉底部 safe area）的位置，見 [VerticalControlBarContainer.bottomLink]
  ///
  /// 只有 bar 下半部沒有 tab 時才提供；排在下方的按鈕（見 [VerticalControlBarButton.alignment]）會由這裡往上排。
  final LayerLink? bottomLink;

  /// bar 的寬度，見 [VerticalControlBar.widthOf]
  final double width;

  /// 底下的頁面有按鈕要放進 bar 時呼叫，用來決定是否留出 bar 的空間
  final ValueChanged<Object>? onItemsAttached;
  final ValueChanged<Object>? onItemsDetached;

  const VerticalControlBarScope({
    super.key,
    required this.isEnabled,
    required this.isActive,
    required this.link,
    this.bottomLink,
    required this.width,
    this.onItemsAttached,
    this.onItemsDetached,
    required super.child,
  });

  static VerticalControlBarScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<VerticalControlBarScope>();
  }

  @override
  bool updateShouldNotify(VerticalControlBarScope oldWidget) {
    return isEnabled != oldWidget.isEnabled || isActive != oldWidget.isActive || link != oldWidget.link || bottomLink != oldWidget.bottomLink || width != oldWidget.width;
  }
}

Widget _buildSurface(
  BuildContext context, {
  required double width,
  required EdgeInsets padding,
  required Widget? child,
}) {
  final theme = VerticalControlBarThemeData.of(context);

  return Material(
    color: theme.backgroundColor,
    shape: Border(
      left: theme.outlineSide,
    ),
    child: Container(
      width: width,
      padding: padding,
      child: child,
    ),
  );
}

/// 把 [bar] 放在 [child] 右側，並讓 [child] 的 MediaQuery 扣掉 bar 佔用的寬度與右側 safe area
class VerticalControlBarLayout extends StatelessWidget {
  final Widget? bar;
  final Widget child;

  const VerticalControlBarLayout({
    super.key,
    required this.bar,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bar = this.bar;
    final mediaQuery = MediaQuery.of(context);
    final barWidth = VerticalControlBar.widthOf(context);

    // 不論 bar 是否顯示都維持相同的 widget 結構，避免折疊／展開時 child 的 State 被重建
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: MediaQuery(
            data: bar != null
                ? mediaQuery.copyWith(
                    size: Size(
                      mediaQuery.size.width - barWidth,
                      mediaQuery.size.height,
                    ),
                    padding: mediaQuery.padding.copyWith(right: 0),
                    viewPadding: mediaQuery.viewPadding.copyWith(right: 0),
                  )
                : mediaQuery,
            child: child,
          ),
        ),
        if (bar != null) bar,
      ],
    );
  }
}

/// Vertical control bar 的底板，[child] 會貼齊底部（例如 tab）
class VerticalControlBarContainer extends StatelessWidget {
  final LayerLink link;

  /// 標記 bar 底部（扣掉底部 safe area，不會壓到 home indicator）的位置，放到底部的按鈕會由這裡往上排
  ///
  /// 下半部已有 [child]（例如 tab）時不需要提供。
  final LayerLink? bottomLink;

  final Widget? child;

  const VerticalControlBarContainer({
    super.key,
    required this.link,
    this.bottomLink,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bottomLink = this.bottomLink;

    return CompositedTransformTarget(
      link: link,
      child: _buildSurface(
        context,
        width: VerticalControlBar.widthOf(context),
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: bottomLink != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: child ?? const SizedBox.shrink()),
                  CompositedTransformTarget(
                    link: bottomLink,
                    child: const SizedBox.shrink(),
                  ),
                ],
              )
            : child,
      ),
    );
  }
}

/// vertical control bar 中單獨的一個按鈕（App Bar 的 leading、actions），各自有圓形的外框
///
/// 比照 Material 的 outlined icon button：底下的 [IconButton]、[TextButton] 會撐滿外框，點擊時的 ripple 與外框同大小。
/// 較寬的按鈕外框為膠囊形，超出 bar 寬度時等比例縮小。
class VerticalControlBarItem extends StatelessWidget {
  final Widget child;

  const VerticalControlBarItem({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = VerticalControlBarThemeData.of(context);
    final iconButtonStyle = IconButton.styleFrom(minimumSize: const Size.square(_itemButtonSize));
    final textButtonStyle = TextButton.styleFrom(minimumSize: const Size.square(_itemButtonSize));

    return SizedBox(
      height: _itemHeight,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _itemHeight),
            // Material 2 的 IconButton 不會套用 IconButtonTheme，以外框裁切 ripple
            child: Material(
              color: theme.backgroundColor,
              shape: StadiumBorder(side: theme.outlineSide),
              clipBehavior: Clip.antiAlias,
              child: IconButtonTheme(
                data: IconButtonThemeData(style: iconButtonStyle.merge(IconButtonTheme.of(context).style)),
                child: TextButtonTheme(
                  data: TextButtonThemeData(style: textButtonStyle.merge(TextButtonTheme.of(context).style)),
                  // 不是 IconButton／TextButton 的按鈕（例如自訂的 InkWell）不會套用上面的 theme，至少維持圓形的外框
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: _itemButtonSize,
                      minHeight: _itemButtonSize,
                    ),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 把 vertical control bar 中一組相關的按鈕（例如 tab）以同一個膠囊形的外框包起來
///
/// 各按鈕之間不留間距；選取中的按鈕可用 [VerticalControlBarThemeData.indicatorColor] 作為背景，比照 Material 的 navigation indicator。
class VerticalControlBarGroup extends StatelessWidget {
  final List<Widget> children;

  const VerticalControlBarGroup({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = VerticalControlBarThemeData.of(context);

    return Material(
      color: theme.backgroundColor,
      shape: StadiumBorder(side: theme.outlineSide),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// 一般頁面（非 tab）的 vertical control bar
///
/// 在產生 route 時包在每個頁面外層；頁面內的 bar 有按鈕要放進 vertical control bar 時，才在右側留出 bar。
/// tab 內的頁面由 tab 的容器提供 bar（自行建立 [VerticalControlBarScope]），這裡不做處理。
class VerticalControlBarInset extends StatefulWidget {
  final Widget child;

  const VerticalControlBarInset({
    super.key,
    required this.child,
  });

  @override
  State<VerticalControlBarInset> createState() => _VerticalControlBarInsetState();
}

class _VerticalControlBarInsetState extends State<VerticalControlBarInset> {
  final link = LayerLink();
  final bottomLink = LayerLink();
  final Set<Object> itemOwners = {};
  bool hasItems = false;

  void attachItems(Object owner) {
    if (itemOwners.add(owner)) {
      scheduleUpdate();
    }
  }

  void detachItems(Object owner) {
    if (itemOwners.remove(owner)) {
      scheduleUpdate();
    }
  }

  // attach / detach 發生在子孫的 build 階段，等 frame 結束後再更新
  void scheduleUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && hasItems != itemOwners.isNotEmpty) {
        setState(() {
          hasItems = itemOwners.isNotEmpty;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (VerticalControlBarScope.maybeOf(context) != null) {
      return widget.child;
    }

    final isEnabled = VerticalControlBar.isDeviceLayoutOf(context);

    return VerticalControlBarLayout(
      bar: isEnabled && hasItems
          ? VerticalControlBarContainer(
              link: link,
              bottomLink: bottomLink,
            )
          : null,
      child: VerticalControlBarScope(
        isEnabled: isEnabled,
        isActive: true,
        link: link,
        bottomLink: bottomLink,
        width: VerticalControlBar.widthOf(context),
        onItemsAttached: attachItems,
        onItemsDetached: detachItems,
        child: widget.child,
      ),
    );
  }
}

/// vertical control bar 啟用時，把 [leading]、[actions] 放進右側的 bar；未啟用時交給 [appBarBuilder] 建立 App Bar 上的按鈕
///
/// 每個按鈕可以用 [VerticalControlBarButton.alignment] 指定排在 bar 的上方或下方；同一側的按鈕依 [leading]、[actions]、[barOnlyActions] 的順序排列。
/// 未指定時 [leading] 在上方；[actions] 在有 [leading] 時排在下方，沒有時排在上方。
/// bar 下半部是 tab（沒有 [VerticalControlBarScope.bottomLink]）時，排在下方的按鈕改接在上方的按鈕之後。
///
/// [actions] 的每一項都會各自有一個外框；不顯示的按鈕不要放進 list，不要以 `SizedBox.shrink()` 等空的 widget 佔位，否則 bar 上會出現空的外框。
///
/// [actions] 中 [VerticalControlBarButton.isAppBarOnly] 的按鈕（例如「全選」、「略過」等文字按鈕）放不進 bar 的寬度，維持在 App Bar 原本的位置。
///
/// [barOnlyActions] 只顯示在 vertical control bar，用在 App Bar 上沒有對應按鈕的功能（例如 App Bar 上是 search bar，bar 上另外提供搜尋按鈕）；
/// 排在 [actions] 之後，不會交給 [appBarBuilder]，未啟用時也不顯示。
///
/// [T] 由傳入的按鈕推斷，[appBarBuilder] 拿到相同型別的按鈕；例如都傳 app 的圖示按鈕時，可以直接以它的 icon、onTap 建立 App Bar 的按鈕。
///
/// 按鈕透過 [OverlayPortal] 畫在 root overlay 上，仍沿用原本位置的 context（Theme、BlocProvider 等）。
class VerticalControlBarPortal<T extends VerticalControlBarButton> extends StatefulWidget {
  final T? leading;
  final List<T>? actions;

  /// 只顯示在 vertical control bar 的按鈕
  final List<VerticalControlBarButton>? barOnlyActions;

  /// 建立 App Bar（沒有 vertical control bar 時的橫向 bar），以 `leading`、`actions` 建立上面的按鈕
  ///
  /// 按鈕移到 vertical control bar 時，`leading` 為 null，`actions` 只剩維持在 App Bar 的文字按鈕（沒有時為 null）。
  final Widget Function(T? leading, List<T>? actions) appBarBuilder;

  const VerticalControlBarPortal({
    super.key,
    this.leading,
    this.actions,
    this.barOnlyActions,
    required this.appBarBuilder,
  });

  @override
  State<VerticalControlBarPortal<T>> createState() => _VerticalControlBarPortalState<T>();
}

class _VerticalControlBarPortalState<T extends VerticalControlBarButton> extends State<VerticalControlBarPortal<T>> {
  final overlayController = OverlayPortalController(debugLabel: 'VerticalControlBar');
  VerticalControlBarScope? scope;
  ValueChanged<Object>? detachItems;
  bool isItemsVisible = false;
  bool isOverlayMounted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    scope = VerticalControlBarScope.maybeOf(context);
    syncItems();
  }

  @override
  void didUpdateWidget(VerticalControlBarPortal<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    syncItems();
  }

  @override
  void dispose() {
    detachItems?.call(this);
    super.dispose();
  }

  /// 維持在 App Bar 的文字按鈕
  bool isAppBarAction(VerticalControlBarButton action) {
    return action.isAppBarOnly;
  }

  /// 放進 vertical control bar 的 actions：移到 bar 的 [VerticalControlBarPortal.actions]，以及只顯示在 bar 的按鈕
  List<VerticalControlBarButton> barActions() {
    return [
      ...?widget.actions?.where((action) => !isAppBarAction(action)),
      ...?widget.barOnlyActions,
    ];
  }

  /// 依各按鈕的位置分成 bar 上方與下方的按鈕，各自維持 leading、actions、barOnlyActions 的順序
  ({List<VerticalControlBarButton> top, List<VerticalControlBarButton> bottom}) alignedButtons() {
    final leading = widget.leading;
    // 未指定位置時：leading 在上方；有 leading 時 actions 排在下方，沒有時排在上方
    final actionsAlignment = leading != null ? VerticalControlBarAlignment.bottom : VerticalControlBarAlignment.top;
    final buttons = [
      if (leading != null)
        (
          button: leading,
          alignment: leading.alignment ?? .top,
        ),
      for (final action in barActions())
        (
          button: action,
          alignment: action.alignment ?? actionsAlignment,
        ),
    ];

    return (
      top: [
        for (final (:button, :alignment) in buttons)
          if (alignment == .top) button,
      ],
      bottom: [
        for (final (:button, :alignment) in buttons)
          if (alignment == .bottom) button,
      ],
    );
  }

  void syncItems() {
    final scope = this.scope;
    final hasItems = scope != null && (widget.leading != null || barActions().isNotEmpty) && VerticalControlBar.isEnabledOf(context);

    final nextDetachItems = hasItems ? scope.onItemsDetached : null;
    if (nextDetachItems != detachItems) {
      detachItems?.call(this);
      if (hasItems) {
        scope.onItemsAttached?.call(this);
      }
      detachItems = nextDetachItems;
    }

    // 被其他頁面蓋住（TickerMode 關閉）或不是目前的 tab 時不顯示
    final isVisible = hasItems && scope.isActive && TickerMode.valuesOf(context).enabled;
    if (isVisible == isItemsVisible) {
      return;
    }
    isItemsVisible = isVisible;

    // OverlayPortal 尚未 mount 時可以直接設定；之後要避開 build 階段
    if (isOverlayMounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          updateOverlay();
        }
      });
    } else {
      updateOverlay();
    }
  }

  void updateOverlay() {
    if (isItemsVisible == overlayController.isShowing) {
      return;
    }
    // show() 也會把 bar 移到最上層，讓目前的頁面蓋過其他 tab 的頁面
    if (isItemsVisible) {
      overlayController.show();
    } else {
      overlayController.hide();
    }
  }

  Widget buildItems(
    BuildContext context, {
    required List<VerticalControlBarButton> buttons,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: buttons.map((button) => VerticalControlBarItem(child: button.buildButton(context))).toList(),
    );
  }

  Widget buildOverlay(BuildContext context) {
    final scope = this.scope;
    if (!isItemsVisible || scope == null) {
      return const SizedBox.shrink();
    }
    final (top: topButtons, bottom: bottomButtons) = alignedButtons();
    // bar 下半部是 tab（沒有 bottomLink）時，排在下方的按鈕接在上方的按鈕之後
    final bottomLink = bottomButtons.isNotEmpty ? scope.bottomLink : null;

    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: scope.link,
            showWhenUnlinked: false,
            // 按鈕各自有外框，不需要底板；bar 本身的底色由 VerticalControlBarContainer 或 sheet 提供
            child: Container(
              width: scope.width,
              // 按鈕的外框（而不是 item 的範圍）從 itemsTop 開始
              padding: EdgeInsets.only(top: VerticalControlBar.itemsTopOf(context) - (_itemHeight - _itemButtonSize) / 2),
              child: buildItems(
                context,
                buttons: [
                  ...topButtons,
                  if (bottomLink == null) ...bottomButtons,
                ],
              ),
            ),
          ),
        ),
        if (bottomLink != null)
          Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: bottomLink,
              showWhenUnlinked: false,
              // 由 bar 底部往上排；不用 followerAnchor，它需要 bar 的尺寸，bar 出現或尺寸改變時不一定會重新計算
              child: FractionalTranslation(
                translation: const Offset(0, -1),
                child: SizedBox(
                  width: scope.width,
                  child: buildItems(
                    context,
                    buttons: bottomButtons,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    isOverlayMounted = true;
    // 按鈕移到 vertical control bar 時，App Bar 不再顯示它們，只留下文字按鈕
    final isEnabled = VerticalControlBar.isEnabledOf(context);
    final appBarActions = widget.actions?.where(isAppBarAction).toList();
    final leading = isEnabled ? null : widget.leading;
    final actions = !isEnabled
        ? widget.actions
        : appBarActions != null && appBarActions.isNotEmpty
        ? appBarActions
        : null;

    return OverlayPortal(
      controller: overlayController,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: buildOverlay,
      child: widget.appBarBuilder(leading, actions),
    );
  }
}
