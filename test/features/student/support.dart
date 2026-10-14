import 'dart:convert';
import 'dart:io';

import 'package:elimupepe/core/design/clay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

export '../../design/harness.dart' show clayModes, clayScales, loadClayFonts, setPhone;

/// The `data` of a fixture in test/fixtures/app_api (a success envelope).
Map<String, dynamic> fixtureData(String name) =>
    (jsonDecode(File('test/fixtures/app_api/$name.json').readAsStringSync()) as Map<String, dynamic>)['data']
        as Map<String, dynamic>;

List<dynamic> fixtureRows(String name) =>
    (jsonDecode(File('test/fixtures/app_api/$name.json').readAsStringSync()) as Map<String, dynamic>)['data'] as List<dynamic>;

Map<String, dynamic> fixtureMeta(String name) =>
    (jsonDecode(File('test/fixtures/app_api/$name.json').readAsStringSync()) as Map<String, dynamic>)['meta'] as Map<String, dynamic>;

/// A whole screen (it brings its own Scaffold and app bar) in a theme mode and text scale.
Widget screenApp(
  Widget screen, {
  ClayThemeMode mode = ClayThemeMode.light,
  double textScale = 1.0,
  ClayThemeOptions? options,
}) {
  final theme = ClayTheme.build(options ?? ClayThemeOptions(mode: mode));
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    builder: (context, w) => ClayAppBarScope(
      onOpenAccessibility: () {},
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: w!,
      ),
    ),
    home: screen,
  );
}

/// flutter_test disables blurred shadows by default; Clay depends on them. The framework checks the
/// flag before tearDown hooks run, so each golden test restores it in a finally block.
Future<void> withShadows(Future<void> Function() body) async {
  debugDisableShadows = false;
  try {
    await body();
  } finally {
    debugDisableShadows = true;
  }
}

/// A tall phone, for tests that read content far down a long list.
void setTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

String modeName(ClayThemeMode m) => m.name;

/// The suffix of a golden file: `light_x1.0`.
String goldenKey(ClayThemeMode m, double scale) => '${m.name}_x$scale';
