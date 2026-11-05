import 'dart:convert';
import 'dart:io';

import 'package:dokimon/core/ui/widgets.dart';
import 'package:dokimon/domain/models/card_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/card_factory.dart';

Widget _host(Widget child, {double width = 120}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: width, child: child)),
    ),
  );
}

void main() {
  test('creatureSeed stabil dan berbeda antar id', () {
    expect(creatureSeed('card_001'), creatureSeed('card_001'));
    expect(creatureSeed('card_001'), isNot(creatureSeed('card_002')));
  });

  test('spesies dari nama kartu: dino, burung, babi, dll', () {
    CreatureSpecies of(String name) =>
        speciesOf(testUnit('card_x', name: name));
    expect(of('Glacier Titan'), CreatureSpecies.dino);
    expect(of('Ignis Drake'), CreatureSpecies.dragon);
    expect(of('Pyre Phoenix'), CreatureSpecies.bird);
    expect(of('Cinderling'), CreatureSpecies.pig);
    expect(of('Ember Pup'), CreatureSpecies.dog);
    expect(of('Mudback Turtle'), CreatureSpecies.turtle);
    expect(of('Tidal Warden'), CreatureSpecies.turtle);
    expect(of('Obsidian Warden'), CreatureSpecies.golem);
  });

  test('katalog bawaan memakai banyak spesies berbeda', () {
    final raw = File('assets/cards/cards.seed.json').readAsStringSync();
    final units = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((c) => c['type'] == 'unit')
        .map((c) => testUnit(c['id'] as String, name: c['name'] as String));
    final kinds = units.map(speciesOf).toSet();
    expect(kinds.length, greaterThanOrEqualTo(10));
  });

  testWidgets('semua spesies & tingkat rarity tergambar tanpa error', (
    tester,
  ) async {
    const names = <String>[
      'Rex',
      'Drake',
      'Bird',
      'Pig',
      'Pup',
      'Bear',
      'Hare',
      'Cat',
      'Turtle',
      'Golem',
      'Serpent',
      'Sprite',
      'Mite',
    ];
    for (final name in names) {
      for (final rarity in Rarity.values) {
        final card = testUnit('card_$name', name: name, rarity: rarity);
        await tester.pumpWidget(
          _host(SizedBox(height: 160, child: CreatureScene(card: card))),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '$name $rarity');
      }
    }
  });

  testWidgets('CardTile merender semua elemen & rarity tanpa error', (
    tester,
  ) async {
    for (final element in CardElement.values) {
      for (final rarity in Rarity.values) {
        final card = testUnit(
          'card_${element.slug}_${rarity.name}',
          name: 'Mon ${element.slug}',
          element: element,
          rarity: rarity,
          attack: 22,
          hp: 65,
        );
        await tester.pumpWidget(_host(CardTile(card: card, quantity: 2)));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.text('Mon ${element.slug}'), findsOneWidget);
        expect(find.text('22'), findsOneWidget);
        expect(find.text('65'), findsOneWidget);
        expect(find.text('×2'), findsOneWidget);
      }
    }
  });

  testWidgets('CardTile spell & obscured', (tester) async {
    final spell = testSpell('card_spell_x', name: 'Fireball');
    await tester.pumpWidget(_host(CardTile(card: spell)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Fireball'), findsOneWidget);

    await tester.pumpWidget(
      _host(CardTile(card: spell, obscured: true), width: 60),
    );
    await tester.pump();
    expect(find.text('???'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
  });

  testWidgets('animasi berhenti saat disableAnimations aktif', (tester) async {
    final card = testUnit('card_motion', rarity: Rarity.master);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _host(CardTile(card: card)),
      ),
    );
    // Tanpa ticker aktif, pumpAndSettle selesai (tidak timeout).
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('jam animasi bersama hanya berjalan saat ada kreatur hidup', (
    tester,
  ) async {
    final clock = CreatureClock.instance;
    final card = testUnit('card_clock', name: 'Pup');

    await tester.pumpWidget(
        _host(SizedBox(height: 120, child: CreatureAvatar(card: card))));
    expect(clock.isRunning, isTrue);
    final before = clock.seconds;
    await tester.pump(const Duration(milliseconds: 500));
    expect(clock.seconds, greaterThan(before));

    await tester.pumpWidget(_host(const SizedBox()));
    expect(clock.isRunning, isFalse);

    // Kreatur diam (animate: false) tidak menyalakan jam.
    await tester.pumpWidget(
      _host(SizedBox(
          height: 120, child: CreatureAvatar(card: card, animate: false))),
    );
    expect(clock.isRunning, isFalse);
  });
}
