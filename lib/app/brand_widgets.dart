import 'package:flutter/material.dart';
import 'package:read_beat/app/icons.dart';
import 'package:read_beat/app/theme.dart';
import 'package:read_beat/core/extensions/extensions.dart';

/// Soft atmosphere behind a screen (cool white light / ocean→forest dark).
class DeskAtmosphere extends StatelessWidget {
  const DeskAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brand = context.brandColors;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: brand.atmosphere),
      child: child,
    );
  }
}

/// Floating glass pill shell for the bottom nav (full rounded).
class FloatingDeskNavShell extends StatelessWidget {
  const FloatingDeskNavShell({super.key, required this.child});

  final Widget child;

  static const double radius = 999;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(borderRadius: radius, child: child);
  }
}

/// Icon-only desk nav with a sliding brand-gradient indicator.
class DeskIconNav extends StatelessWidget {
  const DeskIconNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.height = 56,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final double height;

  static const _items = <({AppIconPair icon, String label})>[
    (icon: AppIcons.home, label: 'Home'),
    (icon: AppIcons.library, label: 'Library'),
    (icon: AppIcons.import, label: 'Import'),
    (icon: AppIcons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final brand = context.brandColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = constraints.maxWidth / _items.length;
            final indicatorWidth = slot * 0.72;
            final left = (slot * selectedIndex) + (slot - indicatorWidth) / 2;

            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                AnimatedPositioned(
                  duration: Duration(milliseconds: reduceMotion ? 0 : 280),
                  curve: Curves.easeOutCubic,
                  left: left,
                  width: indicatorWidth,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: brand.brandFill,
                      boxShadow: [
                        BoxShadow(
                          color: brand.primary.withOpacityValue(0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(
                        child: _DeskNavIcon(
                          tooltip: _items[i].label,
                          selected: i == selectedIndex,
                          icon: _items[i].icon,
                          onTap: () => onDestinationSelected(i),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DeskNavIcon extends StatelessWidget {
  const _DeskNavIcon({
    required this.tooltip,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final bool selected;
  final AppIconPair icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final idle = context.colorScheme.onSurface.withOpacityValue(0.62);
    final active = context.colorScheme.onPrimary;

    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.expand(
            child: Center(
              child: AppIcon(
                icon,
                active: selected,
                size: selected ? 22 : 20,
                color: selected ? active : idle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill search field: hint + optically centered magnifier (no floating label).
abstract final class DeskSearchDecoration {
  static const double _slot = 40;

  static InputDecoration of({required String hintText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: SizedBox(
        width: _slot,
        height: _slot,
        child: Center(
          // FA magnifier optical center sits slightly low in the glyph box.
          child: Transform.translate(
            offset: Offset(0, -1),
            child: AppIcon(AppIcons.search, size: 16),
          ),
        ),
      ),
      prefixIconConstraints: const BoxConstraints.tightFor(
        width: _slot,
        height: _slot,
      ),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints.tightFor(
        width: _slot,
        height: _slot,
      ),
    );
  }

  static Widget clearButton({required VoidCallback onPressed}) {
    return IconButton(
      tooltip: 'Clear',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: _slot, height: _slot),
      icon: const AppIcon(AppIcons.close, size: 14),
    );
  }
}

/// Primary CTA with brand fill gradient (pill, compact).
class BrandGradientButton extends StatelessWidget {
  const BrandGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget child;

  static const double _height = 36;
  static const double _radius = 999;

  @override
  Widget build(BuildContext context) {
    final brand = context.brandColors;
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        gradient: enabled ? brand.brandFill : null,
        color: enabled
            ? null
            : context.colorScheme.outline.withOpacityValue(0.35),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: brand.primary.withOpacityValue(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(_radius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: _height,
              maxHeight: _height,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: DefaultTextStyle.merge(
                  style: context.textTheme.labelLarge?.copyWith(
                    color: context.colorScheme.onPrimary,
                    fontSize: 13,
                  ),
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: context.colorScheme.onPrimary,
                      size: 18,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical Resume Pulse strip (forest → bright → orange tip).
class PulseEdgeBar extends StatelessWidget {
  const PulseEdgeBar({super.key, this.width = 4});

  final double width;

  @override
  Widget build(BuildContext context) {
    final brand = context.brandColors;
    return Container(
      width: width,
      decoration: BoxDecoration(gradient: brand.pulseEdge),
    );
  }
}

/// Thin progress trail with brand gradient.
class BeatProgressBar extends StatelessWidget {
  const BeatProgressBar({super.key, required this.value, this.minHeight = 3});

  final double value;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final brand = context.brandColors;
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: minHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: context.colorScheme.secondary.withOpacityValue(0.7),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: brand.progressTrail),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
