import 'package:flutter/material.dart';

/// Hosts a flow in its own [Navigator], so the screens inside it can keep
/// pushing, replacing and popping routes freely while the app-level router
/// only decides which flow is on screen.
///
/// System back pops the inner navigator first and falls through to the
/// outer one (usually leaving the app) once the inner one is at its root.
class NestedNavigatorShell extends StatefulWidget {
  const NestedNavigatorShell({super.key, required this.home});

  final Widget home;

  static GlobalKey<NavigatorState>? _active;

  /// The navigator of the flow on screen right now, or null between flows.
  /// Lets something outside the widget tree (a tapped notification) open a
  /// screen inside the current flow.
  static NavigatorState? get activeNavigator => _active?.currentState;

  @override
  State<NestedNavigatorShell> createState() => _NestedNavigatorShellState();
}

class _NestedNavigatorShellState extends State<NestedNavigatorShell> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    NestedNavigatorShell._active = _navigatorKey;
  }

  @override
  void dispose() {
    if (NestedNavigatorShell._active == _navigatorKey) NestedNavigatorShell._active = null;
    super.dispose();
  }

  late final _observer = _StackObserver(_syncCanPop);
  bool _canPop = false;

  void _syncCanPop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final can = _navigatorKey.currentState?.canPop() ?? false;
      if (can != _canPop) setState(() => _canPop = can);
    });
  }

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      enabled: _canPop,
      onPopWithResult: (result) => _navigatorKey.currentState?.maybePop(result),
      child: Navigator(
        key: _navigatorKey,
        observers: [_observer],
        onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => widget.home),
      ),
    );
  }
}

class _StackObserver extends NavigatorObserver {
  _StackObserver(this._onChanged);

  final VoidCallback _onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _onChanged();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _onChanged();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _onChanged();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _onChanged();
}
