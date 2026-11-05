import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Blok claymorphism: warna solid, sudut bulat besar, bayangan luar lembut,
/// dan dua inner shadow (sorot terang kiri-atas, bayangan gelap kanan-bawah)
/// yang membuat permukaan terlihat seperti tanah liat mengembung.
///
/// Tanpa gradien — volume murni dari bayangan.
class Clay extends StatelessWidget {
  const Clay({
    super.key,
    this.child,
    this.color = AppTheme.surface,
    this.radius = 24,
    this.depth = 1,
    this.pressed = false,
    this.padding,
    this.width,
    this.height,
    this.shape = BoxShape.rectangle,
    this.alignment,
    this.onTap,
  });

  final Widget? child;
  final Color color;
  final double radius;

  /// Skala ketebalan clay (0 = datar).
  final double depth;

  /// Tampilan ditekan/cekung (mis. tab terpilih, slot kosong).
  final bool pressed;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BoxShape shape;
  final AlignmentGeometry? alignment;
  final VoidCallback? onTap;

  static Color shadeOf(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + amount * 0.3).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final isCircle = shape == BoxShape.circle;
    final borderRadius = isCircle ? null : BorderRadius.circular(radius);
    final shadow = shadeOf(color, 0.32);

    Widget body = Container(
      width: width,
      height: height,
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius: borderRadius,
        boxShadow: pressed || depth == 0
            ? const <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(
                  color: shadow.withValues(alpha: 0.38),
                  offset: Offset(6 * depth, 10 * depth),
                  blurRadius: 22 * depth,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.7),
                  offset: Offset(-4 * depth, -4 * depth),
                  blurRadius: 12 * depth,
                ),
              ],
      ),
      foregroundDecoration: _ClayInset(
        radius: isCircle ? null : radius,
        color: color,
        depth: depth,
        pressed: pressed,
      ),
      child: child,
    );

    if (onTap != null) {
      body = _Squish(onTap: onTap!, child: body);
    }
    return body;
  }
}

/// Efek tekan: clay sedikit mengecil saat disentuh.
class _Squish extends StatefulWidget {
  const _Squish({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Squish> createState() => _SquishState();
}

class _SquishState extends State<_Squish> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Inner shadow digambar sebagai foreground decoration.
class _ClayInset extends Decoration {
  const _ClayInset({
    required this.radius,
    required this.color,
    required this.depth,
    required this.pressed,
  });

  final double? radius;
  final Color color;
  final double depth;
  final bool pressed;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _ClayInsetPainter(this);
}

class _ClayInsetPainter extends BoxPainter {
  _ClayInsetPainter(this.decoration);

  final _ClayInset decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty || decoration.depth == 0) return;
    // Elemen kecil (pil, lencana): inner shadow ber-blur hampir tak terlihat
    // tapi mahal; cukup satu garis sorot tipis tanpa blur.
    if (size.shortestSide < 34) {
      final r = offset & size;
      final radius = decoration.radius ?? size.shortestSide / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(1), Radius.circular(radius)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color =
              Colors.white.withValues(alpha: decoration.pressed ? 0.25 : 0.4),
      );
      return;
    }
    final rect = offset & size;
    final radius = decoration.radius ?? size.shortestSide / 2;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final d = decoration.depth;
    final dark = Clay.shadeOf(decoration.color, 0.22);

    if (decoration.pressed) {
      _inset(canvas, rrect, Offset(5 * d, 6 * d), 8 * d,
          dark.withValues(alpha: 0.55));
      _inset(canvas, rrect, Offset(-3 * d, -3 * d), 6 * d,
          Colors.white.withValues(alpha: 0.6));
      return;
    }
    // Sorot terang di tepi kiri-atas.
    _inset(canvas, rrect, Offset(4 * d, 5 * d), 7 * d,
        Colors.white.withValues(alpha: 0.75));
    // Bayangan lembut di tepi kanan-bawah.
    _inset(canvas, rrect, Offset(-5 * d, -7 * d), 10 * d,
        dark.withValues(alpha: 0.35));
  }

  void _inset(
      Canvas canvas, RRect rrect, Offset shift, double blur, Color color) {
    final outer = rrect.outerRect.inflate(blur * 3 + shift.distance);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(outer)
      ..addRRect(rrect.shift(shift));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
    canvas.restore();
  }
}

/// Tombol clay dengan label + ikon opsional.
class ClayButton extends StatelessWidget {
  const ClayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppTheme.primary,
    this.foreground = Colors.white,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color foreground;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Clay(
          color: color,
          radius: 999,
          depth: enabled ? 0.8 : 0.3,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          onTap: onPressed,
          child: row,
        ),
      ),
    );
  }
}
