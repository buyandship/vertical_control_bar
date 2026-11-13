# Changelog

## 1.0.0

從 bns-app 抽出成獨立的 package。

- `VerticalControlBarPortal`：把 App Bar 的 leading、actions 移到 iPhone Duo 右側的 vertical control bar；`isAppBarOnly` 的按鈕維持在 App Bar，`barOnlyActions` 只顯示在 bar 上
- 依 iOS 27.1 `UIView.LayoutRegion.bar` 系統回報的範圍排列按鈕，避開動態島、狀態列與即時動態，範圍改變時一起移動；系統沒有這個 API 時使用固定的高度
- `VerticalControlBarSupport`：開關 vertical control bar，並提供系統回報的範圍；可傳入假的範圍供測試與 preview 使用
- `VerticalControlBarThemeData`：以 `ThemeExtension` 設定 bar 與按鈕外框的顏色
- `VerticalControlBarButton`：app 的按鈕實作這個 interface 即可放進 bar
- 匯出設定時會用到的 `foldable` 符號（`FoldableProvider`、`DuoMediaQuery` 等），app 不需要另外依賴 `foldable`
