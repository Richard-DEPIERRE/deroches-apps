import 'package:flutter/material.dart';

import '../../l10n/kit_localizations.dart';
import '../analytics/analytics.dart';
import '../data/kit_state.dart';

/// One onboarding page, in the user's language, from the app.
class OnboardingPage {
  const OnboardingPage({required this.title, required this.body, required this.illustration});

  final String title;
  final String body;
  final Widget illustration;
}

/// The first launch (ADR 0001, section 10): shows [pages] until the user
/// skips or finishes them, then [child], for good. Completion is saved in the
/// kit state. Back goes to the previous page, and leaves the app from the
/// first. Never put a paywall in it.
class OnboardingFlow extends StatelessWidget {
  OnboardingFlow({
    super.key,
    required this.kitState,
    required this.analytics,
    required this.pages,
    required this.child,
  }) {
    if (pages.length < 2 || pages.length > 4) throw ArgumentError('onboarding takes 2 to 4 pages, not ${pages.length}');
  }

  final KitStateController kitState;
  final Analytics analytics;
  final List<OnboardingPage> pages;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: kitState,
    builder: (context, _) => switch (kitState) {
      KitStateController(loading: true) => const Scaffold(),
      // A kit state that failed to open never keeps the user out of the app.
      KitStateController(state: KitState(onboardingCompleted: false)) => _Pages(
        pages: pages,
        onDone: (skipped) {
          analytics.track(skipped ? 'onboarding.dismiss.skipped' : 'onboarding.complete.finished');
          kitState.update((s) => s.copyWith(onboardingCompleted: true));
        },
      ),
      _ => child,
    },
  );
}

class _Pages extends StatefulWidget {
  const _Pages({required this.pages, required this.onDone});

  final List<OnboardingPage> pages;
  final void Function(bool skipped) onDone;

  @override
  State<_Pages> createState() => _PagesState();
}

class _PagesState extends State<_Pages> {
  final _controller = PageController();
  int _page = 0;

  bool get _last => _page == widget.pages.length - 1;

  void _go(int page) => MediaQuery.disableAnimationsOf(context)
      ? _controller.jumpToPage(page)
      : _controller.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = KitLocalizations.of(context);
    final theme = Theme.of(context);
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_page - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(top: 8, end: 8),
                      child: Visibility(
                        visible: !_last,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: TextButton(onPressed: () => widget.onDone(true), child: Text(l10n.kitOnboardingSkip)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (page) => setState(() => _page = page),
                      children: [
                        for (final page in widget.pages)
                          LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 200,
                                      child: Center(child: ExcludeSemantics(child: page.illustration)),
                                    ),
                                    const SizedBox(height: 24),
                                    Semantics(
                                      header: true,
                                      child: Text(
                                        page.title,
                                        style: theme.textTheme.headlineSmall,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(page.body, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: l10n.kitOnboardingPage(_page + 1, widget.pages.length),
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < widget.pages.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              width: i == _page ? 24 : 8,
                              height: 8,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: i == _page ? theme.colorScheme.primary : theme.colorScheme.outline,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: _last ? () => widget.onDone(false) : () => _go(_page + 1),
                      child: Text(_last ? l10n.kitOnboardingDone : l10n.kitOnboardingNext),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
