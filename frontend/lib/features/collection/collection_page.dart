import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../domain/models/card_model.dart';
import '../catalog/catalog_cubit.dart';
import 'card_detail_page.dart';
import 'collection_cubit.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return BlocBuilder<CatalogCubit, CatalogState>(
      builder: (context, catalogState) {
        if (catalogState is CatalogLoading) {
          return LoadingView(message: strings.t('common.loading'));
        }
        if (catalogState is! CatalogReady) {
          final message = catalogState is CatalogError
              ? catalogState.message
              : strings.t('error.catalog');
          return ErrorView(
            message: message,
            retryLabel: strings.t('common.retry'),
            onRetry: () => context.read<CatalogCubit>().load(),
          );
        }

        return BlocBuilder<CollectionCubit, CollectionState>(
          builder: (context, collectionState) {
            if (collectionState is CollectionLoading) {
              return LoadingView(message: strings.t('common.loading'));
            }
            if (collectionState is CollectionError) {
              return ErrorView(
                message: collectionState.message,
                retryLabel: strings.t('common.retry'),
                onRetry: () => context.read<CollectionCubit>().load(),
              );
            }
            if (collectionState is! CollectionReady) {
              return const SizedBox.shrink();
            }

            final catalog = catalogState.snapshot;
            final owned = collectionState.owned;
            final cards = context.read<CollectionCubit>().applyFilter(
              catalog.cards,
              owned: owned,
            );

            return _CollectionBody(
              cards: cards,
              owned: owned,
              totalOwned: owned.length,
              totalCards: catalog.cards.where((card) => !card.retired).length,
              offline: catalog.isOffline || collectionState.offline,
              filter: collectionState.filter,
              searchController: _searchController,
            );
          },
        );
      },
    );
  }
}

class _CollectionBody extends StatelessWidget {
  const _CollectionBody({
    required this.cards,
    required this.owned,
    required this.totalOwned,
    required this.totalCards,
    required this.offline,
    required this.filter,
    required this.searchController,
  });

  final List<CardModel> cards;
  final Map<String, int> owned;
  final int totalOwned;
  final int totalCards;
  final bool offline;
  final CollectionFilter filter;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final cubit = context.read<CollectionCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (offline)
          OfflineBanner(message: strings.t('common.offline')),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      strings.t('collection.title'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  PopupMenuButton<CollectionSort>(
                    initialValue: filter.sort,
                    tooltip: strings.t('collection.sort'),
                    onSelected: cubit.setSort,
                    itemBuilder: (context) => CollectionSort.values
                        .map(
                          (sort) => PopupMenuItem<CollectionSort>(
                            value: sort,
                            child: Text(strings.t(sort.i18nKey)),
                          ),
                        )
                        .toList(growable: false),
                    child: ClayPill(
                      label: strings.t(filter.sort.i18nKey),
                      icon: Icons.sort_rounded,
                      color: AppTheme.surface,
                      foreground: AppTheme.ink,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Text(
                strings.t('collection.owned', <String, String>{
                  'owned': totalOwned.toString(),
                  'total': totalCards.toString(),
                }),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                onChanged: cubit.setQuery,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: strings.t('collection.searchHint'),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: filter.query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            searchController.clear();
                            cubit.setQuery('');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              _ChipRow(
                children: <Widget>[
                  _Choice(
                    label: strings.t('common.all'),
                    selected: filter.element == null,
                    onTap: () => cubit.setElement(null),
                  ),
                  for (final element in CardElement.values)
                    _Choice(
                      label: strings.t(element.i18nKey),
                      selected: filter.element == element,
                      color: AppTheme.elementColor(element),
                      onTap: () => cubit.setElement(element),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  _MoreFiltersButton(
                    active: _extraFilterCount(filter),
                    onTap: () => _openMoreFilters(context),
                  ),
                  const Spacer(),
                  if (!filter.isDefault)
                    TextButton.icon(
                      onPressed: () {
                        searchController.clear();
                        cubit.resetFilter();
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: Text(strings.t('collection.reset')),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: cards.isEmpty
              ? EmptyView(
                  title: strings.t('collection.empty'),
                  icon: Icons.filter_alt_off_rounded,
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2 / 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    final quantity = owned[card.id] ?? 0;
                    return CardTile(
                      card: card,
                      quantity: quantity > 1 ? quantity : null,
                      obscured: quantity == 0,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CardDetailPage(
                              card: card,
                              ownedCount: quantity,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

int _extraFilterCount(CollectionFilter filter) =>
    (filter.rarity == null ? 0 : 1) +
    (filter.type == null ? 0 : 1) +
    (filter.ownedOnly == null ? 0 : 1);

/// Lembar filter rarity & tipe/kepemilikan (di luar baris elemen).
void _openMoreFilters(BuildContext context) {
  final cubit = context.read<CollectionCubit>();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => BlocProvider<CollectionCubit>.value(
      value: cubit,
      child: BlocBuilder<CollectionCubit, CollectionState>(
        builder: (context, state) {
          if (state is! CollectionReady) return const SizedBox.shrink();
          final filter = state.filter;
          final strings = AppStrings.of(context);
          Widget section(String title, List<Widget> chips) => Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(title: title),
                Wrap(spacing: 8, runSpacing: 10, children: chips),
              ],
            ),
          );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  section(strings.t('collection.filterRarity'), <Widget>[
                    _Choice(
                      label: strings.t('common.all'),
                      selected: filter.rarity == null,
                      onTap: () => cubit.setRarity(null),
                    ),
                    for (final rarity in Rarity.values)
                      _Choice(
                        label: strings.t(rarity.i18nKey),
                        selected: filter.rarity == rarity,
                        color: AppTheme.rarityColor(rarity),
                        onTap: () => cubit.setRarity(rarity),
                      ),
                  ]),
                  section(strings.t('collection.filterType'), <Widget>[
                    _Choice(
                      label: strings.t('common.all'),
                      selected: filter.type == null,
                      onTap: () => cubit.setType(null),
                    ),
                    _Choice(
                      label: strings.t('type.unit'),
                      selected: filter.type == CardType.unit,
                      onTap: () => cubit.setType(CardType.unit),
                    ),
                    _Choice(
                      label: strings.t('type.spell'),
                      selected: filter.type == CardType.spell,
                      onTap: () => cubit.setType(CardType.spell),
                    ),
                  ]),
                  section(strings.t('collection.filterOwned'), <Widget>[
                    _Choice(
                      label: strings.t('common.all'),
                      selected: filter.ownedOnly == null,
                      onTap: () => cubit.setOwnedOnly(null),
                    ),
                    _Choice(
                      label: strings.t('collection.ownedFilter'),
                      selected: filter.ownedOnly == true,
                      onTap: () => cubit.setOwnedOnly(true),
                    ),
                    _Choice(
                      label: strings.t('collection.notOwnedFilter'),
                      selected: filter.ownedOnly == false,
                      onTap: () => cubit.setOwnedOnly(false),
                    ),
                  ]),
                  ClayButton(
                    label: strings.t('common.done'),
                    expand: true,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _MoreFiltersButton extends StatelessWidget {
  const _MoreFiltersButton({required this.active, required this.onTap});

  final int active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Clay(
      radius: 999,
      depth: 0.5,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.tune_rounded, size: 18, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            strings.t('collection.moreFilters'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: AppTheme.ink,
            ),
          ),
          if (active > 0) ...<Widget>[
            const SizedBox(width: 6),
            ClayPill(label: '$active', color: AppTheme.primary, fontSize: 10),
          ],
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) => Center(child: children[index]),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppTheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Clay(
        radius: 999,
        color: selected ? accent : AppTheme.surface,
        depth: selected ? 0.45 : 0.3,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppTheme.inkSoft,
          ),
        ),
      ),
    );
  }
}
