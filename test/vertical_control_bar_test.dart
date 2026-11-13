import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_control_bar/vertical_control_bar.dart';

// iPhone Duo simulator（以 iOS 27.1 SDK 編譯）外螢幕實測的螢幕尺寸與 safe area
const _outerDisplaySize = Size(466, 678);
const _verticalBarPadding = FakeViewPadding(
  right: 84,
  bottom: 34,
);
// 系統沒有回報範圍時，按鈕外框開始排列的高度
const _fallbackItemsTop = 174.0;

const _leadingKey = ValueKey('leading');
const _actionKey = ValueKey('action');
const _textActionKey = ValueKey('text_action');

const _duoData = FoldableData(
  capabilities: FoldableCapabilities(
    supportLevel: FoldableSupportLevel.available,
    isFoldable: true,
    hingeApiPresent: true,
    regionApiPresent: true,
    angleUnitVerified: true,
    strategy: 'test',
  ),
  status: HingeStatus.closed,
  angleDegrees: 0,
  regions: [],
  displayFeatures: [],
);

class _TestButton implements VerticalControlBarButton {
  final Key key;

  @override
  final VerticalControlBarAlignment? alignment;

  @override
  final bool isAppBarOnly;

  const _TestButton({
    required this.key,
    this.alignment,
    this.isAppBarOnly = false,
  });

  @override
  Widget buildButton(BuildContext context) {
    return isAppBarOnly
        ? TextButton(
            key: key,
            onPressed: () {},
            child: const Text('Select all'),
          )
        : IconButton(
            key: key,
            icon: const Icon(Icons.add),
            onPressed: () {},
          );
  }
}

void main() {
  void setScreen(WidgetTester tester) {
    tester.view.physicalSize = _outerDisplaySize;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = _verticalBarPadding;
    tester.view.viewPadding = _verticalBarPadding;
    addTearDown(tester.view.reset);
  }

  Widget buildApp({
    Stream<Rect>? barRegionStream,
    bool isSupportEnabled = true,
    ThemeData? theme,
  }) {
    return DuoMediaQuery(
      data: _duoData,
      child: VerticalControlBarSupport(
        isEnabled: isSupportEnabled,
        barRegionStream: barRegionStream,
        child: MaterialApp(
          theme: theme,
          home: VerticalControlBarInset(
            child: Scaffold(
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: Builder(
                  builder: (context) {
                    return VerticalControlBarPortal(
                      leading: const _TestButton(key: _leadingKey),
                      actions: const [
                        _TestButton(
                          key: _actionKey,
                          alignment: .top,
                        ),
                        _TestButton(
                          key: _textActionKey,
                          isAppBarOnly: true,
                        ),
                      ],
                      appBarBuilder: (leading, actions) {
                        return AppBar(
                          leading: leading?.buildButton(context),
                          title: const Text('Title'),
                          actions: actions?.map((action) => action.buildButton(context)).toList(),
                        );
                      },
                    );
                  },
                ),
              ),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  // 按鈕外框（VerticalControlBarItem 內的 Material）的位置
  Rect outlineRectOf(
    WidgetTester tester, {
    required Key key,
  }) {
    final outline = find.ancestor(
      of: find.byKey(key),
      matching: find.descendant(
        of: find.byType(VerticalControlBarItem),
        matching: find.byType(Material),
      ),
    );

    return tester.getRect(outline.first);
  }

  bool isInAppBar(Key key) {
    return find
        .descendant(
          of: find.byType(AppBar),
          matching: find.byKey(key),
        )
        .evaluate()
        .isNotEmpty;
  }

  test('VerticalControlBarRegion.rectFrom：把原生送來的範圍轉成 Rect', () {
    expect(
      VerticalControlBarRegion.rectFrom(<Object?, Object?>{
        'left': 382,
        'top': 174.5,
        'width': 84,
        'height': 470,
      }),
      const Rect.fromLTWH(382, 174.5, 84, 470),
    );
  });

  testWidgets('系統沒有回報範圍時，按鈕外框從固定的高度開始排列', (tester) async {
    setScreen(tester);
    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(outlineRectOf(tester, key: _leadingKey).top, _fallbackItemsTop);
    expect(outlineRectOf(tester, key: _actionKey).top, greaterThan(outlineRectOf(tester, key: _leadingKey).bottom));
  });

  testWidgets('按鈕外框從系統回報的範圍上緣開始排列，範圍改變時（例如出現即時動態）跟著移動', (tester) async {
    setScreen(tester);
    final barRegions = StreamController<Rect>();
    addTearDown(barRegions.close);

    await tester.pumpWidget(buildApp(barRegionStream: barRegions.stream));
    barRegions.add(const Rect.fromLTWH(382, 174, 84, 470));
    await tester.pump();
    await tester.pump();

    expect(outlineRectOf(tester, key: _leadingKey).top, 174);

    // 即時動態讓直欄上方的狀態區變高
    barRegions.add(const Rect.fromLTWH(382, 236, 84, 408));
    await tester.pump();
    await tester.pump();

    expect(outlineRectOf(tester, key: _leadingKey).top, 236);
    expect(outlineRectOf(tester, key: _actionKey).top, greaterThan(outlineRectOf(tester, key: _leadingKey).bottom));
  });

  testWidgets('VerticalControlBarSupport 關閉時不讀取系統回報的範圍，按鈕維持在 App Bar', (tester) async {
    setScreen(tester);
    var listenCount = 0;
    final barRegions = StreamController<Rect>.broadcast(onListen: () => listenCount += 1);
    addTearDown(barRegions.close);

    await tester.pumpWidget(
      buildApp(
        barRegionStream: barRegions.stream,
        isSupportEnabled: false,
      ),
    );
    await tester.pump();

    expect(listenCount, 0);
    expect(find.byType(VerticalControlBarItem), findsNothing);
    expect(isInAppBar(_leadingKey), isTrue);
  });

  testWidgets('isAppBarOnly 的按鈕維持在 App Bar，其他按鈕移到右側直欄', (tester) async {
    setScreen(tester);
    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(isInAppBar(_textActionKey), isTrue);
    expect(isInAppBar(_leadingKey), isFalse);
    expect(isInAppBar(_actionKey), isFalse);
    expect(find.byType(VerticalControlBarItem), findsNWidgets(2));
  });

  testWidgets('VerticalControlBarThemeData：bar 與按鈕外框使用 theme 提供的顏色', (tester) async {
    setScreen(tester);
    const outlineColor = Color(0xFF123456);
    await tester.pumpWidget(
      buildApp(
        theme: ThemeData(
          extensions: const <ThemeExtension<dynamic>>[
            VerticalControlBarThemeData(
              backgroundColor: Colors.white,
              outlineColor: outlineColor,
              indicatorColor: Colors.orange,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    final outline = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(_leadingKey),
            matching: find.descendant(
              of: find.byType(VerticalControlBarItem),
              matching: find.byType(Material),
            ),
          )
          .first,
    );
    expect((outline.shape! as StadiumBorder).side.color, outlineColor);
  });
}
