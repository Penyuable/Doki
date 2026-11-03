import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../domain/models/card_model.dart';

/// Jenis jurus. Memetakan ke aksi engine yang sudah ada
/// (Attack / UseAbility / SetGuard) — tidak menambah aturan battle.
enum MoveKind { strike, ability, guard }

/// Jurus sebuah kartu untuk ditampilkan sebagai bola skill.
///
/// `power` adalah stat kartu (ATK atau power ability), bukan hasil hitung
/// damage; angka damage tetap datang dari engine (I-05).
class CardMove {
  const CardMove({
    required this.kind,
    required this.name,
    required this.icon,
    required this.color,
    this.power,
    this.cost = 0,
    this.description,
  });

  final MoveKind kind;
  final String name;
  final IconData icon;
  final Color color;
  final int? power;
  final int cost;
  final String? description;
}

/// Daftar jurus kartu: serangan dasar (unit), ability (bila ada), guard (unit).
List<CardMove> movesFor(
  CardModel card,
  AppStrings strings, {
  int? attackOverride,
}) {
  final ability = card.ability;
  return <CardMove>[
    if (card.isUnit)
      CardMove(
        kind: MoveKind.strike,
        name: strikeNameOf(card, strings),
        icon: AppTheme.elementIcon(card.element),
        color: AppTheme.elementColor(card.element),
        power: attackOverride ?? card.attack ?? 0,
      ),
    if (ability != null)
      CardMove(
        kind: MoveKind.ability,
        name: ability.name,
        icon: abilityIcon(ability.type),
        color: abilityColor(ability.type),
        power: ability.power > 0 ? ability.power : null,
        cost: ability.cost,
        description: ability.text,
      ),
    if (card.isUnit)
      CardMove(
        kind: MoveKind.guard,
        name: strings.t('battle.guard'),
        icon: Icons.shield_rounded,
        color: AppTheme.info,
        description: strings.t('move.guardHint'),
      ),
  ];
}

String strikeNameOf(CardModel card, AppStrings strings) =>
    strings.t('move.strike.${card.element.slug}');

IconData abilityIcon(String type) => switch (type) {
      'attack' => Icons.bolt_rounded,
      'heal' => Icons.favorite_rounded,
      'buff' => Icons.trending_up_rounded,
      'control' => Icons.ac_unit_rounded,
      'shield' => Icons.shield_moon_rounded,
      _ => Icons.auto_awesome_rounded,
    };

Color abilityColor(String type) => switch (type) {
      'attack' => AppTheme.danger,
      'heal' => AppTheme.success,
      'buff' => AppTheme.warning,
      'control' => AppTheme.accent,
      'shield' => AppTheme.info,
      _ => AppTheme.primary,
    };

/// Bola jurus clay: lingkaran berwarna dengan ikon, nama di bawah, dan
/// keterangan kekuatan/biaya.
class SkillOrb extends StatelessWidget {
  const SkillOrb({
    super.key,
    required this.move,
    this.onTap,
    this.enabled = true,
    this.size = 70,
  });

  final CardMove move;
  final VoidCallback? onTap;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final active = enabled && onTap != null;
    final costLabel = move.cost > 0
        ? strings.t('move.energy', <String, String>{'cost': '${move.cost}'})
        : strings.t('move.free');

    return Semantics(
      button: onTap != null,
      enabled: active,
      label: move.name,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: SizedBox(
          width: size + 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Clay(
                    width: size,
                    height: size,
                    shape: BoxShape.circle,
                    color: enabled ? move.color : AppTheme.inkFaint,
                    depth: size / 70,
                    onTap: active ? onTap : null,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(move.icon,
                              color: Colors.white, size: size * 0.38),
                          if (move.power != null)
                            Text(
                              '${move.power}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: size * 0.17,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -2,
                    child: ClayPill(
                      label: move.cost > 0 ? '${move.cost}' : '0',
                      icon: Icons.bolt_rounded,
                      color:
                          move.cost > 0 ? AppTheme.accent : AppTheme.inkFaint,
                      fontSize: size * 0.13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                move.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: (size * 0.16).clamp(10.0, 13.0),
                  fontWeight: FontWeight.w900,
                  color: AppTheme.ink,
                  height: 1.15,
                ),
              ),
              Text(
                costLabel,
                style: TextStyle(
                  fontSize: (size * 0.13).clamp(9.0, 11.0),
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Deretan bola jurus untuk sebuah kartu (dipakai di detail kartu).
class MoveOrbRow extends StatelessWidget {
  const MoveOrbRow({super.key, required this.card, this.size = 62});

  final CardModel card;
  final double size;

  @override
  Widget build(BuildContext context) {
    final moves = movesFor(card, AppStrings.of(context));
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 14,
      children: <Widget>[
        for (final move in moves) SkillOrb(move: move, size: size),
      ],
    );
  }
}
