import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';

/// Жылдызча оценка виджети — басуу менен тандоо
class StarRatingWidget extends StatefulWidget {
  final int initialRating;
  final double size;
  final bool interactive;
  final Function(int)? onRatingChanged;

  const StarRatingWidget({
    super.key,
    this.initialRating = 0,
    this.size = 32,
    this.interactive = true,
    this.onRatingChanged,
  });

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  late int _current;
  int _hovered = 0;

  @override
  void initState() {
    super.initState();
    _current = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = star <= (_hovered > 0 ? _hovered : _current);
        return GestureDetector(
          onTap: widget.interactive
              ? () {
                  setState(() => _current = star);
                  widget.onRatingChanged?.call(star);
                }
              : null,
          child: MouseRegion(
            onEnter: widget.interactive ? (_) => setState(() => _hovered = star) : null,
            onExit: widget.interactive ? (_) => setState(() => _hovered = 0) : null,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                key: ValueKey('$star-$filled'),
                color: filled ? Colors.amber : AppColors.grey300,
                size: widget.size,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Окуу гана — оценка көрсөтүү (жарым жылдыз менен)
class StarDisplayWidget extends StatelessWidget {
  final double rating;
  final double size;
  final int reviewCount;

  const StarDisplayWidget({
    super.key,
    required this.rating,
    this.size = 18,
    this.reviewCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final star = i + 1;
          if (rating >= star) {
            return Icon(Icons.star_rounded, color: Colors.amber, size: size);
          } else if (rating >= star - 0.5) {
            return Icon(Icons.star_half_rounded, color: Colors.amber, size: size);
          } else {
            return Icon(Icons.star_outline_rounded, color: AppColors.grey300, size: size);
          }
        }),
        const SizedBox(width: 6),
        Text(
          rating > 0 ? '${rating.toStringAsFixed(1)} ($reviewCount)' : 'Оценка жок',
          style: TextStyle(
            fontSize: size * 0.75,
            color: AppColors.grey500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
