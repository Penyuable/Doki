import 'package:dokimon/core/i18n/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teks panduan & petunjuk arena tersedia di id dan en', () {
    final keys = <String>[
      'help.title',
      'help.next',
      'help.start',
      for (final step in <String>[
        'collect',
        'deck',
        'summon',
        'moves',
        'win'
      ]) ...<String>['help.$step.title', 'help.$step.body'],
      'battle.hint.botTurn',
      'battle.hint.play',
      'battle.hint.act',
      'battle.hint.endTurn',
      'battle.cantPlay.energy',
      'battle.cantPlay.board',
      'battle.cantPlay.target',
      'battle.cantPlay.turn',
      'home.heroTitle',
      'home.heroBody',
      'deck.deckCount',
      'collection.moreFilters',
      'collection.filterOwned',
    ];
    for (final code in AppStrings.supportedLocaleCodes) {
      final strings = AppStrings(code);
      for (final key in keys) {
        expect(strings.t(key), isNot(key), reason: '$code: $key');
      }
    }
  });

  test('alasan energi menyebut angka sebenarnya', () {
    const strings = AppStrings('id');
    expect(
      strings.t('battle.cantPlay.energy', <String, String>{
        'cost': '3',
        'energy': '1',
      }),
      'Energi kurang: butuh 3, kamu punya 1.',
    );
  });
}
