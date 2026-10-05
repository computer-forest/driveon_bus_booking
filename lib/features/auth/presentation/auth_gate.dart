import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _lockIfNeeded() async {
    final user = await ref.read(authRepositoryProvider).authState().first;
    final enabled = await ref.read(secureStoreProvider).read(StoreKeys.biometricEnabled) == 'true';
    if (!mounted || _locked) return;
    if (user != null && !user.isAdmin && user.onboarded && enabled) setState(() => _locked = true);
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
    ref.listen<AsyncValue<AppUser?>>(authStateProvider, (_, next) {
      if (next.value == null && _locked) setState(() => _locked = false);
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
