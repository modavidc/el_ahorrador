import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_clock.dart';
import '../../features/ledger/ledger.dart';
import '../../features/ledger/month_summary.dart';
import '../../features/settings/app_preferences.dart';
import '../../theme/design_tokens.dart';
import '../format.dart';
import '../kit.dart';
import '../ledger_scope.dart';
import '../widgets.dart';

/// Ids registered in this session: their rows show "Registrado · Deshacer"
/// until the app restarts.
class RecentEntries extends ValueNotifier<Set<String>> {
  RecentEntries() : super(const {});

  void add(String id) => value = {...value, id};

  void remove(String id) => value = {...value}..remove(id);
}

class RecentEntriesScope extends InheritedNotifier<RecentEntries> {
  const RecentEntriesScope({
    super.key,
    required RecentEntries entries,
    required super.child,
  }) : super(notifier: entries);

  static RecentEntries of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<RecentEntriesScope>()!
      .notifier!;
}

/// Movimientos (v3): month title, streak and search; Diario · Calendario ·
/// Mensual; the "Puedes gastar hoy" card and the notices carousel.
class MovementsScreen extends StatefulWidget {
  const MovementsScreen({
    super.key,
    required this.preferences,
    required this.onAdd,
    required this.onOpen,
    required this.onUndo,
    required this.onTryShare,
    required this.onStreak,
    this.inboxCount,
    this.onOpenInbox,
  });

  final AppPreferences preferences;
  final VoidCallback onAdd;
  final ValueChanged<Movement> onOpen;
  final ValueChanged<Movement> onUndo;
  final VoidCallback onTryShare;
  final VoidCallback onStreak;

  /// Payments waiting in Por revisar, for the "N pagos necesitan un dato"
  /// notice.
  final Stream<int>? inboxCount;
  final VoidCallback? onOpenInbox;

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

enum _Filter { all, expense, income, capture }

class _MovementsScreenState extends State<MovementsScreen> {
  int _tab = 0;
  bool _search = false;
  String _query = '';
  _Filter _filter = _Filter.all;
  bool _showAll = false;
  DateTime? _selectedDay;
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _toggleSearch() => setState(() {
    _search = !_search;
    _query = '';
    _queryController.clear();
    _filter = _Filter.all;
    _tab = 0;
  });

  bool _matches(Movement m) {
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty &&
        !'${m.note} ${m.category} ${m.account}'.toLowerCase().contains(q)) {
      return false;
    }
    return switch (_filter) {
      _Filter.all => true,
      _Filter.expense => m.type == MovementType.expense,
      _Filter.income => m.type == MovementType.income,
      _Filter.capture => m.origin != MovementOrigin.manual,
    };
  }

  @override
  Widget build(BuildContext context) {
    final data = LedgerScope.of(context);
    final today = AppClock.now();
    final summary = MonthSummary(
      movements: data.movements,
      budgetCents: data.monthlyBudgetCents,
      today: today,
    );
    final streak = streakDays(data.movements, today);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
      children: [
        _Header(
          title: Fmt.monthTitle(today.month),
          streak: streak,
          searching: _search,
          onStreak: widget.onStreak,
          onSearch: _toggleSearch,
        ),
        if (_search) ...[
          _SearchField(
            controller: _queryController,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (f, label) in const [
                (_Filter.all, 'Todo'),
                (_Filter.expense, 'Gastos'),
                (_Filter.income, 'Ingresos'),
                (_Filter.capture, 'Captura'),
              ])
                DsChip(
                  label: label,
                  selected: _filter == f,
                  onTap: () => setState(() => _filter = f),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Segmented(
          labels: const ['Diario', 'Calendario', 'Mensual'],
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        ...switch (_tab) {
          0 => _daily(context, summary, streak),
          1 => _calendar(context, summary, today),
          _ => _monthly(
            context,
            data.movements,
            data.monthlyBudgetCents,
            today,
          ),
        },
      ],
    );
  }

  // ---- Diario

  List<Widget> _daily(BuildContext context, MonthSummary summary, int streak) {
    final data = LedgerScope.of(context);
    final recent = RecentEntriesScope.of(context).value;
    final filtering = _query.trim().isNotEmpty || _filter != _Filter.all;
    final days = groupByDay(data.movements.where(_matches));
    final visible = filtering || _showAll ? days : days.take(6).toList();
    final today = AppClock.now();

    return [
      if (!filtering) ...[
        const SizedBox(height: 12),
        _BudgetCard(summary: summary),
        _Notices(
          movements: data.movements,
          preferences: widget.preferences,
          streak: streak,
          onTryShare: widget.onTryShare,
          inboxCount: widget.inboxCount,
          onOpenInbox: widget.onOpenInbox,
          onAdd: widget.onAdd,
        ),
      ],
      if (filtering && days.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 50),
          child: Text(
            'Sin resultados',
            textAlign: TextAlign.center,
            style: DesignText.row.copyWith(
              fontWeight: FontWeight.w400,
              color: DesignColors.ink2,
            ),
          ),
        ),
      if (!filtering && days.isEmpty && data.loaded) const _EmptyDay(),
      for (final (day, rows) in visible) ...[
        DayHeader(
          day: day.day,
          label: dayLabel(day, today),
          net: Fmt.net(dayNetCents(rows) / 100),
        ),
        PaperCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Column(
            children: [
              for (final (i, m) in rows.indexed)
                MovementRow(
                  movement: m,
                  first: i == 0,
                  onTap: () => widget.onOpen(m),
                  onUndo: recent.contains(m.id) ? () => widget.onUndo(m) : null,
                ),
            ],
          ),
        ),
      ],
      if (!filtering && !_showAll && days.length > 6) ...[
        const SizedBox(height: 14),
        _WideButton(
          label: 'Ver días anteriores',
          onTap: () => setState(() => _showAll = true),
        ),
      ],
    ];
  }

  // ---- Calendario

  List<Widget> _calendar(
    BuildContext context,
    MonthSummary summary,
    DateTime today,
  ) {
    final month = summary.month;
    final selected =
        _selectedDay ?? DateTime(today.year, today.month, today.day);
    final byDay = {
      for (final (d, rows) in groupByDay(summary.movements)) d: rows,
    };
    final rows = byDay[selected] ?? const <Movement>[];
    final first = DateTime(month.year, month.month);
    final lead = first.weekday % 7;
    final cells = <DateTime>[
      for (var i = -lead; i < summary.daysInMonth; i++)
        DateTime(month.year, month.month, i + 1),
    ];
    while (cells.length % 7 != 0) {
      final last = cells.last;
      cells.add(DateTime(last.year, last.month, last.day + 1));
    }
    final recent = RecentEntriesScope.of(context).value;

    return [
      const SizedBox(height: 12),
      PaperCard(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (final w in const ['D', 'L', 'M', 'M', 'J', 'V', 'S'])
                    Expanded(
                      child: Text(
                        w,
                        textAlign: TextAlign.center,
                        style: DesignText.tinyBold.copyWith(
                          color: DesignColors.ink2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (var w = 0; w < cells.length; w += 7)
              Row(
                children: [
                  for (final d in cells.sublist(w, w + 7))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: _CalendarCell(
                          day: d,
                          inMonth: d.month == month.month,
                          today: DateUtils.isSameDay(d, today),
                          selected: DateUtils.isSameDay(d, selected),
                          movements: byDay[d] ?? const [],
                          onTap: d.month == month.month
                              ? () => setState(() => _selectedDay = d)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
      DayHeader(
        day: selected.day,
        label: dayLabel(selected, today),
        net: Fmt.net(dayNetCents(rows) / 100),
        top: 18,
      ),
      PaperCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: rows.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Sin movimientos este día',
                  textAlign: TextAlign.center,
                  style: DesignText.body14.copyWith(color: DesignColors.ink2),
                ),
              )
            : Column(
                children: [
                  for (final (i, m) in rows.indexed)
                    MovementRow(
                      movement: m,
                      first: i == 0,
                      compact: true,
                      onTap: () => widget.onOpen(m),
                      onUndo: recent.contains(m.id)
                          ? () => widget.onUndo(m)
                          : null,
                    ),
                ],
              ),
      ),
    ];
  }

  // ---- Mensual

  List<Widget> _monthly(
    BuildContext context,
    List<Movement> movements,
    int budgetCents,
    DateTime today,
  ) {
    final months = {
      DateTime(today.year, today.month),
      for (final m in movements) DateTime(m.at.year, m.at.month),
    }.toList()..sort((a, b) => b.compareTo(a));
    return [
      const SizedBox(height: 12),
      for (final (i, month) in months.indexed) ...[
        if (i > 0) const SizedBox(height: 10),
        _MonthCard(
          summary: MonthSummary(
            movements: movements,
            budgetCents: budgetCents,
            today: today,
            month: month,
          ),
        ),
      ],
    ];
  }
}

/// "Hoy", "Ayer", "Viernes 25" (with the month when it is another one).
String dayLabel(DateTime day, DateTime today) {
  final d = DateTime(day.year, day.month, day.day);
  final t = DateTime(today.year, today.month, today.day);
  if (d == t) return 'Hoy';
  if (d == DateTime(t.year, t.month, t.day - 1)) return 'Ayer';
  const names = [
    'Domingo',
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
  ];
  final label = '${names[d.weekday % 7]} ${d.day}';
  return d.month == t.month && d.year == t.year
      ? label
      : '$label ${Fmt.months[d.month - 1].toLowerCase()}';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.streak,
    required this.searching,
    required this.onStreak,
    required this.onSearch,
  });

  final String title;
  final int streak;
  final bool searching;
  final VoidCallback onStreak;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 56),
    child: Row(
      children: [
        Expanded(child: Text(title, style: DesignText.tabTitle)),
        const SizedBox(width: 2),
        Semantics(
          button: true,
          label: 'Racha',
          child: GestureDetector(
            onTap: onStreak,
            child: Container(
              height: 40,
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
              decoration: BoxDecoration(
                color: DesignColors.card,
                borderRadius: BorderRadius.circular(DesignRadius.pill),
                boxShadow: DesignShadows.card,
              ),
              child: Row(
                children: [
                  Sym(
                    DesignIcons.filled(DesignIcons.localFireDepartment),
                    size: 20,
                    color: DesignColors.red,
                  ),
                  const SizedBox(width: 4),
                  Text('$streak', style: DesignText.body14Bold),
                ],
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: searching ? 'Cerrar búsqueda' : 'Buscar',
          child: GestureDetector(
            onTap: onSearch,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Sym(
                  searching ? DesignIcons.close : DesignIcons.search,
                  size: 24,
                  color: DesignColors.ink2,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    margin: const EdgeInsets.only(bottom: 0),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: DesignColors.card,
      borderRadius: BorderRadius.circular(DesignRadius.lg),
      boxShadow: DesignShadows.card,
    ),
    child: Row(
      children: [
        const Sym(DesignIcons.search, size: 20, color: DesignColors.ink2),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            style: DesignText.input,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: 'Buscar por nota o categoría',
              hintStyle: DesignText.input.copyWith(color: DesignColors.ink2),
            ),
          ),
        ),
      ],
    ),
  );
}

/// "Puedes gastar hoy" with what is left, days, the budget bar and today's
/// mark.
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final grey = DesignText.small.copyWith(color: DesignColors.ink2);
    final strong = DesignText.smallBold;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Puedes gastar hoy',
                      style: DesignText.smallBold.copyWith(
                        color: DesignColors.ink2,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Fmt.signedMoney(s.perDay),
                        style: DesignText.figure.copyWith(
                          color: s.overBudget
                              ? DesignColors.red
                              : DesignColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'Quedan ',
                      children: [
                        TextSpan(
                          text: Fmt.signedMoney(s.leftCents / 100),
                          style: strong,
                        ),
                      ],
                    ),
                    style: grey.copyWith(height: 1.5),
                  ),
                  Text(
                    '${s.daysLeft} ${s.daysLeft == 1 ? 'día' : 'días'} · '
                    '${s.spentPercent}% usado',
                    style: grey.copyWith(height: 1.5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _BudgetBar(spent: s.spentRatio, today: s.dayRatio),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text.rich(
                TextSpan(
                  text: 'Ingresos ',
                  children: [
                    TextSpan(
                      text: Fmt.money(s.incomeCents / 100),
                      style: strong.copyWith(color: DesignColors.green),
                    ),
                  ],
                ),
                style: grey,
              ),
              Text.rich(
                TextSpan(
                  text: 'Gastos ',
                  children: [
                    TextSpan(
                      text: Fmt.money(s.spentCents / 100),
                      style: strong,
                    ),
                  ],
                ),
                style: grey,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetBar extends StatelessWidget {
  const _BudgetBar({required this.spent, required this.today});

  final double spent;
  final double today;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 14,
    child: LayoutBuilder(
      builder: (context, box) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 4,
            height: 6,
            child: Container(
              decoration: BoxDecoration(
                color: DesignColors.chip,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 4,
            height: 6,
            width: box.maxWidth * spent.clamp(0, 1),
            child: Container(
              decoration: BoxDecoration(
                color: DesignColors.red,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Positioned(
            left: box.maxWidth * today.clamp(0, 1) - 1,
            top: 0,
            bottom: 0,
            width: 2,
            child: const ColoredBox(color: DesignColors.ink),
          ),
        ],
      ),
    ),
  );
}

/// One notice of the carousel.
final class _Notice {
  const _Notice({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
    this.dark = false,
    this.accent = false,
  });

  final String key;
  final IconData icon;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;
  final bool dark;
  final bool accent;
}

/// "AVISOS · N": horizontal cards with snap, dots and × to dismiss.
class _Notices extends StatefulWidget {
  const _Notices({
    required this.movements,
    required this.preferences,
    required this.streak,
    required this.onTryShare,
    required this.onAdd,
    this.inboxCount,
    this.onOpenInbox,
  });

  final List<Movement> movements;
  final AppPreferences preferences;
  final int streak;
  final VoidCallback onTryShare;
  final VoidCallback onAdd;
  final Stream<int>? inboxCount;
  final VoidCallback? onOpenInbox;

  @override
  State<_Notices> createState() => _NoticesState();
}

class _NoticesState extends State<_Notices> {
  late final Stream<Set<String>> _dismissed = widget.preferences
      .watchDismissedNotices();
  int _index = 0;
  PageController? _pages;

  @override
  void dispose() {
    _pages?.dispose();
    _inboxSubscription?.cancel();
    super.dispose();
  }

  late final Stream<int> _inbox = widget.inboxCount ?? Stream.value(0);
  int _pending = 0;
  StreamSubscription<int>? _inboxSubscription;

  @override
  void initState() {
    super.initState();
    _inboxSubscription = _inbox.listen((n) => setState(() => _pending = n));
  }

  List<_Notice> _notices(Set<String> dismissed) {
    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day);
    final nightKey = 'night:${today.toIso8601String().substring(0, 10)}';
    final usedCapture = widget.movements.any(
      (m) => m.origin != MovementOrigin.manual,
    );
    final hasToday = widget.movements.any((m) => m.day == today);
    return [
      if (!usedCapture)
        _Notice(
          key: 'share',
          icon: DesignIcons.bolt,
          title: 'Prueba la función principal',
          subtitle: 'Yape → Compartir → El Ahorrador.',
          cta: 'Probar',
          onTap: widget.onTryShare,
          dark: true,
        ),
      if (_pending > 0 && widget.onOpenInbox != null)
        _Notice(
          key: 'inbox:$_pending',
          icon: DesignIcons.inbox,
          title: _pending == 1
              ? '1 pago necesita un dato'
              : '$_pending pagos necesitan un dato',
          subtitle: 'Complétalos y quedan registrados.',
          cta: 'Revisar',
          onTap: widget.onOpenInbox!,
        ),
      if (!hasToday && now.hour >= 20)
        _Notice(
          key: nightKey,
          icon: DesignIcons.nightlight,
          title: 'Aún no registras nada hoy',
          subtitle: widget.streak > 0
              ? 'Son las ${Fmt.time(now)} · tu racha de ${widget.streak} '
                    '${widget.streak == 1 ? 'día' : 'días'} está en juego.'
              : 'Son las ${Fmt.time(now)} · empieza tu racha hoy.',
          cta: 'Registrar',
          onTap: widget.onAdd,
          accent: true,
        ),
    ].where((n) => !dismissed.contains(n.key)).toList();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Set<String>>(
    stream: _dismissed,
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      final notices = _notices(snapshot.data!);
      if (notices.isEmpty) return const SizedBox.shrink();
      final index = _index.clamp(0, notices.length - 1);
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(
              'Avisos · ${notices.length}',
              trailing: notices.length < 2
                  ? null
                  : Row(
                      children: [
                        for (final (i, _) in notices.indexed) ...[
                          if (i > 0) const SizedBox(width: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: i == index ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == index
                                  ? DesignColors.ink
                                  : DesignColors.lineStrong,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            LayoutBuilder(
              builder: (context, box) {
                // Cards are the width minus 20px with an 8px gap, and the
                // strip bleeds to the screen edges (margin 0 −18px).
                final fraction = (box.maxWidth - 20 + 8) / (box.maxWidth + 18);
                if (_pages?.viewportFraction != fraction) {
                  _pages?.dispose();
                  _pages = PageController(viewportFraction: fraction);
                }
                return SizedBox(
                  height: 96,
                  child: OverflowBox(
                    maxWidth: box.maxWidth + 36,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: PageView.builder(
                        controller: _pages,
                        padEnds: false,
                        clipBehavior: Clip.none,
                        itemCount: notices.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _NoticeCard(
                            notice: notices[i],
                            onDismiss: () {
                              widget.preferences.dismissNotice(notices[i].key);
                              setState(() => _index = 0);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.onDismiss});

  final _Notice notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final n = notice;
    final fg = n.dark ? DesignColors.card : DesignColors.ink;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: n.dark ? DesignColors.ink : DesignColors.card,
        borderRadius: BorderRadius.circular(DesignRadius.notice),
        boxShadow: DesignShadows.card,
      ),
      child: Row(
        children: [
          IconTile(
            icon: n.icon,
            color: n.dark
                ? DesignColors.onDarkAccent
                : n.accent
                ? DesignColors.red
                : DesignColors.ink,
            background: n.dark
                ? DesignColors.onDarkTile
                : n.accent
                ? DesignColors.blush
                : DesignColors.tile,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: n.onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DesignText.body14Bold.copyWith(
                      color: fg,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DesignText.small.copyWith(
                      height: 1.35,
                      color: n.dark
                          ? DesignColors.onDarkText
                          : DesignColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: n.onTap,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: n.dark || n.accent
                      ? DesignColors.red
                      : DesignColors.ink,
                  borderRadius: BorderRadius.circular(DesignRadius.pill),
                ),
                child: Text(
                  n.cta,
                  style: DesignText.label13Bold.copyWith(
                    color: DesignColors.card,
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Descartar aviso',
            child: GestureDetector(
              onTap: onDismiss,
              child: SizedBox(
                width: 36,
                height: 44,
                child: Center(
                  child: Sym(
                    DesignIcons.close,
                    size: 18,
                    color: n.dark
                        ? DesignColors.onDarkClose
                        : DesignColors.ink2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.movements,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool today;
  final bool selected;
  final List<Movement> movements;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    int sum(MovementType t) => movements
        .where((m) => m.type == t)
        .fold(0, (a, m) => a + m.amountCents);
    final income = inMonth ? sum(MovementType.income) : 0;
    final expense = inMonth ? sum(MovementType.expense) : 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        decoration: BoxDecoration(
          color: selected
              ? DesignColors.blush
              : today
              ? DesignColors.tile
              : null,
          borderRadius: BorderRadius.circular(DesignRadius.md),
        ),
        child: Column(
          children: [
            Text(
              '${day.day}',
              style: DesignText.label13Bold.copyWith(
                color: !inMonth
                    ? DesignColors.inkOut
                    : selected
                    ? DesignColors.red
                    : DesignColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            if (income > 0)
              _cellAmount(income, DesignText.tinyBold, DesignColors.green),
            if (expense > 0)
              _cellAmount(expense, DesignText.tiny, DesignColors.ink3),
          ],
        ),
      ),
    );
  }

  Widget _cellAmount(int cents, TextStyle style, Color color) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(Fmt.short(cents / 100), style: style.copyWith(color: color)),
  );
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final over = s.overBudget;
    final grey = DesignText.label13.copyWith(color: DesignColors.ink2);
    final strong = DesignText.label13Bold;
    final note = over
        ? 'Te pasaste ${Fmt.money0(-s.leftCents / 100)} del presupuesto'
        : '${s.spentPercent}% del presupuesto${s.isCurrent ? ' · en curso' : ''}';
    return PaperCard(
      padding: const EdgeInsets.all(16),
      border: Border.all(
        color: s.isCurrent ? DesignColors.red : Colors.transparent,
        width: 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Fmt.monthTitle(s.month.month),
                  style: DesignText.cardTitle,
                ),
              ),
              Text(
                Fmt.net0(s.netCents / 100),
                style: DesignText.rowAmountStrong.copyWith(
                  color: s.netCents < 0 ? DesignColors.red : DesignColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: [
              Text.rich(
                TextSpan(
                  text: 'Ingresos ',
                  children: [
                    TextSpan(
                      text: Fmt.money0(s.incomeCents / 100),
                      style: strong.copyWith(color: DesignColors.green),
                    ),
                  ],
                ),
                style: grey,
              ),
              Text.rich(
                TextSpan(
                  text: 'Gastos ',
                  children: [
                    TextSpan(
                      text: Fmt.money0(s.spentCents / 100),
                      style: strong,
                    ),
                  ],
                ),
                style: grey,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) => Container(
              height: 6,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: DesignColors.chip,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Container(
                width: box.maxWidth * s.spentRatio.clamp(0, 1),
                decoration: BoxDecoration(
                  color: over ? DesignColors.red : DesignColors.ink,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: DesignText.small.copyWith(color: DesignColors.ink2),
          ),
        ],
      ),
    );
  }
}

class _WideButton extends StatelessWidget {
  const _WideButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DesignColors.chip,
          borderRadius: BorderRadius.circular(DesignRadius.lg),
        ),
        child: Text(label, style: DesignText.body14Bold),
      ),
    ),
  );
}

/// Empty month: what to do first.
class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    child: Column(
      children: [
        const IconTile(
          icon: DesignIcons.receiptLong,
          color: DesignColors.red,
          background: DesignColors.blush,
          size: 56,
          iconSize: 28,
          radius: 18,
        ),
        const SizedBox(height: 12),
        Text('Aún no hay movimientos', style: DesignText.cardTitle),
        const SizedBox(height: 4),
        Text(
          'Comparte un comprobante de Yape o toca + para registrar.',
          textAlign: TextAlign.center,
          style: DesignText.body14.copyWith(color: DesignColors.ink2),
        ),
      ],
    ),
  );
}
