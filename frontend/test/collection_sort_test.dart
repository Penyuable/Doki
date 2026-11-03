import 'package:dokimon/core/i18n/app_strings.dart';
import 'package:dokimon/features/collection/collection_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('setiap opsi urutan punya label terjemahan (bukan kunci mentah)', () {
    for (final code in AppStrings.supportedLocaleCodes) {
      final strings = AppStrings(code);
      for (final sort in CollectionSort.values) {
        expect(sort.i18nKey, 'collection.sort.${sort.name}');
        expect(strings.t(sort.i18nKey), isNot(startsWith('collection.')));
      }
    }
  });
}
