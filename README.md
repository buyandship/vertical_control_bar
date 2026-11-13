# vertical_control_bar

iPhone Duo 的 vertical control bar。外螢幕、以及內螢幕橫向時，系統把狀態列移到畫面右側的直欄，這個 package 把 App Bar 的按鈕與 tab 移進這一欄；內螢幕直向與其他 iPhone 維持原本的 App Bar。

公司內部使用，不發佈到 pub.dev。

## 需求

- Flutter 3.41 以上（Dart 3.11）
- app 需以 iOS 27.1 以上的 SDK 編譯，否則在 iPhone Duo 上會以一般 iPhone 的比例顯示，不會進入這個姿態
- 原生實作只有 iOS；其他平台可以照常依賴，不會出現 bar

## 安裝

```yaml
dependencies:
  vertical_control_bar:
    git:
      url: https://github.com/buyandship/vertical_control_bar.git
      ref: v1.0.0
```

`FoldableProvider`、`DuoMediaQuery` 等折疊狀態會一起從這個 package 匯出，不需要另外依賴 `foldable`。

## 設定

### 1. 在 `MaterialApp` 外層提供折疊狀態與開關

```dart
FoldableProvider(
  child: VerticalControlBarSupport(
    // 例如由 Remote Config 控制；切換時頁面的 State 不會重建
    isEnabled: isIphoneDuoSupportEnabled,
    child: MaterialApp(...),
  ),
)
```

`VerticalControlBarSupport` 在 iOS 會讀取系統回報的 bar 可用範圍（iOS 27.1 的 `UIView.LayoutRegion.bar`），讓按鈕排在動態島、狀態列與即時動態下方，範圍改變時一起移動。系統沒有這個 API 時使用固定的高度。

### 2. 設定顏色（選用）

```dart
ThemeData(
  extensions: const <ThemeExtension<dynamic>>[
    VerticalControlBarThemeData(
      backgroundColor: Colors.white,
      outlineColor: Color(0xFFE0E0E0),
      indicatorColor: Color(0xFFEEEEEE),
    ),
  ],
)
```

沒有設定時使用 `VerticalControlBarThemeData.fallback`。

### 3. 每個頁面包上 `VerticalControlBarInset`

```dart
MaterialPageRoute(
  builder: (context) => VerticalControlBarInset(child: page),
)
```

頁面有按鈕移到 bar 時才在右側留出 bar；dialog、bottom sheet 維持原本的 bar。

### 4. App Bar 的按鈕實作 `VerticalControlBarButton`

```dart
class AppIconButton implements VerticalControlBarButton {
  final IconData icon;
  final VoidCallback onTap;

  @override
  final VerticalControlBarAlignment? alignment;

  const AppIconButton({
    required this.icon,
    required this.onTap,
    this.alignment,
  });

  // 文字按鈕等放不進 bar 寬度的按鈕回傳 true，維持在 App Bar
  @override
  bool get isAppBarOnly => false;

  @override
  Widget buildButton(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onTap,
    );
  }
}
```

### 5. 用 `VerticalControlBarPortal` 建立 App Bar

```dart
Scaffold(
  appBar: PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight),
    child: VerticalControlBarPortal(
      leading: AppIconButton(
        icon: Icons.arrow_back,
        onTap: () => Navigator.of(context).pop(),
      ),
      actions: [
        AppIconButton(
          icon: Icons.share,
          onTap: share,
        ),
      ],
      appBarBuilder: (leading, actions) {
        return AppBar(
          leading: leading?.buildButton(context),
          title: const Text('Title'),
          actions: actions?.map((action) => action.buildButton(context)).toList(),
        );
      },
    ),
  ),
  body: ...,
)
```

bar 啟用時，`leading`、`actions` 移到右側的 bar，`appBarBuilder` 只拿到留在 App Bar 的按鈕；未啟用時全部交給 `appBarBuilder`。

- `alignment`：指定排在 bar 的上方或下方
- `barOnlyActions`：只顯示在 bar 上的按鈕（例如 App Bar 是 search bar，bar 上另外提供搜尋按鈕）
- 不顯示的按鈕不要放進 `actions`，空的 widget 也會在 bar 上產生一個外框

### Tab

有 tab 的頁面由 tab 的容器自行建立 `VerticalControlBarScope`，以 `VerticalControlBarLayout`、`VerticalControlBarContainer`、`VerticalControlBarGroup` 組出 bar。可以參考 bns-app 的 `lib/screens/root_container/components/tab_navigation_bar.dart`。

## 測試與 preview

`VerticalControlBarSupport(barRegionStream: ...)` 可以傳入假的範圍，模擬系統回報（例如即時動態讓範圍上緣變低）；搭配 `DuoMediaQuery(data: FoldableData(...))` 模擬 iPhone Duo 的姿態。範例見 `test/vertical_control_bar_test.dart`。

## 開發

```sh
fvm flutter test
```

和 app 一起開發時，在 app 的根目錄建立 `pubspec_overrides.yaml`（不要 commit），改用本機的 package：

```yaml
dependency_overrides:
  vertical_control_bar:
    path: ../vertical_control_bar
```

## 發版

1. 更新 `pubspec.yaml` 的 `version` 與 `CHANGELOG.md`
2. commit 後打 tag（例如 `v1.1.0`）並 push
3. app 的 `ref` 改成新的 tag，執行 `flutter pub get`
