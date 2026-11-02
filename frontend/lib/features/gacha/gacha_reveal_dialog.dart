import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../domain/models/card_model.dart';
import '../../domain/models/gacha_model.dart';

class GachaRevealDialog extends StatefulWidget {
  const GachaRevealDialog({
    super.key,
    required this.results,
    required this.reduceMotion,
    required this.haptics,
  });

  final List<GachaPullResult> results;
  final bool reduceMotion;
  final bool haptics;

  @override
  State<GachaRevealDialog> createState() => _GachaRevealDialogState();
}

class _GachaRevealDialogState extends State<GachaRevealDialog> {
  static const Duration _step = Duration(milliseconds: 300);

  Timer? _timer;
  int _revealed = 0;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _revealed = widget.results.length;
      return;
    }
    _timer = Timer.periodic(_step, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _revealNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _revealNext() {
    if (_revealed >= widget.results.length) {
      _timer?.cancel();
      return;
    }
    final result = widget.results[_revealed];
    setState(() => _revealed += 1);
    if (widget.haptics && result.rarity.isRarePlus) {
      HapticFeedback.mediumImpact();
    }
    if (_revealed >= widget.results.length) {
      _timer?.cancel();
    }
  }

  void _revealAll() {
    _timer?.cancel();
    setState(() => _revealed = widget.results.length);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final allRevealed = _revealed >= widget.results.length;
    final columns = widget.results.length == 1 ? 1 : 2;

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      child: AppBackground(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      strings.t('gacha.reveal'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (!allRevealed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    strings.t('gacha.revealHint'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.58,
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2 / 3,
                  ),
                  itemCount: widget.results.length,
                  itemBuilder: (context, index) {
                    return _RevealCard(
                      result: widget.results[index],
                      revealed: index < _revealed,
                      reduceMotion: widget.reduceMotion,
                      onTap: index < _revealed ? null : _revealNext,
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  if (!allRevealed)
                    TextButton.icon(
                      onPressed: _revealAll,
                      icon: const Icon(Icons.fast_forward_rounded, size: 18),
                      label: Text(strings.t('gacha.skip')),
                    )
                  else
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(strings.t('gacha.pullAgain')),
                      ),
                    ),
                  if (!allRevealed) const Spacer(),
                  if (!allRevealed)
                    FilledButton(
                      onPressed: _revealAll,
                      child: Text(strings.t('common.done')),
                    )
                  else ...<Widget>[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(strings.t('common.done')),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({
    required this.result,
    required this.revealed,
    required this.reduceMotion,
    this.onTap,
  });

  final GachaPullResult result;
  final bool revealed;
  final bool reduceMotion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = result.card;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 380);

    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: revealed ? 1 : 0),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          final showFront = value >= 0.5 || reduceMotion;
          final rotation = value * math.pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0014)
              ..rotateY(rotation),
            child: showFront
                ? _front(context, card)
                : _back(context, result.rarity),
          );
        },
      ),
    );
  }

  Widget _front(BuildContext context, CardModel? card) {
    final strings = AppStrings.of(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (card != null)
          CardTile(card: card, showStats: false)
        else
          Panel(
            child: Center(
              child: Text(
                result.cardId,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        Positioned(
          right: 6,
          bottom: 34,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (result.isNew)
                _Badge(
                  label: strings.t('gacha.new'),
                  color: const Color(0xFF4ADE80),
                ),
              if (result.wasPity) ...<Widget>[
                const SizedBox(height: 4),
                _Badge(
                  label: strings.t('gacha.pityHit'),
                  color: const Color(0xFFC084FC),
                ),
              ],
              if (result.guaranteedRare) ...<Widget>[
                const SizedBox(height: 4),
                _Badge(
                  label: strings.t('gacha.guaranteed'),
                  color: AppTheme.gold,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _back(BuildContext context, Rarity rarity) {
    final color = AppTheme.rarityColor(rarity);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            color.withValues(alpha: 0.42),
            const Color(0xFF15131F),
            color.withValues(alpha: 0.2),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.4),
      ),
      child: Center(
        child: Icon(
          Icons.question_mark_rounded,
          size: 40,
          color: color.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0B0A12),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
