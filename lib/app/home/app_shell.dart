import 'package:flutter/material.dart';

import 'package:el_ahorrador/design_system/kit.dart';
import 'package:flutter/services.dart';

import 'package:el_ahorrador/design_system/tokens.dart';

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

/// One action of the + menu.
final class FabAction {
  const FabAction({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onSelected,
    this.capture = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onSelected;

  /// Capture actions sit in the second group with a neutral tile.
  final bool capture;
}

/// v3 shell: 5-tab navigation with a pill on the active tab and the red +
/// with its menu (REGISTRAR · CAPTURA).
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

  /// Navigation bar without the gesture area (86px − 18px in the prototype).
  static const navHeight = 68.0;

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
    final bottomInset = insets.bottom < 18 ? 18.0 : insets.bottom;
    final navTop = navHeight + bottomInset;
    final index = _controller.index;
    final showFab =
        widget.destinations[index].showFab && !_controller.fabHidden;
    final actions = widget.fabActions(_controller);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: DesignColors.paper,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: DesignColors.paper,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: DesignColors.paper,
        body: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: insets.top),
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
                  bottomInset: bottomInset,
                  onSelected: _controller.select,
                ),
              ],
            ),
            if (_fabOpen) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _fabOpen = false),
                  child: const ColoredBox(color: DesignColors.scrim),
                ),
              ),
              Positioned(
                right: 16,
                bottom: navTop + 18 + 62 + 14,
                width: 270,
                child: _FabMenu(
                  actions: actions,
                  onSelected: (action) {
                    setState(() => _fabOpen = false);
                    action.onSelected();
                  },
                ),
              ),
            ],
            if (showFab)
              Positioned(
                right: 18,
                bottom: navTop + 18,
                child: _Fab(
                  key: const ValueKey('fab'),
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
    required this.bottomInset,
    required this.onSelected,
  });

  final List<ShellDestination> destinations;
  final int selected;
  final double bottomInset;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: _AppShellState.navHeight + bottomInset,
    padding: EdgeInsets.fromLTRB(6, 6, 6, bottomInset),
    decoration: const BoxDecoration(
      color: DesignColors.paper,
      border: Border(top: BorderSide(color: DesignColors.line)),
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
                    Container(
                      width: 56,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == selected ? DesignColors.blush : null,
                        borderRadius: BorderRadius.circular(DesignRadius.pill),
                      ),
                      child: Sym(
                        i == selected ? DesignIcons.filled(d.icon) : d.icon,
                        size: 22,
                        color: i == selected
                            ? DesignColors.ink
                            : DesignColors.ink2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        d.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DesignText.nav.copyWith(
                          color: i == selected
                              ? DesignColors.ink
                              : DesignColors.ink2,
                        ),
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
  const _Fab({super.key, required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: open ? 'Cerrar menú' : 'Registrar',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: DesignColors.red,
          borderRadius: BorderRadius.circular(22),
          boxShadow: DesignShadows.fab,
        ),
        alignment: Alignment.center,
        child: Sym(
          open ? DesignIcons.close : DesignIcons.add,
          size: 30,
          color: DesignColors.card,
        ),
      ),
    ),
  );
}

class _FabMenu extends StatelessWidget {
  const _FabMenu({required this.actions, required this.onSelected});

  final List<FabAction> actions;
  final ValueChanged<FabAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final groups = [
      ('REGISTRAR', actions.where((a) => !a.capture)),
      ('CAPTURA', actions.where((a) => a.capture)),
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: DesignColors.paper,
        borderRadius: BorderRadius.circular(DesignRadius.menu),
        boxShadow: DesignShadows.menu,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (title, items) in groups)
            if (items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Text(
                  title,
                  style: DesignText.menuGroup.copyWith(
                    color: DesignColors.ink2,
                  ),
                ),
              ),
              for (final action in items)
                Semantics(
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(action),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: action.capture
                                  ? DesignColors.tile
                                  : DesignColors.blush,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Sym(
                              action.icon,
                              size: 20,
                              color: action.capture
                                  ? DesignColors.ink
                                  : DesignColors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  action.label,
                                  style: DesignText.body14Bold,
                                ),
                                Text(
                                  action.subtitle,
                                  style: DesignText.small.copyWith(
                                    color: DesignColors.ink2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}
