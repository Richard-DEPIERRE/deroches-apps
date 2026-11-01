import 'package:flutter/material.dart';

import '../../l10n/kit_localizations.dart';
import '../../l10n/kit_localizations_en.dart';

/// Shown in release builds in place of a part of the app that failed to draw.
///
/// A full page when there is room, one line (icon and title) in a small space
/// such as a list row.
class KitErrorView extends StatelessWidget {
  const KitErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    // English when the failure happened above the app's localizations.
    final l10n = Localizations.of<KitLocalizations>(context, KitLocalizations) ?? KitLocalizationsEn();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Material(
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxHeight < 240 || box.maxWidth < 280) {
            return Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 20, color: muted),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.kitErrorTitle,
                      style: theme.textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: muted),
                      const SizedBox(height: 16),
                      Text(
                        l10n.kitErrorTitle,
                        style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.kitErrorBody,
                        style: theme.textTheme.bodyLarge?.copyWith(color: muted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
