import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════
// IosStyleButton — iOS нативдик стил
// Таза ак фон + жумшак shadow + тегерек бурчтар
// Blur/айнек жок — ак карточка стили
//
// Колдонуу:
//   IosStyleButton(onTap: () {}, child: Icon(Icons.tune))
//   IosStyleButton.circle(onTap: () {}, child: Icon(Icons.arrow_back))
//   IosStyleButton.label(onTap: () {}, icon: Icons.refresh, label: 'Жаңылоо')
//   IosStyleButton.primary(onTap: () {}, label: 'Сакта')
// ══════════════════════════════════════════════════════════════════

class IosStyleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool active;
  final Color? activeColor;
  final EdgeInsets padding;
  final double radius;

  const IosStyleButton({
    super.key,
    required this.child,
    this.onTap,
    this.active = false,
    this.activeColor,
    this.padding = const EdgeInsets.all(13),
    this.radius = 14,
  });

  // ── Тегерек (Back, Fav, Share) ──
  factory IosStyleButton.circle({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    bool active = false,
    Color? activeColor,
    double size = 38,
  }) => _IosCircleButton(
        key: key,
        onTap: onTap,
        active: active,
        activeColor: activeColor,
        size: size,
        child: child,
      );

  // ── Иконка + текст (Жаңылоо, Өтүнүч) ──
  factory IosStyleButton.label({
    Key? key,
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    Color color = const Color(0xFFD97706),
    bool active = false,
  }) => _IosLabelButton(
        key: key,
        label: label,
        icon: icon,
        color: color,
        onTap: onTap,
        active: active,
      );

  // ── Толук туурасы (Login, Save, Checkout) ──
  factory IosStyleButton.primary({
    Key? key,
    required String label,
    required VoidCallback? onTap,
    bool loading = false,
    double height = 52,
    Color color = const Color(0xFFD97706),
  }) => _IosPrimaryButton(
        key: key,
        label: label,
        onTap: onTap,
        loading: loading,
        height: height,
        color: color,
      );

  @override
  State<IosStyleButton> createState() => _IosStyleButtonState();
}

class _IosStyleButtonState extends State<IosStyleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.activeColor ?? const Color(0xFFD97706);

    final bg = widget.active
        ? color
        : (isDark ? const Color(0xFF2A2A2A) : Colors.white);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                  ]
                : isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: -2,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Тегерек баскыч ──
class _IosCircleButton extends IosStyleButton {
  final double size;

  const _IosCircleButton({
    super.key,
    required super.child,
    super.onTap,
    super.active,
    super.activeColor,
    required this.size,
  }) : super(padding: EdgeInsets.zero, radius: 999);

  @override
  State<IosStyleButton> createState() => _IosCircleButtonState();
}

class _IosCircleButtonState extends _IosStyleButtonState {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.activeColor ?? const Color(0xFFD97706);
    final size = (widget as _IosCircleButton).size;

    final bg = widget.active
        ? color
        : (isDark ? const Color(0xFF2A2A2A) : Colors.white);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

// ── Label баскыч ──
class _IosLabelButton extends IosStyleButton {
  final String label;
  final IconData icon;
  final Color color;

  const _IosLabelButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    super.onTap,
    super.active,
  }) : super(
          child: const SizedBox.shrink(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          radius: 20,
        );

  @override
  State<IosStyleButton> createState() => _IosLabelButtonState();
}

class _IosLabelButtonState extends _IosStyleButtonState {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btn = widget as _IosLabelButton;
    final bg = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(btn.icon, color: btn.color, size: 14),
              const SizedBox(width: 5),
              Text(
                btn.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: btn.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Primary толук баскыч ──
class _IosPrimaryButton extends IosStyleButton {
  final String label;
  final bool loading;
  final double height;
  final Color color;

  const _IosPrimaryButton({
    super.key,
    required this.label,
    super.onTap,
    required this.loading,
    required this.height,
    required this.color,
  }) : super(child: const SizedBox.shrink(), padding: EdgeInsets.zero, radius: 14);

  @override
  State<IosStyleButton> createState() => _IosPrimaryButtonState();
}

class _IosPrimaryButtonState extends _IosStyleButtonState {
  @override
  Widget build(BuildContext context) {
    final btn = widget as _IosPrimaryButton;
    final enabled = widget.onTap != null && !btn.loading;

    return GestureDetector(
      onTap: enabled ? widget.onTap : null,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: btn.height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: enabled ? btn.color : Colors.grey[300],
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: btn.color.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                      spreadRadius: -3,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: btn.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    btn.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
