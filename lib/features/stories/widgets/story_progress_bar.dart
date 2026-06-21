import 'package:flutter/material.dart';

/// Story viewer'дин жогору жагындагы прогресс тилкелери.
/// Ар бир story үчүн бир тилке — активдүүсү анимация менен толот.
class StoryProgressBar extends StatelessWidget {
  final int count;        // жалпы stories саны
  final int currentIndex; // учурдагы story индекси
  final Animation<double> progress; // 0.0 → 1.0 анимация

  const StoryProgressBar({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < count - 1 ? 4 : 0),
            child: _SingleBar(
              state: i < currentIndex
                  ? _BarState.done
                  : i == currentIndex
                      ? _BarState.active
                      : _BarState.pending,
              progress: i == currentIndex ? progress : null,
            ),
          ),
        );
      }),
    );
  }
}

enum _BarState { done, active, pending }

class _SingleBar extends StatelessWidget {
  final _BarState state;
  final Animation<double>? progress;

  const _SingleBar({required this.state, this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: state == _BarState.active && progress != null
            ? AnimatedBuilder(
                animation: progress!,
                builder: (_, __) => LinearProgressIndicator(
                  value: progress!.value,
                  backgroundColor: Colors.white.withValues(alpha: 0.4),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : LinearProgressIndicator(
                value: state == _BarState.done ? 1.0 : 0.0,
                backgroundColor: Colors.white.withValues(alpha: 0.4),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
      ),
    );
  }
}
