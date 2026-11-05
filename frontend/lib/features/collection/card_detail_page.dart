import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/config/game_config.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../data/repositories/deck_repository.dart';
import '../../domain/models/card_model.dart';
import '../../domain/models/deck_model.dart';
import '../battle/battle_moves.dart';
import '../deck/deck_builder_page.dart';

class CardDetailPage extends StatelessWidget {
  const CardDetailPage({
    super.key,
    required this.card,
    required this.ownedCount,
  });

  final CardModel card;
  final int ownedCount;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(card.name),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: <Widget>[
              Center(
                child: SizedBox(
                  width: 230,
                  child: CardTile(
                    card: card,
                    showStats: false,
                    quantity: ownedCount > 1 ? ownedCount : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  RarityChip(
                    label: strings.t(card.rarity.i18nKey),
                    rarity: card.rarity,
                  ),
                  const SizedBox(width: 8),
                  ElementChip(
                    element: card.element,
                    label: strings.t(card.element.i18nKey),
                  ),
                  const SizedBox(width: 8),
                  _Tag(label: strings.t(card.type.i18nKey)),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  ownedCount > 0
                      ? strings.t('card.ownedCount', <String, String>{
                          'count': ownedCount.toString(),
                        })
                      : strings.t('card.notOwned'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 20),
              if (card.isUnit)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _StatCell(
                        icon: Icons.flash_on_rounded,
                        label: strings.t('card.attack'),
                        value: '${card.attack ?? 0}',
                        color: AppTheme.attack,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCell(
                        icon: Icons.favorite_rounded,
                        label: strings.t('card.hp'),
                        value: '${card.hp ?? 0}',
                        color: AppTheme.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCell(
                        icon: Icons.shield_rounded,
                        label: strings.t('card.defense'),
                        value: '${card.defense ?? 0}',
                        color: AppTheme.info,
                      ),
                    ),
                  ],
                )
              else
                _StatCell(
                  icon: Icons.bolt_rounded,
                  label: strings.t('card.cost'),
                  value: '${card.cost}',
                  color: AppTheme.accent,
                ),
              const SizedBox(height: 20),
              SectionHeader(title: strings.t('card.moves')),
              Panel(
                padding: const EdgeInsets.fromLTRB(8, 18, 8, 14),
                child: MoveOrbRow(card: card),
              ),
              const SizedBox(height: 20),
              if (card.ability != null) ...<Widget>[
                SectionHeader(title: strings.t('card.ability')),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              card.ability!.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              strings.t('card.abilityCost', <String, String>{
                                'cost': card.ability!.cost.toString(),
                              }),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        card.ability!.text,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          _Tag(
                            label: strings.t(
                              'ability.${card.ability!.type}',
                            ),
                          ),
                          _Tag(label: card.ability!.target),
                          if (card.ability!.status != null)
                            _Tag(
                              label:
                                  '${card.ability!.status!.kind} '
                                  '${card.ability!.status!.value} '
                                  '(${card.ability!.status!.turns})',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              if (card.keywords.isNotEmpty) ...<Widget>[
                SectionHeader(title: strings.t('card.keywords')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: card.keywords
                      .map(
                        (keyword) => Chip(
                          label: Text(strings.t('keyword.$keyword')),
                          avatar: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 18),
              ],
              if (card.flavorText.isNotEmpty) ...<Widget>[
                SectionHeader(title: strings.t('card.flavor')),
                Text(
                  card.flavorText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppTheme.inkSoft,
                  ),
                ),
                const SizedBox(height: 22),
              ],
              FilledButton.icon(
                onPressed: ownedCount > 0
                    ? () => _addToDeck(context)
                    : null,
                icon: const Icon(Icons.add_rounded),
                label: Text(strings.t('card.addToDeck')),
              ),
              if (ownedCount > 0) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  strings.t('deck.copyOf', <String, String>{
                    'count':
                        '${GameConfig.maxCopiesPerCard > ownedCount ? ownedCount : GameConfig.maxCopiesPerCard}',
                    'max': GameConfig.maxCopiesPerCard.toString(),
                  }),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToDeck(BuildContext context) async {
    final scope = AppScope.of(context);
    final choice = await showModalBottomSheet<_DeckChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DeckPickerSheet(repository: scope.repositories.deck),
    );
    if (choice == null || !context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeckBuilderPage(
          deckId: choice.deck?.id,
          initialCardId: card.id,
        ),
      ),
    );
  }
}

class _DeckChoice {
  const _DeckChoice(this.deck);

  final DeckModel? deck;
}

class _DeckPickerSheet extends StatefulWidget {
  const _DeckPickerSheet({required this.repository});

  final DeckRepository repository;

  @override
  State<_DeckPickerSheet> createState() => _DeckPickerSheetState();
}

class _DeckPickerSheetState extends State<_DeckPickerSheet> {
  late Future<List<DeckModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FutureBuilder<List<DeckModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(strings.t('deck.noDecks')),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => setState(
                        () => _future = widget.repository.list(),
                      ),
                      child: Text(strings.t('common.retry')),
                    ),
                  ],
                ),
              );
            }

            final decks = snapshot.data ?? const <DeckModel>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  strings.t('deck.pickDeck'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (final deck in decks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.style_rounded),
                    title: Text(deck.name),
                    subtitle: Text(
                      '${deck.cardCount}/${GameConfig.deckSize}',
                    ),
                    trailing: deck.isValid
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.success,
                          )
                        : const Icon(
                            Icons.error_outline_rounded,
                            color: AppTheme.warning,
                          ),
                    onTap: () => Navigator.of(context).pop(
                      _DeckChoice(deck),
                    ),
                  ),
                if (decks.length < GameConfig.maxDecks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.add_circle_outline_rounded),
                    title: Text(strings.t('deck.new')),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(const _DeckChoice(null)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClayPill(
      label: label,
      color: AppTheme.surfaceHigh,
      foreground: AppTheme.inkSoft,
      fontSize: 10.5,
    );
  }
}
