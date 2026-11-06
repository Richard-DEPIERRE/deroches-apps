import 'package:flutter/widgets.dart';

import '../config/app_config.dart';
import '../crash/crash_reporter.dart';

/// Hands the kit's services to widgets (ADR 0001, section 3).
class KitScope extends InheritedWidget {
  const KitScope({super.key, required this.config, required this.crashReporter, required super.child});

  final AppConfig config;
  final CrashReporter crashReporter;

  static KitScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<KitScope>();
    assert(scope != null, 'No KitScope above this widget: build the app with KitApp.');
    return scope!;
  }

  @override
  bool updateShouldNotify(KitScope oldWidget) => config != oldWidget.config || crashReporter != oldWidget.crashReporter;
}
