import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/design_tokens.dart';
import '../widgets.dart';

/// One destination of the bottom navigation.
final class ShellDestination {
  const ShellDestination({
    required this.icon,
    required this.label,
    required this.builder,
    this.showFab = false,
  });

  final IconData icon;
  final String label;
  final WidgetBuilder builder;
  final bool showFab;
}

/// One action of the FAB menu.
final class FabAction {
  const FabAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onSelected;
}

/// v1 shell: 5-item bottom navigation (58px) and the primary FAB with its
/// menu (Añadir manual · Escanear recibo · Preguntar al Coach).
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.destinations,
    required this.fabActions,
    this.controller,
  });

  final List<ShellDestination> destinations;
  final List<FabAction> Function(ShellController controller) fabActions;
  final ShellController? controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

/// Lets FAB actions and screens switch tabs, and screens hide the FAB (the
/// category detail of Estad. has none).
class ShellController extends ChangeNotifier {
  int _index = 0;
  final _fabHiddenTabs = <int>{};

  int get index => _index;
  bool get fabHidden => _fabHiddenTabs.contains(_index);

  void select(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }

  /// Hides the FAB on the current tab only.
  void setFabHidden(bool hidden) {
    final changed = hidden
        ? _fabHiddenTabs.add(_index)
        : _fabHiddenTabs.remove(_index);
    if (changed) notifyListeners();
  }
}

class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.controller, required super.child});

  final ShellController controller;

  static ShellController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>()?.controller;

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      controller != oldWidget.controller;
}

class _AppShellState extends State<AppShell> {
  late final ShellController _controller =
      widget.controller ?? ShellController();
  final _visited = <int>{0};
  bool _fabOpen = false;

  static const navHeight = 58.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTabChanged);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onTabChanged() => setState(() {
    _visited.add(_controller.index);
    _fabOpen = false;
  });

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final index = _controller.index;
    final showFab =
        widget.destinations[index].showFab && !_controller.fabHidden;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: DesignColors.surfaceCard,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: DesignColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: DesignColors.background,
        body: Stack(
          children: [
            Column(
              children: [
                Container(height: insets.top, color: DesignColors.surfaceCard),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    removeBottom: true,
                    child: ShellScope(
                      controller: _controller,
                      child: IndexedStack(
                        index: index,
                        children: [
                          for (final (i, d) in widget.destinations.indexed)
                            _visited.contains(i)
                                ? Builder(builder: d.builder)
                                : const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ),
                ),
                _BottomNavigation(
                  destinations: widget.destinations,
                  selected: index,
                  onSelected: _controller.select,
                ),
                Container(
                  height: insets.bottom,
                  color: DesignColors.background,
                ),
              ],
            ),
            if (_fabOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _fabOpen = false),
                  child: ColoredBox(
                    color: DesignColors.scrim,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        0,
                        24,
                        insets.bottom + navHeight + 80,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final (i, action)
                              in widget.fabActions(_controller).indexed) ...[
                            if (i > 0) const SizedBox(height: 14),
                            _FabMenuItem(
                              action: action,
                              onTap: () {
                                setState(() => _fabOpen = false);
                                action.onSelected();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (showFab)
              Positioned(
                right: 20,
                bottom: insets.bottom + navHeight + 8,
                child: _Fab(
                  open: _fabOpen,
                  onTap: () => setState(() => _fabOpen = !_fabOpen),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.destinations,
    required this.selected,
    required this.onSelected,
  });

  final List<ShellDestination> destinations;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: _AppShellState.navHeight,
    decoration: const BoxDecoration(
      color: DesignColors.surfaceCard,
      border: Border(top: BorderSide(color: DesignColors.border)),
    ),
    child: Row(
      children: [
        for (final (i, d) in destinations.indexed)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == selected,
              label: d.label,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Sym(
                      d.icon,
                      size: 24,
                      color: i == selected
                          ? DesignColors.primary
                          : DesignColors.textTertiary,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      d.label,
                      style: DesignText.micro.copyWith(
                        color: i == selected
                            ? DesignColors.primary
                            : DesignColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Fab extends StatelessWidget {
  const _Fab({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: open ? 'Cerrar menú' : 'Añadir',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: DesignColors.primary,
          shape: BoxShape.circle,
          boxShadow: DesignShadows.fab,
        ),
        alignment: Alignment.center,
        child: AnimatedRotation(
          turns: open ? 0.125 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Sym(
            DesignIcons.add,
            size: 28,
            color: DesignColors.onPrimary,
          ),
        ),
      ),
    ),
  );
}

class _FabMenuItem extends StatelessWidget {
  const _FabMenuItem({required this.action, required this.onTap});

  final FabAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color: DesignColors.fabLabel,
            borderRadius: BorderRadius.circular(DesignRadius.sm),
          ),
          child: Text(
            action.label,
            style: DesignText.bodyMedium.copyWith(
              color: DesignColors.textInverse,
            ),
          ),
        ),
        const SizedBox(width: DesignSpacing.md),
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DesignColors.surfaceCard,
            shape: BoxShape.circle,
            boxShadow: DesignShadows.fabAction,
          ),
          child: Sym(action.icon, size: 22, color: action.color),
        ),
      ],
    ),
  );
}
