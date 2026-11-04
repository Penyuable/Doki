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
    final single = widget.results.length == 1;
    final maxGridHeight = MediaQuery.sizeOf(context).height * 0.58;

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      child: Clay(
        color: AppTheme.background,
        radius: 32,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
            if (single)
              Center(
                child: SizedBox(
                  width: (maxGridHeight * 2 / 3).clamp(160.0, 240.0),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: _RevealCard(
                      result: widget.results.first,
                      revealed: _revealed > 0,
                      reduceMotion: widget.reduceMotion,
                      onTap: _revealed > 0 ? null : _revealNext,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxGridHeight),
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
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
            if (!allRevealed)
              ClayButton(
                label: strings.t('gacha.skip'),
                icon: Icons.fast_forward_rounded,
                expand: true,
                onPressed: _revealAll,
              )
            else
              Row(
                children: <Widget>[
                  Expanded(
                    child: ClayButton(
                      label: strings.t('gacha.pullAgain'),
                      icon: Icons.refresh_rounded,
                      color: AppTheme.surface,
                      foreground: AppTheme.primary,
                      expand: true,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClayButton(
                      label: strings.t('common.done'),
                      expand: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                ],
              ),
          ],
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
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 380);

    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: revealed ? 1 : 0),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          final showFront = value >= 0.5 || reduceMotion;
          // Sisi depan berputar dari -90° ke 0°, bukan 90°→180°, supaya
          // tidak tampil terbalik seperti cermin setelah kartu dibuka.
          final rotation = reduceMotion
              ? 0.0
              : showFront
                  ? (value - 1) * math.pi
                  : value * math.pi;
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
                  color: AppTheme.success,
                ),
              if (result.wasPity) ...<Widget>[
                const SizedBox(height: 4),
                _Badge(
                  label: strings.t('gacha.pityHit'),
                  color: AppTheme.primary,
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
    return Clay(
      color: color,
      radius: 22,
      child: const Center(
        child: Icon(
          Icons.question_mark_rounded,
          size: 40,
          color: Colors.white,
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
          color: AppTheme.ink,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
