import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Solid Font Awesome glyph used across the product UI.
@immutable
final class AppIconPair {
  const AppIconPair(this.icon);

  /// Full plain / solid style.
  final FaIconData icon;
}

/// ReadBeat icon catalog — Font Awesome solid only (no Material Icons).
abstract final class AppIcons {
  static const home = AppIconPair(FontAwesomeIcons.solidHouse);
  static const library = AppIconPair(FontAwesomeIcons.bookOpen);
  static const import = AppIconPair(FontAwesomeIcons.solidSquarePlus);
  static const settings = AppIconPair(FontAwesomeIcons.gear);
  static const search = AppIconPair(FontAwesomeIcons.magnifyingGlass);
  static const favorite = AppIconPair(FontAwesomeIcons.solidHeart);
  static const delete = AppIconPair(FontAwesomeIcons.solidTrashCan);
  static const close = AppIconPair(FontAwesomeIcons.solidCircleXmark);
  static const check = AppIconPair(FontAwesomeIcons.solidCircleCheck);
  static const tick = AppIconPair(FontAwesomeIcons.check);
  static const error = AppIconPair(FontAwesomeIcons.circleExclamation);
  static const pause = AppIconPair(FontAwesomeIcons.solidCirclePause);
  static const play = AppIconPair(FontAwesomeIcons.solidCirclePlay);
  static const replay = AppIconPair(FontAwesomeIcons.rotateLeft);
  static const forward = AppIconPair(FontAwesomeIcons.forward);
  static const account = AppIconPair(FontAwesomeIcons.solidCircleUser);
  static const sun = AppIconPair(FontAwesomeIcons.solidSun);
  static const moon = AppIconPair(FontAwesomeIcons.solidMoon);
  static const themeAuto = AppIconPair(FontAwesomeIcons.circleHalfStroke);
  static const headphones = AppIconPair(FontAwesomeIcons.solidHeadphones);
  static const book = AppIconPair(FontAwesomeIcons.book);
  static const chevronRight = AppIconPair(FontAwesomeIcons.chevronRight);
  static const chevronUp = AppIconPair(FontAwesomeIcons.chevronUp);
  static const chevronDown = AppIconPair(FontAwesomeIcons.chevronDown);
  static const playlist = AppIconPair(FontAwesomeIcons.listOl);
  static const listView = AppIconPair(FontAwesomeIcons.listUl);
  static const gridView = AppIconPair(FontAwesomeIcons.tableCellsLarge);
  static const sync = AppIconPair(FontAwesomeIcons.arrowsRotate);
  static const storage = AppIconPair(FontAwesomeIcons.hardDrive);
  static const privacy = AppIconPair(FontAwesomeIcons.shieldHalved);
  static const bell = AppIconPair(FontAwesomeIcons.solidBell);
  static const offline = AppIconPair(FontAwesomeIcons.wifi);
  static const apple = AppIconPair(FontAwesomeIcons.apple);
}

/// Full plain solid Font Awesome icon (no dual-tone layers).
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.pair, {
    super.key,
    this.active = false,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final AppIconPair pair;

  /// Kept for call-site compatibility; glyph style is always solid.
  final bool active;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 22;
    final resolvedColor =
        color ?? iconTheme.color ?? DefaultTextStyle.of(context).style.color;

    return FaIcon(
      pair.icon,
      size: resolvedSize,
      color: resolvedColor,
      semanticLabel: semanticLabel,
    );
  }
}
