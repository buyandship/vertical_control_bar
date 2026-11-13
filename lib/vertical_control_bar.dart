/// iPhone Duo 的 vertical control bar：外螢幕、以及內螢幕橫向時，把 App Bar 的按鈕與 tab 移到狀態列所在的右側直欄
library;

// 設定 vertical control bar 會用到的折疊狀態隨 package 一起提供，app 不需要另外依賴 foldable。
// 只匯出用得到的部分，foldable 其他 API 的變動不會影響這個 package 的使用者；需要更多時由 app 自行依賴 foldable
export 'package:foldable/foldable.dart' show DuoMediaQuery, FoldableCapabilities, FoldableData, FoldableProvider, FoldableSupportLevel, HingeStatus, SizeClass;

export 'src/vertical_control_bar.dart';
export 'src/vertical_control_bar_button.dart';
export 'src/vertical_control_bar_region.dart';
export 'src/vertical_control_bar_theme.dart';
