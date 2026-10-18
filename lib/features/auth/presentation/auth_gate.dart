import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../../notifications/push_navigation.dart';
import '../../notifications/push_service.dart';
import '../data/secure_store.dart';
import 'lock_screen.dart';

/// Sits above the whole router and decides, on launch and on return from
/// the background, whether a signed-in customer must unlock first.
///
///  - signed in and biometric unlock on → lock screen
///  - signed in and biometric unlock off → straight in (session is valid)
///  - signed out → the router's own sign-in flow
///
/// The app underneath stays mounted while locked, so unlocking after a
/// short absence returns to exactly where the customer was.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> with WidgetsBindingObserver {
  bool _locked = false;
  DateTime? _pausedAt;

  /// A tapped notification waiting for somewhere to open: the app may still be
  /// locked, signing in, or not yet showing a screen.
  PushTap? _pendingTap;
  StreamSubscription<PushTap>? _tapSub;
  Timer? _tapRetry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockIfNeeded();
    final push = ref.read(pushServiceProvider);
    _tapSub = push.taps.listen(_onTap);
    push.launchTap().then((tap) {
      if (tap != null && mounted) _onTap(tap);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapSub?.cancel();
    _tapRetry?.cancel();
    super.dispose();
  }

  void _onTap(PushTap tap) {
    _pendingTap = tap;
    _openPendingTap();
  }

  /// Opens the waiting notification once the app is unlocked and a screen is
  /// up, trying again for a few seconds while it starts or the person signs in.
  Future<void> _openPendingTap({int attempt = 0}) async {
    final tap = _pendingTap;
    if (tap == null || !mounted) return;
    _tapRetry?.cancel();
    if (!_locked && await openPushTap(ref, tap)) {
      if (_pendingTap == tap) _pendingTap = null;
      return;
    }
    if (attempt >= 20) {
      _pendingTap = null; // the person never got in; do not surprise them later
      return;
    }
    _tapRetry = Timer(const Duration(milliseconds: 500), () => _openPendingTap(attempt: attempt + 1));
  }

  Future<void> _lockIfNeeded() async {
    final user = await ref.read(authRepositoryProvider).authState().first;
    final enabled = await ref.read(secureStoreProvider).read(StoreKeys.biometricEnabled) == 'true';
    if (!mounted) return;
    // A person who was already signed in when the app opened gets their pushes too.
    if (user != null && user.onboarded) ref.read(pushServiceProvider).register(user.id);
    if (_locked) return;
    if (user != null && user.onboarded && enabled) setState(() => _locked = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (away >= ref.read(authConfigProvider).relockAfter) _lockIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppUser?>>(authStateProvider, (prev, next) {
      final user = next.value;
      if (user == null && _locked) setState(() => _locked = false);
      // Once someone has finished signing in, this phone can receive their pushes.
      if (user != null && user.onboarded) ref.read(pushServiceProvider).register(user.id);
    });
    return Stack(
      children: [
        Visibility(visible: !_locked, maintainState: true, child: widget.child),
        if (_locked)
          Positioned.fill(
            child: LockScreen(
              onUnlocked: () => setState(() => _locked = false),
              onSignedOut: () => setState(() => _locked = false),
            ),
          ),
      ],
    );
  }
}
