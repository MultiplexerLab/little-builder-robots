import 'package:flutter/material.dart';
import 'package:little_builder_robots/app/theme.dart';
import 'package:little_builder_robots/core/utils/touch_guard.dart';

enum ChunkyButtonStyle { primary, secondary }

/// The child-facing button (DES-04, DES-05, DES-07).
///
/// Primary: Sunny fill, thick Navy outline and a 6 pt drop shadow; only one
/// per screen. Secondary: white fill, Navy outline, no shadow. When pressed,
/// the shadow drops and the button moves down 6 pt over 100 ms.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = ChunkyButtonStyle.secondary,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ChunkyButtonStyle style;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _pressed = false;

  bool get _isPrimary => widget.style == ChunkyButtonStyle.primary;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final shadow = _isPrimary && !_pressed ? AppSizes.shadow : 0.0;
    final offset = _isPrimary && _pressed ? AppSizes.shadow : 0.0;
    final minHeight = _isPrimary ? AppSizes.childPrimary : AppSizes.childTarget;

    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: widget.onPressed == null
            ? null
            : () {
                // NFR-19: no palm presses, no repeat taps within 400 ms.
                if (TouchGuard.instance.allowNavigation()) widget.onPressed!();
              },
        child: Padding(
          padding: EdgeInsets.only(bottom: _isPrimary ? AppSizes.shadow : 0),
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : AppSizes.pressDuration,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, offset, 0),
            constraints: BoxConstraints(
              minHeight: minHeight,
              minWidth: minHeight,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: _isPrimary ? AppColors.sunny : AppColors.white,
              borderRadius: BorderRadius.circular(minHeight / 2),
              border: Border.all(
                color: AppColors.navy,
                width: _isPrimary ? AppSizes.outlineThick : AppSizes.outline,
              ),
              boxShadow: [
                if (shadow > 0)
                  BoxShadow(
                    color: AppColors.navy,
                    offset: Offset(0, shadow),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: AppColors.navy, size: 32),
                  const SizedBox(width: 12),
                ],
                // Large text sizes shrink to fit rather than overflow.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(widget.label, style: AppText.button),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
