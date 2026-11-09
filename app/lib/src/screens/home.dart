part of '../../main.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _Home();
}

class _Home extends State<Home> with WidgetsBindingObserver {
  List<Reminder> rows = [];
  Map<String, dynamic> taken = {};
  int tab = 0, revision = 0;
  Reminder? edit;
  bool loading = true, saving = false;
  String? loadError;
  DateTime cursor = DateTime.now(), selected = DateTime.now();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !loading &&
        !saving &&
        loadError == null)
      load();
  }

Widget _waterProgress(Reminder reminder) {
  final now = DateTime.now();

  final today =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  final waterHistory = taken['__water'];
  final reminderHistory =
      waterHistory is Map ? waterHistory[reminder['id']] : null;
  final dayHistory =
      reminderHistory is Map ? reminderHistory[today] : null;

  final total = (reminder['cups'] as num?)?.toInt() ?? 1;
  final count = total.clamp(1, 24).toInt();

  final completed = dayHistory is Map
      ? dayHistory.length.clamp(0, count).toInt()
      : 0;

  const blue = Color(0xff3788b5);

  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: isEnglish
              ? '$completed of $count glasses completed today'
              : '${fa(completed)} از ${fa(count)} لیوان امروز مصرف شده',
          child: ExcludeSemantics(
            child: LayoutBuilder(
  builder: (context, constraints) {
    final gap = count <= 12 ? 4.0 : 2.0;

    final segmentWidth =
        (constraints.maxWidth - gap * (count - 1)) / count;

    final radius =
        (segmentWidth / 3).clamp(1.0, 5.0).toDouble();

    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              height: 18,
              decoration: BoxDecoration(
                color: i < completed
                    ? blue
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: blue.withValues(
                    alpha: i < completed ? 1 : 0.25,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  },
),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          isEnglish
              ? '$completed of $count today'
              : '${fa(completed)} از ${fa(count)} امروز',
          style: const TextStyle(
            fontSize: 12,
            color: blue,
          ),
        ),
      ],
    ),
  );
}

void _showSaveFeedback({required bool exact}) {
  if (!mounted) return;

  final colors = Theme.of(context).colorScheme;

  final accent = exact
      ? colors.primary
      : const Color(0xff925b21);

  final background = exact
      ? Color.alphaBlend(
          colors.primary.withValues(alpha: 0.08),
          Colors.white,
        )
      : const Color(0xfffff1df);

  final messenger = ScaffoldMessenger.of(context);

  messenger.hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: background,
      elevation: 4,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      duration: Duration(seconds: exact ? 4 : 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: accent.withValues(alpha: 0.12),
        ),
      ),
      content: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              exact
                  ? Icons.check_rounded
                  : Icons.alarm_outlined,
              color: accent,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEnglish
                      ? 'Reminder saved'
                      : 'یادآورت ذخیره شد',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!exact) ...[
                  const SizedBox(height: 4),
                  Text(
                    isEnglish
                        ? 'Enable exact alarms for timed alerts.'
                        : 'برای زنگ خوردن، مجوز آلارم دقیق رو فعال کن.',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      action: exact
          ? null
          : SnackBarAction(
              label: isEnglish ? 'Enable' : 'فعال‌سازی',
              textColor: accent,
              onPressed: () async {
                try {
                  await native.invokeMethod('exact');
                } catch (_) {
                  if (!mounted) return;

                  message(
                    isEnglish
                        ? 'Could not open alarm permissions.'
                        : 'صفحهٔ مجوز آلارم باز نشد.',
                  );
                }
              },
            ),
    ),
  );
}

  Future<void> load() async {
    try {
      final data = await native.invokeMethod<String>('load');
      final history = await native.invokeMethod<String>('history');
      final dataRows = (jsonDecode(data ?? '[]') as List).cast<Reminder>();
      if (!mounted || saving) return;
      setState(() {
        rows = dataRows;
        taken = (jsonDecode(history ?? '{}') as Map).cast<String, dynamic>();
        loading = false;
        loadError = null;
      });
      if (dataRows.isNotEmpty &&
          await native.invokeMethod<bool>('needsRefresh') == true &&
          mounted &&
          !saving) {
        await save(dataRows, quiet: true);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          loading = false;
          loadError = e.toString();
        });
    }
  }

  void message(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  
  Future<bool> save(List<Reminder> updated, {bool quiet = false}) async {
    if (saving) return false;
    setState(() => saving = true);
    try {
      final now = DateTime.now();
      final scheduled = <Reminder>[];
      for (final r in updated) {
        final frequent =
            ['water', 'medicine'].contains(r['kind']) ||
            (r['n'] == 1 && ['day', 'week'].contains(r['unit']));
        final until = frequent ? day(now, 405) : month(now, 240);
        final immediate =
    ['water', 'medicine'].contains(r['kind']) &&
    r['startNow'] == true;

final from = immediate
    ? DateTime.parse(r['start'] as String)
    : now;
final generated = events(r, from, until)
    .where((event) => !event.calendar);

final occurrences = (
  ['water', 'medicine'].contains(r['kind'])
      ? generated.take(1)
      : generated
).toList()
  ..sort((a, b) => a.time.compareTo(b.time));
        for (final e in occurrences) {
  final when = e.time.millisecondsSinceEpoch;

  final scheduledItem = <String, dynamic>{
    'id': r['id'],
    'kind': r['kind'],
    'when': when,
    'originalWhen': when,
    'occurrence': '${r['id']}:$when',
    'message': e.message,
    'alarm': e.alarm,
  };

  if (r['kind'] == 'water') {
  final start = DateTime.parse(r['start'] as String);
  final stepMs = waterIntervalSeconds(r) * 1000;

  final index =
      e.time.difference(start).inMilliseconds ~/ stepMs;

  scheduledItem.addAll({
    'waterAnchor': start.millisecondsSinceEpoch,
    'waterStepMs': stepMs,
    'waterIndex': index,

    // صفر یعنی ادامه بدون محدودیت تعداد.
    'waterLimit': r['waterRepeat'] == true ? 0 : r['cups'],

    if (r['end'] != null)
      'waterEnd': DateTime.parse(r['end'] as String)
          .millisecondsSinceEpoch,

    'waterDay':
        '${e.time.year.toString().padLeft(4, '0')}-'
        '${e.time.month.toString().padLeft(2, '0')}-'
        '${e.time.day.toString().padLeft(2, '0')}',

    'waterSlot': index,
  });
}
  if (r['kind'] == 'medicine') {
  final start = DateTime.parse(r['start'] as String);

  scheduledItem.addAll({
    'medicineAnchor': start.millisecondsSinceEpoch,
    'medicineStepMs': medicineIntervalSeconds(r) * 1000,
    'medicineDays': medicineWeekdays(r).toList()..sort(),

    if (r['end'] != null)
      'medicineEnd': DateTime.parse(r['end'] as String)
          .millisecondsSinceEpoch,
  });
}
  scheduled.add(scheduledItem);
}
      }

final storedRows = <Reminder>[
  for (final row in updated)
    {
      ...row,
      'startNow': false,
    },
];

      final exact = await native.invokeMethod<bool>('save', {
        'rows': jsonEncode(storedRows),
        'events': jsonEncode(scheduled),
      });
      if (!mounted) return false;
      setState(() => rows = storedRows);
      if (!quiet) {
        _showSaveFeedback(exact: exact == true);
      }
      return true;
    } catch (e) {
      if (mounted) message('${tr("خطا در ذخیره یا زمان‌بندی")}: $e');
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

Widget _medicineDetails(Reminder reminder) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final paused = reminder['paused'] == true;

  // هنگام توقف هم آمار برنامهٔ امروز قابل مشاهده باشد.
  final schedule = <String, dynamic>{
    ...reminder,
    'paused': false,
  };

  final todayTimes = medicineOccurrences(
    schedule,
    today,
    tomorrow,
  ).toList();

  final allHistory = taken['__medicine'];
  final rawHistory = allHistory is Map
      ? allHistory[reminder['id']]
      : null;

  final history = rawHistory is Map
      ? rawHistory
      : const <String, dynamic>{};

  bool wasTaken(DateTime time) =>
      history.containsKey('${time.millisecondsSinceEpoch}');

  final completed = todayTimes.where(wasTaken).length;
  final total = todayTimes.length;

  final future = medicineOccurrences(
    schedule,
    now,
    DateTime(now.year, now.month, now.day + 405),
  ).where((time) => !wasTaken(time));

  DateTime? next = future.isEmpty ? null : future.first;
  String nextState = 'scheduled';

  final allPending = taken['__medicinePending'];
  final pending = allPending is Map
      ? allPending[reminder['id']]
      : null;

  if (pending is Map && pending['when'] is num) {
    final pendingTime = DateTime.fromMillisecondsSinceEpoch(
      (pending['when'] as num).toInt(),
    );

    final state = pending['state'] as String? ?? 'scheduled';

    if (state == 'ringing' ||
        !pendingTime.isBefore(now.subtract(const Duration(minutes: 1)))) {
      if (next == null || !pendingTime.isAfter(next)) {
        next = pendingTime;
        nextState = state;
      }
    }
  }

  const accent = Color(0xff78649d);

  final type = reminder['type'] as String? ?? 'قرص';

  const englishTypes = {
    'قرص': 'Tablet',
    'کپسول': 'Capsule',
    'شربت': 'Syrup',
    'پماد': 'Ointment',
    'کرم': 'Cream',
    'آمپول': 'Injection',
    'قطره': 'Drops',
    'سایر': 'Other',
  };

  final typeLabel = isEnglish
      ? englishTypes[type] ?? tr(type)
      : type;

  String nextLabel;

  if (paused) {
    nextLabel = isEnglish ? 'Paused' : 'متوقف';
  } else if (nextState == 'ringing') {
    nextLabel = isEnglish
        ? 'Current dose · awaiting confirmation'
        : 'نوبت فعلی · منتظر تأیید مصرف';
  } else if (next == null) {
    nextLabel = isEnglish
        ? 'No upcoming dose in the scheduling window'
        : 'نوبت بعدی در بازهٔ زمان‌بندی نیست';
  } else {
    final timeLabel = DateUtils.isSameDay(next, now)
        ? '${isEnglish ? "Today" : "امروز"}، ${clock(next)}'
        : '${date(next)}، ${clock(next)}';

    final prefix = nextState == 'snoozed'
        ? (isEnglish ? 'Snoozed' : 'تعویق تا')
        : (isEnglish ? 'Next' : 'نوبت بعد');

    nextLabel = '$prefix: $timeLabel';
  }

  final progressLabel = total == 0
      ? (isEnglish ? 'No doses scheduled today' : 'امروز نوبت مصرف نداری')
      : isEnglish
          ? '$completed of $total doses taken today'
          : '${fa(completed)} از ${fa(total)} نوبت امروز مصرف شده';

  final note = reminder['note'] as String? ?? '';

  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            typeLabel,
            style: const TextStyle(
              fontSize: 12,
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          progressLabel,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: accent,
          ),
        ),
        if (total > 0) ...[
          const SizedBox(height: 8),
          Semantics(
            label: progressLabel,
            child: ExcludeSemantics(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // برای تعداد زیاد، نوار پیوسته خواناتر است.
                  final available = constraints.maxWidth;
                  final segmentWidth =
                      (available - (total - 1) * 4) / total;

                  if (total > 12 || segmentWidth < 12) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: completed / total,
                        minHeight: 10,
                        color: accent,
                        backgroundColor:
                            accent.withValues(alpha: 0.12),
                      ),
                    );
                  }

                  return Row(
                    children: [
                      for (var i = 0; i < total; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 14,
                            decoration: BoxDecoration(
                              color: wasTaken(todayTimes[i])
                                  ? accent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              paused
                  ? Icons.pause_circle_outline
                  : nextState == 'snoozed'
                      ? Icons.snooze_outlined
                      : Icons.schedule_outlined,
              size: 17,
              color: accent,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                nextLabel,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
        if (note.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            note,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );
}

Future<void> _deleteCustomReminder(Reminder reminder) async {
  if (saving || reminder['kind'] != 'custom') return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Text(
        isEnglish
            ? 'Delete this reminder?'
            : 'این یادآور حذف شود؟',
      ),
      content: Text(
        isEnglish
            ? '“${reminder['title']}” and its scheduled alerts will be removed.'
            : '«${reminder['title']}» همراه با یادآوری‌های زمان‌بندی‌شده‌اش حذف می‌شود.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(isEnglish ? 'Cancel' : 'لغو'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(isEnglish ? 'Delete' : 'حذف'),
        ),
      ],
    ),
  );

  if (confirmed != true || !mounted || saving) return;

  final deleted = await save(
    [
      for (final row in rows)
        if (row['id'] != reminder['id']) row,
    ],
    quiet: true,
  );

  if (!mounted || !deleted) return;

  setState(() {
    if (edit?['id'] == reminder['id']) {
      edit = null;
      revision++;
    }
  });

  message(
    isEnglish ? 'Custom reminder deleted' : 'یادآور دلخواه حذف شد',
  );
}

 @override
Widget build(BuildContext context) {
  return ValueListenableBuilder<bool>(
    valueListenable: categoryPickerVisible,
    builder: (context, pickerVisible, child) {
      final fullscreenPicker = tab == 0;
      return _buildPage(context, fullscreenPicker);
    },
  );
}

Widget _buildPage(BuildContext context, bool fullscreenPicker) => Scaffold(
    appBar: fullscreenPicker ? null : AppBar(
      title: Text(tr('یادآور')),
      actions: [
        IconButton(
          tooltip: tr('تنظیمات'),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const Settings())),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : loadError != null
        ? Center(
            child: TextButton(
              onPressed: load,
              child: Text(tr('خطا در خواندن داده‌ها؛ تلاش دوباره')),
            ),
          )
        : IndexedStack(
            index: tab,
            children: [
              ReminderForm(
                customReminders: rows
                    .where((item) => item['kind'] == 'custom')
                    .toList(),
                    isActive: tab == 0,
                onCalendar: () {
  setState(() {
    tab = 1;
  });
},    
                onOpenCustom: (item) {
                  if (saving) return;
                  final reveal = context
                      .findAncestorStateOfType<_ThemeRevealState>();
                  if (reveal != null && selectedTheme.value != 'custom') {
                    reveal.changeTo('custom');
                  } else {
                    selectedTheme.value = 'custom';
                  }
                  setState(() {
                    edit = item;
                    revision++;
                    tab = 0;
                  });
                },
                key: ValueKey(revision),
                row: edit,
                busy: saving,
                onDeleteCustom: _deleteCustomReminder,
                onSave: (r) async {
  final exists = rows.any((row) => row['id'] == r['id']);

  // ویرایش جای قبلی را حفظ می‌کند؛ مورد جدید به آخر اضافه می‌شود.
  final updated = <Reminder>[
    for (final row in rows)
      if (row['id'] == r['id']) r else row,
    if (!exists) r,
  ];

  if (!await save(updated) || !mounted) return;

  if (r['kind'] == 'custom') {
    _ReminderCardsState.rememberCustom(r['id'] as String);
    selectedTheme.value = null;
  }

  setState(() {
    edit = null;
    revision++;
    tab = r['kind'] == 'custom' ? 0 : 2;
  });
},
              ),
              calendar(),
              list(),
            ],
          ),
    bottomNavigationBar: fullscreenPicker ? null : NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline),
          label: tr('ثبت یادآور'),
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          label: tr('تقویم'),
        ),
        NavigationDestination(
          icon: Icon(Icons.list_alt_outlined),
          label: tr('یادآورهای من'),
        ),
      ],
    ),
  );
  
  
Widget calendar() {
    final j = Jalali.fromDateTime(cursor);
    final first = Jalali(j.year, j.month).toDateTime();
    final limit = month(first, 1);
    final startIndex = (first.weekday + 1) % 7;
    final marks = <int, Set<String>>{};
    final details = <String>[];
    for (final r in rows) {
      for (final e in events(r, first, limit).where((e) => e.calendar)) {
        final d = Jalali.fromDateTime(e.time).day;
        (marks[d] ??= <String>{}).add(r['kind'] as String);
        if (DateUtils.isSameDay(e.time, selected))
          details.add('${kinds[r['kind']]!.$2}  ${r['title']}');
      }
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: tr('ماه قبل'),
                      onPressed: () =>
                          setState(() => cursor = month(first, -1)),
                      icon: Icon(
                        isEnglish ? Icons.chevron_left : Icons.chevron_right,
                      ),
                    ),
                    Text(
                      '${solarMonth(j)} ${fa(j.year)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      tooltip: tr('ماه بعد'),
                      onPressed: () => setState(() => cursor = limit),
                      icon: Icon(
                        isEnglish ? Icons.chevron_right : Icons.chevron_left,
                      ),
                    ),
                  ],
                ),
                Row(
                  children:
                      (isEnglish
                              ? [
                                  'Sat',
                                  'Sun',
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                ]
                              : ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'])
                          .map((d) => Expanded(child: Center(child: Text(d))))
                          .toList(),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 7,
                  childAspectRatio: .82,
                  children: List.generate(startIndex + j.monthLength, (i) {
                    final d = i - startIndex + 1;
                    if (d < 1) return const SizedBox();
                    final t = day(first, d - 1);
                    final icons = (marks[d] ?? {})
                        .map((k) => kinds[k]!.$2)
                        .toList();
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => selected = t),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: DateUtils.isSameDay(t, selected)
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(fa(d)),
                            if (icons.isNotEmpty)
                              Text(
                                icons.length > 2
                                    ? '${icons.first}+${fa(icons.length - 1)}'
                                    : icons.join(),
                                style: const TextStyle(fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        ListTile(
          title: Text(date(selected)),
          subtitle: Text(
            details.isEmpty ? tr('مناسبتی ثبت نشده است') : details.join('\n'),
          ),
        ),
      ],
    );
  }

  Widget list() {
    final now = DateTime.now();
    if (rows.isEmpty)
      return Center(child: Text(tr('اولین یادآورت را ثبت کن 🌱')));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final k in kinds.keys)
          if (rows.any((r) => r['kind'] == k)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '${kinds[k]!.$2}  ${tr(kinds[k]!.$1)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final r in rows.where((r) => r['kind'] == k))
              Builder(
                builder: (context) {
                  final times =
                      events(
                          r,
                          now,
                          ['water', 'medicine'].contains(k)
                              ? day(now, 405)
                              : month(now, 240),
                        ).where((e) => !e.calendar).map((e) => e.time).toList()
                        ..sort();
                  return Card(
                    color: kinds[k]!.$3,
                    child: ListTile(
                      title: Text(
                        k == 'water' ? tr('آب خوردن') : r['title'] as String,
                      ),
                      subtitle: k == 'medicine'
    ? _medicineDetails(r)
    : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (r['paused'] == true)
                tr('متوقف')
              else if (times.isEmpty)
                tr('نوبت فعالی در بازهٔ زمان‌بندی نیست')
              else
                '${date(times.first)}، ${clock(times.first)}',
              if (r['note'] is String &&
                  (r['note'] as String).isNotEmpty)
                r['note'] as String,
            ].join('\n'),
          ),
          if (k == 'water') _waterProgress(r),
        ],
      ),
                      trailing: PopupMenuButton<String>(
                        enabled: !saving,
                        onSelected: (action) async {
                          if (action == 'edit') {
                            selectedTheme.value = r['kind'] as String;
                            setState(() {
                              edit = r;
                              revision++;
                              tab = 0;
                            });
                            return;
                          }
                          if (action == 'delete') {
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(tr('این یادآور حذف شود؟')),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(tr('لغو')),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(tr('حذف')),
                                  ),
                                ],
                              ),
                            );
                            if (yes == true && mounted)
                              await save(
                                rows.where((x) => x['id'] != r['id']).toList(),
                              );
                            return;
                          }
                          final replacement = {...r};
                          if (action == 'pause')
                            replacement['paused'] = r['paused'] != true;
                          if (action == 'changed') {
                            final old = DateTime.parse(r['start'] as String);
                            replacement['start'] = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              old.hour,
                              old.minute,
                            ).toIso8601String();
                          }
                          await save([
                            for (final x in rows)
                              x['id'] == r['id'] ? replacement : x,
                          ]);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(tr('ویرایش')),
                          ),
                          PopupMenuItem(
                            value: 'pause',
                            child: Text(
                              r['paused'] == true
                                  ? tr('فعال‌سازی')
                                  : tr('توقف موقت'),
                            ),
                          ),
                          if (k == 'car')
                            PopupMenuItem(
                              value: 'changed',
                              child: Text(tr('تعویض شد')),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(tr('حذف')),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
      ],
    );
  }
}
