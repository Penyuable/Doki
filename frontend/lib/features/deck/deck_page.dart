import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_scope.dart';
import '../../core/config/game_config.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../domain/models/deck_model.dart';
import '../auth/auth_cubit.dart';
import '../profile/profile_cubit.dart';
import 'deck_builder_page.dart';
import 'deck_list_cubit.dart';

enum _DeckAction { activate, edit, delete }

class DeckPage extends StatelessWidget {
  const DeckPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return BlocProvider<DeckListCubit>(
      create: (_) => DeckListCubit(scope.repositories.deck)..load(),
      child: const _DeckView(),
    );
  }
}

class _DeckView extends StatelessWidget {
  const _DeckView();

  Future<void> _openBuilder(
    BuildContext context, {
    String? deckId,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DeckBuilderPage(deckId: deckId),
      ),
    );
    if (changed == true && context.mounted) {
      await _refreshAll(context);
    }
  }

  Future<void> _refreshAll(BuildContext context) async {
    context.read<DeckListCubit>().refresh();
    await context.read<AuthCubit>().refreshProfile();
    if (context.mounted) {
      await context.read<ProfileCubit>().refresh();
    }
  }

  Future<void> _activate(BuildContext context, DeckModel deck) async {
    final message = await context.read<DeckListCubit>().activate(deck.id);
    if (!context.mounted) return;
    final strings = AppStrings.of(context);
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    await context.read<AuthCubit>().refreshProfile();
    if (context.mounted) {
      await context.read<ProfileCubit>().refresh();
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(strings.t('deck.active'))),
        );
    }
  }

  Future<void> _delete(BuildContext context, DeckModel deck) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.t('deck.deleteConfirm', <String, String>{
          'name': deck.name,
        })),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.t('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final message = await context.read<DeckListCubit>().delete(deck.id);
    if (!context.mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    await context.read<AuthCubit>().refreshProfile();
    if (context.mounted) {
      await context.read<ProfileCubit>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return BlocBuilder<DeckListCubit, DeckListState>(
      builder: (context, state) {
        if (state is DeckListLoading) {
          return LoadingView(message: strings.t('common.loading'));
        }
        if (state is DeckListError) {
          return ErrorView(
            message: state.message,
            retryLabel: strings.t('common.retry'),
            onRetry: () => context.read<DeckListCubit>().load(),
          );
        }
        if (state is! DeckListReady) {
          return const SizedBox.shrink();
        }

        final decks = state.decks;
        final canCreate = decks.length < GameConfig.maxDecks;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings.t('deck.title'),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          strings.t('deck.size', <String, String>{
                            'count': decks.length.toString(),
                            'max': GameConfig.maxDecks.toString(),
                          }),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: canCreate ? () => _openBuilder(context) : null,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(strings.t('deck.new')),
                  ),
                ],
              ),
            ),
            if (!canCreate)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  strings.t('deck.maxDecks'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.warning,
                  ),
                ),
              ),
            Expanded(
              child: decks.isEmpty
                  ? EmptyView(
                      title: strings.t('deck.empty'),
                      icon: Icons.style_outlined,
                      action: FilledButton.icon(
                        onPressed: () => _openBuilder(context),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(strings.t('deck.new')),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      itemCount: decks.length,
                      itemBuilder: (context, index) {
                        final deck = decks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DeckCard(
                            deck: deck,
                            busy: state.busyDeckId == deck.id,
                            onAction: (action) {
                              switch (action) {
                                case _DeckAction.activate:
                                  _activate(context, deck);
                                  break;
                                case _DeckAction.edit:
                                  _openBuilder(context, deckId: deck.id);
                                  break;
                                case _DeckAction.delete:
                                  _delete(context, deck);
                                  break;
                              }
                            },
                            onTap: () => _openBuilder(context, deckId: deck.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.deck,
    required this.busy,
    required this.onAction,
    required this.onTap,
  });

  final DeckModel deck;
  final bool busy;
  final ValueChanged<_DeckAction> onAction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final accent = deck.isValid ? AppTheme.success : AppTheme.warning;

    return Panel(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: <Widget>[
              const Clay(
                width: 42,
                height: 56,
                radius: 14,
                color: AppTheme.primary,
                depth: 0.6,
                child: Icon(
                  Icons.style_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            deck.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (deck.isActive) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              strings.t('deck.active'),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${deck.cardCount}/${GameConfig.deckSize} ${strings.t('deck.cards').toLowerCase()}'
                      ' · ${deck.isValid ? strings.t('deck.valid') : strings.t('deck.invalid')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: accent,
                      ),
                    ),
                    if (!deck.isValid &&
                        deck.violations.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        strings.t(
                          'deck.violation.${deck.violations.first.code}',
                        ),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<_DeckAction>(
                  tooltip: strings.t('common.edit'),
                  onSelected: onAction,
                  itemBuilder: (context) => <PopupMenuEntry<_DeckAction>>[
                    if (!deck.isActive)
                      PopupMenuItem<_DeckAction>(
                        value: _DeckAction.activate,
                        child: Text(strings.t('deck.activate')),
                      ),
                    PopupMenuItem<_DeckAction>(
                      value: _DeckAction.edit,
                      child: Text(strings.t('common.edit')),
                    ),
                    PopupMenuItem<_DeckAction>(
                      value: _DeckAction.delete,
                      child: Text(strings.t('common.delete')),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
