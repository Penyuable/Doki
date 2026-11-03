import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/models/card_model.dart';
import '../theme/app_theme.dart';
import 'clay.dart';
import 'creature_avatar.dart';

export 'clay.dart';
export 'creature_avatar.dart';

/// Latar polos pastel dengan beberapa gumpalan clay dekoratif.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.background,
      child: Stack(
        children: <Widget>[
          const Positioned(
            top: -70,
            right: -50,
            child: _Blob(color: Color(0xFFD8D2FA), size: 190),
          ),
          const Positioned(
            top: 260,
            left: -80,
            child: _Blob(color: Color(0xFFFCDCE7), size: 150),
          ),
          const Positioned(
            bottom: -60,
            right: 30,
            child: _Blob(color: Color(0xFFD3ECF8), size: 170),
          ),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Clay(
          color: color,
          width: size,
          height: size,
          shape: BoxShape.circle,
          depth: 0.6,
        ),
      ),
    );
  }
}

/// Logo Dokimon: tile clay ungu dengan kreatur api. Sama dengan ikon app.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96, this.animate = true});

  final double size;
  final bool animate;

  static final CardModel _mascot = mascotCard(
    'card_001',
    CardElement.fire,
    name: 'Ember Rex',
  );

  @override
  Widget build(BuildContext context) {
    return Clay(
      width: size,
      height: size,
      radius: size * 0.3,
      color: AppTheme.primary,
      depth: (size / 90).clamp(0.4, 1.2),
      child: Padding(
        padding: EdgeInsets.all(size * 0.1),
        child: Clay(
          shape: BoxShape.circle,
          color: const Color(0xFFFFE2CF),
          depth: (size / 140).clamp(0.3, 0.9),
          child: Padding(
            padding: EdgeInsets.only(top: size * 0.04),
            child: CreatureAvatar(card: _mascot, animate: animate),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.1,
                    color: AppTheme.ink,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Clay(
      color: color ?? AppTheme.surface,
      radius: 26,
      padding: padding,
      child: child,
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Clay(
            width: 64,
            height: 64,
            shape: BoxShape.circle,
            padding: EdgeInsets.all(18),
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Coba lagi',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Clay(
              width: 76,
              height: 76,
              shape: BoxShape.circle,
              color: Color(0xFFFCDCE3),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 36,
                color: AppTheme.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 16),
              ClayButton(label: retryLabel, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Clay(
              width: 80,
              height: 80,
              shape: BoxShape.circle,
              child: Icon(icon, size: 38, color: AppTheme.inkFaint),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Pil clay kecil berwarna solid.
class ClayPill extends StatelessWidget {
  const ClayPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.foreground = Colors.white,
    this.fontSize = 11,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final Color foreground;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Clay(
      color: color,
      radius: 999,
      depth: 0.4,
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.85,
        vertical: fontSize * 0.4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: fontSize * 1.25, color: foreground),
            SizedBox(width: fontSize * 0.35),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RarityChip extends StatelessWidget {
  const RarityChip({super.key, required this.label, required this.rarity});

  final String label;
  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    return ClayPill(
      label: label.toUpperCase(),
      color: AppTheme.rarityColor(rarity),
      fontSize: 10,
    );
  }
}

class ElementChip extends StatelessWidget {
  const ElementChip({super.key, required this.element, required this.label});

  final CardElement element;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClayPill(
      label: label,
      icon: AppTheme.elementIcon(element),
      color: AppTheme.elementColor(element),
      fontSize: 11,
    );
  }
}

class WalletChips extends StatelessWidget {
  const WalletChips({super.key, required this.gold, required this.gems});

  final int gold;
  final int gems;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClayPill(
          label: gold.toString(),
          icon: Icons.monetization_on_rounded,
          color: AppTheme.gold,
          fontSize: 12,
        ),
        const SizedBox(width: 8),
        ClayPill(
          label: gems.toString(),
          icon: Icons.diamond_rounded,
          color: AppTheme.gem,
          fontSize: 12,
        ),
      ],
    );
  }
}

class StatBox extends StatelessWidget {
  const StatBox({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = AppTheme.primary,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Clay(
              width: 32,
              height: 32,
              shape: BoxShape.circle,
              color: color,
              depth: 0.5,
              child: Icon(icon, size: 17, color: Colors.white),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.ink,
                ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Bar HP clay: alur cekung + isi pil solid.
class HpBar extends StatelessWidget {
  const HpBar({
    super.key,
    required this.current,
    required this.max,
    this.height = 10,
    this.color = AppTheme.success,
  });

  final int current;
  final int max;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    final effective = ratio > 0.5
        ? color
        : ratio > 0.25
            ? AppTheme.warning
            : AppTheme.danger;
    return Clay(
      color: AppTheme.surfaceHigh,
      radius: height,
      height: height,
      pressed: true,
      depth: 0.4,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          widthFactor: ratio,
          heightFactor: 1,
          child: Clay(color: effective, radius: height, depth: 0.25),
        ),
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFFFFF0D2),
      child: Row(
        children: <Widget>[
          const Icon(Icons.wifi_off_rounded, size: 16, color: AppTheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppTheme.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Artwork kartu: kreatur 3D prosedural di panggung clay; gambar CMS
/// menimpanya bila berhasil dimuat.
class CardArtwork extends StatelessWidget {
  const CardArtwork({
    super.key,
    required this.card,
    this.borderRadius = 14,
    this.animate = true,
    this.mirrored = false,
  });

  final CardModel card;
  final double borderRadius;
  final bool animate;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    final url = card.displayImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CreatureScene(card: card, animate: animate, mirrored: mirrored),
          if (url.startsWith('https://'))
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (context, url) => const SizedBox.shrink(),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

/// Kartu clay: badan pastel sesuai elemen, jendela artwork cekung, bola
/// biaya, badge elemen, pip rarity, dan pil statistik.
class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.card,
    this.quantity,
    this.onTap,
    this.showStats = true,
    this.obscured = false,
    this.animate = true,
  });

  final CardModel card;
  final int? quantity;
  final VoidCallback? onTap;
  final bool showStats;

  /// Kartu belum dimiliki: silhouette + nama disamarkan.
  final bool obscured;

  /// Animasi idle kreatur.
  final bool animate;

  static const List<double> _grayscale = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static double _statSize(double w) => (w * 0.075).clamp(7.0, 15.0);

  @override
  Widget build(BuildContext context) {
    final live = animate && !obscured;

    Widget tile = LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 120.0;
        final radius = (w * 0.13).clamp(10.0, 26.0);
        final pad = w * 0.06;
        final nameSize = (w * 0.09).clamp(8.0, 18.0);
        final depth = (w / 150).clamp(0.3, 1.0);
        final rarityColor = AppTheme.rarityColor(card.rarity);

        return Clay(
          color: AppTheme.elementPastel(card.element),
          radius: radius,
          depth: depth,
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned.fill(
                      child: Clay(
                        color: Clay.shadeOf(
                          AppTheme.elementPastel(card.element),
                          0.05,
                        ),
                        radius: radius * 0.7,
                        pressed: true,
                        depth: depth * 0.7,
                        child: CardArtwork(
                          card: card,
                          borderRadius: radius * 0.7,
                          animate: live,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -w * 0.02,
                      left: -w * 0.02,
                      child: _CostBall(cost: card.cost, size: w * 0.22),
                    ),
                    Positioned(
                      top: w * 0.02,
                      right: w * 0.02,
                      child: _ElementBadge(
                        element: card.element,
                        size: w * 0.17,
                      ),
                    ),
                    if (quantity != null && quantity! > 1)
                      Positioned(
                        bottom: w * 0.03,
                        right: w * 0.03,
                        child: ClayPill(
                          label: '×$quantity',
                          color: AppTheme.ink,
                          fontSize: (w * 0.075).clamp(7.0, 13.0),
                        ),
                      ),
                    if (obscured)
                      Center(
                        child: Icon(
                          Icons.lock_rounded,
                          size: w * 0.24,
                          color: AppTheme.inkSoft,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: w * 0.045),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      obscured ? '???' : card.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: nameSize,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  _RarityPips(
                    count: card.rarity.index + 1,
                    color: rarityColor,
                    size: w * 0.05,
                  ),
                ],
              ),
              if (showStats) ...<Widget>[
                SizedBox(height: w * 0.035),
                _statsRow(w),
              ],
            ],
          ),
        );
      },
    );

    if (obscured) {
      tile = Opacity(
        opacity: 0.55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(_grayscale),
          child: tile,
        ),
      );
    }

    return Semantics(
      button: onTap != null,
      label: obscured ? '???' : card.name,
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(aspectRatio: 2 / 3, child: tile),
      ),
    );
  }

  Widget _statsRow(double w) {
    final size = _statSize(w);
    if (!card.isUnit) {
      return Row(
        children: <Widget>[
          Flexible(
            child: ClayPill(
              label: card.ability?.type.toUpperCase() ?? 'SPELL',
              icon: Icons.auto_awesome_rounded,
              color: AppTheme.accent,
              fontSize: size,
            ),
          ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        Flexible(
          child: ClayPill(
            label: '${card.attack ?? 0}',
            icon: Icons.flash_on_rounded,
            color: AppTheme.attack,
            fontSize: size,
          ),
        ),
        SizedBox(width: w * 0.03),
        Flexible(
          child: ClayPill(
            label: '${card.hp ?? 0}',
            icon: Icons.favorite_rounded,
            color: AppTheme.success,
            fontSize: size,
          ),
        ),
      ],
    );
  }
}

class _CostBall extends StatelessWidget {
  const _CostBall({required this.cost, required this.size});

  final int cost;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Clay(
      width: size,
      height: size,
      shape: BoxShape.circle,
      color: AppTheme.primary,
      depth: (size / 30).clamp(0.3, 0.8),
      child: Center(
        child: Text(
          cost.toString(),
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ElementBadge extends StatelessWidget {
  const _ElementBadge({required this.element, required this.size});

  final CardElement element;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Clay(
      width: size,
      height: size,
      shape: BoxShape.circle,
      color: AppTheme.surface,
      depth: (size / 30).clamp(0.25, 0.6),
      child: Icon(
        AppTheme.elementIcon(element),
        size: size * 0.62,
        color: AppTheme.elementColor(element),
      ),
    );
  }
}

class _RarityPips extends StatelessWidget {
  const _RarityPips({
    required this.count,
    required this.color,
    required this.size,
  });

  final int count;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = math.max(3.0, size);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.only(left: dot * 0.25),
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}
