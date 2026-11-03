import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_scope.dart';
import '../../core/config/game_config.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../domain/deck_rules.dart';
import '../../domain/models/card_model.dart';
import 'deck_builder_cubit.dart';

class DeckBuilderPage extends StatelessWidget {
  const DeckBuilderPage({super.key, this.deckId, this.initialCardId});

  final String? deckId;
  final String? initialCardId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return BlocProvider<DeckBuilderCubit>(
      create: (_) => DeckBuilderCubit(
        decks: scope.repositories.deck,
        catalog: scope.repositories.catalog,
        inventory: scope.repositories.inventory,
      )..init(deckId: deckId, initialCardId: initialCardId),
      child: _DeckBuilderView(
        deckId: deckId,
        initialCardId: initialCardId,
      ),
    );
  }
}

class _DeckBuilderView extends StatefulWidget {
  const _DeckBuilderView({this.deckId, this.initialCardId});

  final String? deckId;
  final String? initialCardId;

  @override
  State<_DeckBuilderView> createState() => _DeckBuilderViewState();
}

class _DeckBuilderViewState extends State<_DeckBuilderView> {
  final _nameController = TextEditingController();
  bool _nameInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cubit = context.read<DeckBuilderCubit>();
    final ok = await cubit.save();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    final message = cubit.state.saveError;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return BlocConsumer<DeckBuilderCubit, DeckBuilderState>(
      listener: (context, state) {
        if (!_nameInitialized && !state.loading) {
          _nameInitialized = true;
          _nameController.text = state.name;
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.deckId == null
                  ? strings.t('deck.newTitle')
                  : strings.t('deck.builderTitle'),
            ),
            leading: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: state.canSave ? _save : null,
                child: state.saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(strings.t('deck.save')),
              ),
            ],
          ),
          body: AppBackground(
            child: SafeArea(
              top: false,
              child: state.loading
                  ? LoadingView(message: strings.t('common.loading'))
                  : state.loadError != null
                  ? ErrorView(
                      message: state.loadError!,
                      retryLabel: strings.t('common.retry'),
                      onRetry: () => context.read<DeckBuilderCubit>().init(
                        deckId: widget.deckId,
                        initialCardId: widget.initialCardId,
                      ),
                    )
                  : _BuilderBody(
                      nameController: _nameController,
                      onSave: _save,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _BuilderBody extends StatelessWidget {
  const _BuilderBody({required this.nameController, required this.onSave});

  final TextEditingController nameController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final cubit = context.read<DeckBuilderCubit>();
    final state = context.watch<DeckBuilderCubit>().state;
    final validation = state.validation;

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: nameController,
                  onChanged: cubit.setName,
                  maxLength: 24,
                  decoration: InputDecoration(
                    labelText: strings.t('deck.name'),
                    hintText: strings.t('deck.nameHint'),
                    counterText: '',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _Counter(
                      label: strings.t('deck.size', <String, String>{
                        'count': state.totalCards.toString(),
                        'max': GameConfig.deckSize.toString(),
                      }),
                      good: state.totalCards == GameConfig.deckSize,
                    ),
                    const SizedBox(width: 8),
                    _Counter(
                      label: validation.valid
                          ? strings.t('deck.valid')
                          : strings.t('deck.invalid'),
                      good: validation.valid,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: state.entries.isEmpty ? null : cubit.clear,
                      child: Text(strings.t('deck.clear')),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Panel(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: _Curve(curve: validation.curve),
                ),
                if (state.saveError != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    state.saveError!,
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (validation.violations.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  for (final violation in validation.violations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: AppTheme.warning,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _violationText(strings, violation),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          TabBar(
            tabs: <Widget>[
              Tab(text: strings.t('deck.selected')),
              Tab(text: strings.t('deck.collection')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _DeckContentsTab(strings: strings),
                _AddCardsTab(strings: strings),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              onPressed: state.canSave ? onSave : null,
              icon: state.saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                state.saving
                    ? strings.t('deck.saving')
                    : strings.t('deck.save'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _violationText(AppStrings strings, DeckRuleViolation violation) {
    final code = violation.code;
    final count = violation.actual;
    final limit = violation.limit;
    if (code == 'DECK_SIZE') {
      return strings.t('deck.size', <String, String>{
        'count': '${count ?? 0}',
        'max': GameConfig.deckSize.toString(),
      });
    }
    if (code == 'COPY_LIMIT_EXCEEDED') {
      return strings.t('deck.copyLimit', <String, String>{
        'count': '${count ?? 0}',
        'max': '${limit ?? GameConfig.maxCopiesPerCard}',
      });
    }
    return strings.t('deck.violation.$code');
  }
}

class _DeckContentsTab extends StatelessWidget {
  const _DeckContentsTab({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeckBuilderCubit>();
    final state = context.watch<DeckBuilderCubit>().state;

    final entries = state.entries.entries.toList()
      ..sort((a, b) {
        final cardA = state.catalog[a.key];
        final cardB = state.catalog[b.key];
        final costA = cardA?.cost ?? 0;
        final costB = cardB?.cost ?? 0;
        final byCost = costA.compareTo(costB);
        return byCost != 0
            ? byCost
            : (cardA?.name ?? a.key).compareTo(cardB?.name ?? b.key);
      });

    if (entries.isEmpty) {
      return EmptyView(
        title: strings.t('deck.empty'),
        icon: Icons.style_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final card = state.catalog[entry.key];
        if (card == null) return const SizedBox.shrink();
        final quantity = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _CardRow(
            card: card,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  onPressed: () => cubit.remove(card.id),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  tooltip: strings.t('common.delete'),
                ),
                Text(
                  '$quantity',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                IconButton(
                  onPressed: state.canAdd(card.id)
                      ? () => cubit.add(card.id)
                      : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: strings.t('deck.addCards'),
                ),
              ],
            ),
            subtitle: strings.t('deck.copyOf', <String, String>{
              'count': quantity.toString(),
              'max': GameConfig.maxCopiesPerCard.toString(),
            }),
          ),
        );
      },
    );
  }
}

class _AddCardsTab extends StatefulWidget {
  const _AddCardsTab({required this.strings});

  final AppStrings strings;

  @override
  State<_AddCardsTab> createState() => _AddCardsTabState();
}

class _AddCardsTabState extends State<_AddCardsTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeckBuilderCubit>();
    final state = context.watch<DeckBuilderCubit>().state;
    final query = _query.trim().toLowerCase();
    final cards = state.collectionCards
        .where(
          (card) =>
              query.isEmpty || card.name.toLowerCase().contains(query),
        )
        .toList(growable: false);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: widget.strings.t('deck.searchHint'),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
            ),
          ),
        ),
        Expanded(
          child: cards.isEmpty
              ? EmptyView(
                  title: widget.strings.t('collection.empty'),
                  icon: Icons.search_off_rounded,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    final owned = state.owned[card.id] ?? 0;
                    final copies = state.entries[card.id] ?? 0;
                    final addable = state.canAdd(card.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CardRow(
                        card: card,
                        subtitle: widget.strings.t(
                          'deck.copyOf',
                          <String, String>{
                            'count': copies.toString(),
                            'max': GameConfig.maxCopiesPerCard.toString(),
                          },
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '×$owned',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.inkSoft,
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton.filledTonal(
                              onPressed: addable
                                  ? () => cubit.add(card.id)
                                  : null,
                              icon: const Icon(
                                Icons.add_rounded,
                                size: 18,
                              ),
                              tooltip: widget.strings.t('deck.addCards'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.trailing,
    required this.subtitle,
  });

  final CardModel card;
  final Widget trailing;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 38,
            height: 56,
            child: CardArtwork(card: card, borderRadius: 8, animate: false),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${card.cost}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    RarityChip(
                      label: card.rarity.api,
                      rarity: card.rarity,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.good});

  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final color = good ? AppTheme.success : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _Curve extends StatelessWidget {
  const _Curve({required this.curve});

  final Map<int, int> curve;

  @override
  Widget build(BuildContext context) {
    var maxCount = 1;
    for (final count in curve.values) {
      if (count > maxCount) maxCount = count;
    }

    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (var cost = 0; cost <= 6; cost++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Container(
                    height:
                        4 +
                        38 *
                            ((cost == 6
                                    ? curve.entries
                                          .where((entry) => entry.key >= 6)
                                          .fold<int>(
                                            0,
                                            (sum, entry) => sum + entry.value,
                                          )
                                    : (curve[cost] ?? 0)) /
                                maxCount),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cost == 6 ? '6+' : '$cost',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
