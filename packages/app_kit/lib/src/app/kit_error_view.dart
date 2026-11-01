import 'package:flutter/material.dart';

import '../../l10n/kit_localizations.dart';

/// Shown in release builds in place of a part of the app that failed to draw.
class KitErrorView extends StatelessWidget {
  const KitErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = KitLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.kitErrorTitle, style: text.titleLarge),
              const SizedBox(height: 12),
              Text(l10n.kitErrorBody, style: text.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
