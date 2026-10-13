import 'dart:io';

import 'package:elimupepe/core/design/clay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled fonts so widget tests and goldens render real glyphs.
Future<void> loadClayFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = await File(f).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Fredoka', ['assets/fonts/Fredoka.ttf']);
  await load('Nunito', ['assets/fonts/Nunito.ttf']);
  await load('OpenDyslexic', [
    'assets/fonts/OpenDyslexic3-Regular.ttf',
    'assets/fonts/OpenDyslexic3-Bold.ttf',
  ]);
  final lucide = await rootBundle
      .load('packages/lucide_icons_flutter/assets/lucide.ttf');
  final l = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(Future.value(lucide));
  await l.load();
}

const clayModes = ClayThemeMode.values;
const clayScales = [1.0, 1.5, 2.0];

Widget clayApp(
  Widget child, {
  ClayThemeMode mode = ClayThemeMode.light,
  double textScale = 1.0,
  ClayThemeOptions? options,
  bool scroll = true,
  PreferredSizeWidget? appBar,
  VoidCallback? onOpenAccessibility,
}) {
  final o = options ?? ClayThemeOptions(mode: mode);
  final theme = ClayTheme.build(o);
  Widget body = Padding(
    padding: const EdgeInsets.all(ClaySpace.s4),
    child: child,
  );
  if (scroll) body = SingleChildScrollView(child: body);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    builder: (context, w) => ClayAppBarScope(
      onOpenAccessibility: onOpenAccessibility,
      child: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: w!,
      ),
    ),
    home: Scaffold(appBar: appBar, body: body),
  );
}

void setPhone(WidgetTester tester, {double dpr = 1.0}) {
  tester.view.physicalSize = Size(360 * dpr, 780 * dpr);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Runs [verify] for every theme mode and text scale (1.0, 1.5, 2.0) at
/// 360x780 dp and asserts: no layout exception, 48 dp tap targets, labelled
/// tap targets.
void testClayMatrix(
  String description,
  Widget Function(BuildContext context) build, {
  Future<void> Function(WidgetTester tester)? verify,
  bool scroll = true,
  PreferredSizeWidget? appBar,
}) {
  for (final mode in clayModes) {
    for (final scale in clayScales) {
      testWidgets('$description [${mode.name} x$scale]', (tester) async {
        final semantics = tester.ensureSemantics();
        setPhone(tester);
        await tester.pumpWidget(clayApp(
          Builder(builder: build),
          mode: mode,
          textScale: scale,
          scroll: scroll,
          appBar: appBar,
        ));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await verify?.call(tester);
        semantics.dispose();
      });
    }
  }
}
