import 'dart:async';
import 'package:flutter/material.dart';
import 'supabase_client.dart';

/// Колдонуучу тиркемени активдүү колдонуп жатканда
/// `profiles.last_active_at` талаасын мезгил-мезгили менен жаныртат.
///
/// Бул "онлайн" статусун болжолдоо үчүн колдонулат: эгер
/// `last_active_at` соңку 5 мүнөттө жаныртылган болсо, колдонуучу
/// "онлайн" деп эсептелет.
///
/// `main()` ичинде, MaterialApp'тын үстүнө орнотулушу керек:
/// ```dart
/// runApp(ActiveStatusTracker(child: MyApp()));
/// ```
class ActiveStatusTracker extends StatefulWidget {
  final Widget child;

  const ActiveStatusTracker({super.key, required this.child});

  @override
  State<ActiveStatusTracker> createState() => _ActiveStatusTrackerState();
}

class _ActiveStatusTrackerState extends State<ActiveStatusTracker>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ping();
    // Ар 2 мүнөттө бир жаныртат (app ачык турганда).
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _ping());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ping();
    }
  }

  Future<void> _ping() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase.from('profiles').update({
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
    } catch (_) {
      // Тиркеме иштешине тоскоолдук кылбасын — катаны жутуп коёбуз.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
