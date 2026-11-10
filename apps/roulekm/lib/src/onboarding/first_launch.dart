import 'package:app_kit/app_kit.dart';
import 'package:flutter/material.dart';

import '../../l10n/roulekm_localizations.dart';
import '../data/log_controller.dart';
import '../rates/rates.dart';
import '../vehicles/vehicle_screen.dart';

/// The first launch (DAPP-141 §6): the kit's three onboarding pages, then the first-vehicle step, then [home].
/// The step follows the pages in the same launch only, so "Later" needs nothing saved: on a later launch, [home]
/// asks for the vehicle itself.
class FirstLaunch extends StatefulWidget {
  const FirstLaunch({
    super.key,
    required this.kitState,
    required this.analytics,
    required this.log,
    required this.home,
  });

  final KitStateController kitState;
  final Analytics analytics;
  final LogController log;
  final Widget home;

  @override
  State<FirstLaunch> createState() => _FirstLaunchState();
}

class _FirstLaunchState extends State<FirstLaunch> {
  /// Whether this launch shows the pages, known once the kit state is read.
  bool? _onboarding;
  bool _vehicleDone = false;

  @override
  Widget build(BuildContext context) {
    final l10n = RoulekmLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.kitState,
      builder: (context, _) {
        if (!widget.kitState.loading) _onboarding ??= widget.kitState.state?.onboardingCompleted == false;
        return OnboardingFlow(
          kitState: widget.kitState,
          analytics: widget.analytics,
          doneLabel: l10n.onboardingDone,
          pages: [
            OnboardingPage(
              title: l10n.onboardingTitle1,
              body: l10n.onboardingBody1,
              illustration: _Illustration(Icons.route_outlined, switch (regionRates()) {
                RateSystem.france => Icons.euro,
                RateSystem.uk => Icons.currency_pound,
                RateSystem.us => Icons.attach_money,
              }),
            ),
            OnboardingPage(
              title: l10n.onboardingTitle2,
              body: l10n.onboardingBody2,
              illustration: const _Illustration(Icons.smartphone_outlined, Icons.location_off_outlined),
            ),
            OnboardingPage(
              title: l10n.onboardingTitle3,
              body: l10n.onboardingBody3,
              illustration: const _Illustration(Icons.all_inclusive, Icons.check),
            ),
          ],
          child: _onboarding == true && !_vehicleDone
              ? VehicleScreen(log: widget.log, firstVehicleDone: () => setState(() => _vehicleDone = true))
              : widget.home,
        );
      },
    );
  }
}

/// A page's picture, drawn so it follows light and dark: an icon on a rounded square, and a badge on a disc.
class _Illustration extends StatelessWidget {
  const _Illustration(this.icon, this.badge);

  final IconData icon;
  final IconData badge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 168,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(44)),
              child: Icon(icon, size: 92, color: colors.onPrimaryContainer),
            ),
          ),
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 5),
              ),
              child: Icon(badge, size: 30, color: colors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
