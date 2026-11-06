import '../data/kit_state.dart';

/// The soft-paywall rule, in code (ADR 0001, section 4): no paywall before
/// onboarding is complete and the app has reported its first useful moment,
/// so a hard paywall on day one can't be built by mistake. Both steps are
/// saved in the kit state document.
class PaywallGate {
  PaywallGate(this._kitState);

  final KitStateController _kitState;

  static final _placement = RegExp(r'^[a-z0-9_]+$');

  /// Whether a paywall may show at [placement], the detail of its
  /// `paywall.view.<placement>` event.
  bool canShow(String placement) {
    if (!_placement.hasMatch(placement)) throw ArgumentError.value(placement, 'placement', 'not an analytics detail');
    final state = _kitState.state;
    return state != null && state.onboardingCompleted && state.firstValueReached;
  }

  /// The app calls this when the user has done its first useful thing (a
  /// first entry saved, a first result shown). Saved once.
  Future<void> markFirstValue() async {
    if (_kitState.state?.firstValueReached ?? true) return;
    await _kitState.update((s) => s.copyWith(firstValueReached: true));
  }
}
