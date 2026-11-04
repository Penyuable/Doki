// Generator ikon app Dokimon (Android legacy + adaptive, iOS).
//
// Jalankan dari folder `frontend`:
//   flutter test tool/generate_app_icon_test.dart
//
// Ikon digambar dari widget yang sama dengan logo di aplikasi (tile clay +
// kreatur api), jadi ikon & logo selalu konsisten.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dokimon/core/theme/app_theme.dart';
import 'package:dokimon/core/ui/widgets.dart';
import 'package:dokimon/domain/models/card_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

enum _IconStyle { legacy, adaptiveForeground, opaque }

final CardModel _mascot = mascotCard(
  'card_001',
  CardElement.fire,
  rarity: Rarity.common,
  name: 'Ember Rex',
);

Widget _disc(double diameter) {
  return Clay(
    width: diameter,
    height: diameter,
    shape: BoxShape.circle,
    color: const Color(0xFFFFE2CF),
    depth: (diameter / 240).clamp(0.3, 0.7),
    child: Padding(
      padding: EdgeInsets.only(top: diameter * 0.06),
      child: CreatureAvatar(card: _mascot, animate: false),
    ),
  );
}

Widget _art(_IconStyle style, double size) {
  switch (style) {
    case _IconStyle.legacy:
      return Center(
        child: Clay(
          width: size * 0.88,
          height: size * 0.88,
          radius: size * 0.24,
          color: AppTheme.primary,
          depth: (size / 320).clamp(0.3, 0.7),
          alignment: Alignment.center,
          child: _disc(size * 0.66),
        ),
      );
    case _IconStyle.adaptiveForeground:
      // Zona aman adaptive icon = 66/108 diameter; disc dibuat 56%.
      return Center(child: _disc(size * 0.56));
    case _IconStyle.opaque:
      return ColoredBox(
        color: AppTheme.primary,
        child: Center(child: _disc(size * 0.74)),
      );
  }
}

Future<void> _render(
  WidgetTester tester,
  _IconStyle style,
  int pixels,
  String path, {
  bool opaquePng = false,
}) async {
  final key = GlobalKey();
  // Gambar pada 256 logis lalu skala ke ukuran target agar detail konsisten.
  const logical = 256.0;
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox.square(
              dimension: logical,
              child: _art(style, logical),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixels / logical);
    final List<int> png;
    if (opaquePng) {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      png =
          _encodeRgbPng(rgba!.buffer.asUint8List(), image.width, image.height);
    } else {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      png = bytes!.buffer.asUint8List();
    }
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png);
  });
}

void main() {
  testWidgets('generate app icons', (tester) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const res = 'android/app/src/main/res';
    const densities = <String, double>{
      'mdpi': 1,
      'hdpi': 1.5,
      'xhdpi': 2,
      'xxhdpi': 3,
      'xxxhdpi': 4,
    };
    for (final entry in densities.entries) {
      await _render(
        tester,
        _IconStyle.legacy,
        (48 * entry.value).round(),
        '$res/mipmap-${entry.key}/ic_launcher.png',
      );
      await _render(
        tester,
        _IconStyle.adaptiveForeground,
        (108 * entry.value).round(),
        '$res/mipmap-${entry.key}/ic_launcher_foreground.png',
      );
    }

    const iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents =
        jsonDecode(File('$iosDir/Contents.json').readAsStringSync())
            as Map<String, dynamic>;
    final done = <String>{};
    for (final image in (contents['images'] as List<dynamic>)) {
      final map = image as Map<String, dynamic>;
      final file = map['filename'] as String?;
      if (file == null || !done.add(file)) continue;
      final points = double.parse((map['size'] as String).split('x').first);
      final scale = double.parse((map['scale'] as String).replaceAll('x', ''));
      // App Store menolak ikon dengan kanal alpha: tulis PNG RGB.
      await _render(
        tester,
        _IconStyle.opaque,
        (points * scale).round(),
        '$iosDir/$file',
        opaquePng: true,
      );
    }

    // Logo layar launch iOS (168pt, transparan di atas latar storyboard).
    const launchDir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
    for (final (scale, suffix) in <(int, String)>[
      (1, ''),
      (2, '@2x'),
      (3, '@3x')
    ]) {
      await _render(
        tester,
        _IconStyle.legacy,
        168 * scale,
        '$launchDir/LaunchImage$suffix.png',
      );
    }
  });
}

/// PNG truecolor (RGB, tanpa alpha) dari piksel RGBA.
List<int> _encodeRgbPng(Uint8List rgba, int width, int height) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      raw
        ..addByte(rgba[i])
        ..addByte(rgba[i + 1])
        ..addByte(rgba[i + 2]);
    }
  }
  final out = BytesBuilder()
    ..add(const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final typeBytes = ascii.encode(type);
    out
      ..add(_u32(data.length))
      ..add(typeBytes)
      ..add(data)
      ..add(_u32(_crc32(<int>[...typeBytes, ...data])));
  }

  chunk('IHDR', <int>[..._u32(width), ..._u32(height), 8, 2, 0, 0, 0]);
  chunk('IDAT', zlib.encode(raw.takeBytes()));
  chunk('IEND', const <int>[]);
  return out.takeBytes();
}

List<int> _u32(int v) => <int>[
      (v >> 24) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 8) & 0xFF,
      v & 0xFF,
    ];

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
