import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.background,
            scheme.surfaceVariant.withOpacity(0.35),
          ],
        ),
      ),
      child: Stack(
        children: [
          const _SoftGlow(
            alignment: Alignment(-0.8, -0.9),
            size: 240,
            color: Color(0x33F2C14E),
          ),
          const _SoftGlow(
            alignment: Alignment(0.9, -0.5),
            size: 180,
            color: Color(0x26E07A5F),
          ),
          const _SoftGlow(
            alignment: Alignment(0.6, 0.9),
            size: 220,
            color: Color(0x261B6A67),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _SoftGlow extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final Color color;

  const _SoftGlow({
    required this.alignment,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 80,
                spreadRadius: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
