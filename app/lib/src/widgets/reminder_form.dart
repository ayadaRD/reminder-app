part of '../../main.dart';

const _customReminderIcons = <String, IconData>{
  'bookmark': Icons.bookmark_border_rounded,
  'star': Icons.star_outline_rounded,
  'work': Icons.work_outline_rounded,
  'book': Icons.menu_book_outlined,
  'fitness': Icons.fitness_center_rounded,
  'shopping': Icons.shopping_bag_outlined,
};

class ReminderForm extends StatefulWidget {
  const ReminderForm({
    super.key,
    this.row,
    this.isActive = true,
    required this.busy,
    required this.onSave,
    required this.customReminders,
    required this.onCalendar,
    required this.onOpenCustom,
    required this.onDeleteCustom,
  });

  final bool isActive;
  final Reminder? row;
  final bool busy;
  final Future<void> Function(Reminder) onSave;
  final List<Reminder> customReminders;
  final VoidCallback onCalendar;
  final ValueChanged<Reminder> onOpenCustom;
  final Future<void> Function(Reminder) onDeleteCustom;

  @override
  State<ReminderForm> createState() => _ReminderForm();
}

class _ReminderForm extends State<ReminderForm> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final note = TextEditingController();
  final interval = TextEditingController(text: '1');
  final cups = TextEditingController(text: '8');

  late String _draftId;

  String? kind;
  String unit = 'once';
  String waterUnit = 'minute';
  String medicineUnit = 'hour';
  String type = 'قرص';
  String love = 'year';
  String _customIcon = 'bookmark';

  DateTime start = DateTime.now().add(const Duration(minutes: 5));
  DateTime? end;

  int lead = 3;
  int _customColor = 0xffddd5f3;

  bool alarm = false;
  bool show = true;
  bool repeat = false;
  bool waterRepeat = false;
  bool medicineEveryDay = true;

  bool _showCategories = false;
  bool _waterStartNow = false;
  bool _medicineStartNow = false;
  bool _medicineCustomInterval = false;
  bool _paused = false;

  Set<int> medicineDays = <int>{};

  String _text(String persian, String english) =>
      isEnglish ? english : persian;

  ColorScheme get _colors => kind == 'custom'
      ? ColorScheme.fromSeed(
          seedColor: Color(_customColor),
          brightness: Brightness.light,
        )
      : Theme.of(context).colorScheme;

  int get _waterIntervalMax => switch (waterUnit) {
        'second' => 86400,
        'hour' => 24,
        _ => 1440,
      };

  int get _medicineIntervalMax =>
      medicineUnit == 'minute' ? 1440 : 168;

  @override
  void initState() {
    super.initState();

    final r = widget.row;
    _draftId = r?['id']?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();

    if (r != null) {
      kind = r['kind'] as String?;
      unit = r['unit'] as String? ?? 'once';
      love = r['love'] as String? ?? 'year';
      type = r['type'] as String? ?? 'قرص';

      title.text = r['title'] as String? ?? '';
      note.text = r['note'] as String? ?? '';
      interval.text = '${r['n'] ?? 1}';
      cups.text = '${r['cups'] ?? 8}';

      start = DateTime.parse(r['start'] as String);
      end = r['end'] == null
          ? null
          : DateTime.parse(r['end'] as String);

      lead = (r['lead'] as num?)?.toInt() ?? 3;
      alarm = r['alarm'] == true;
      show = r['calendar'] != false;
      repeat = unit != 'once';
      _paused = r['paused'] == true;

      waterRepeat = r['waterRepeat'] == true;
      final savedWaterUnit = r['waterUnit'];
      waterUnit = ['second', 'minute', 'hour'].contains(savedWaterUnit)
          ? savedWaterUnit as String
          : 'minute';

      medicineUnit = r['medicineUnit'] == 'minute' ? 'minute' : 'hour';
      medicineEveryDay = r['medicineEveryDay'] != false;
      medicineDays = medicineWeekdays(r);

      _customColor =
          (r['customColor'] as num?)?.toInt() ?? 0xffddd5f3;

      final savedIcon = r['customIcon'];
      _customIcon = savedIcon is String &&
              _customReminderIcons.containsKey(savedIcon)
          ? savedIcon
          : 'bookmark';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      categoryPickerVisible.value = kind == null || _showCategories;
    });
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    interval.dispose();
    cups.dispose();
    super.dispose();
  }

  void choose(String category, {bool createNew = false}) {
    if (widget.busy) return;

    void openForm() {
      if (!mounted) return;

      categoryPickerVisible.value = false;

      if (category == kind && !createNew) {
        setState(() => _showCategories = false);
        return;
      }

      final now = DateTime.now();

      setState(() {
        kind = category;
        _showCategories = false;
        _paused = false;
        _draftId = now.microsecondsSinceEpoch.toString();

        title.clear();
        note.clear();

        _customColor = 0xffddd5f3;
        _customIcon = 'bookmark';

        cups.text = '8';
        waterUnit = category == 'water' ? 'hour' : 'minute';
        waterRepeat = false;
        _waterStartNow = false;

        medicineUnit = 'hour';
        medicineEveryDay = true;
        medicineDays = <int>{};
        _medicineStartNow = false;
        _medicineCustomInterval = false;

        interval.text = switch (category) {
          'water' => '3',
          'medicine' => '8',
          _ => '1',
        };

        unit = switch (category) {
          'car' => 'month',
          'plant' => 'day',
          _ => 'once',
        };

        type = 'قرص';
        love = 'year';
        lead = 3;
        alarm = false;
        end = null;
        repeat = false;
        show = true;

        start = ['medicine', 'custom'].contains(category)
            ? now.add(const Duration(minutes: 5))
            : DateTime(
                now.year,
                now.month,
                now.day,
                category == 'water' ? 8 : 9,
              );
      });
    }

    final reveal = context.findAncestorStateOfType<_ThemeRevealState>();

    if (reveal != null && selectedTheme.value != category) {
      reveal.changeTo(category, onChange: openForm);
    } else {
      selectedTheme.value = category;
      openForm();
    }
  }

  Reminder value() {
    final mode = kind == 'love' && love != 'custom' ? love : unit;

    final maximumInterval = switch (kind) {
      'water' => _waterIntervalMax,
      'medicine' => _medicineIntervalMax,
      _ => 1440,
    };

    final selectedDays = medicineDays.toList()..sort();

    return {
      'id': _draftId,
      'kind': kind,
      'title': kind == 'water' ? 'آب خوردن' : title.text.trim(),
      'note': note.text.trim(),
      'start': start.toIso8601String(),
      'end': end?.toIso8601String(),
      'alarm': ['water', 'medicine'].contains(kind) ||
          (kind != 'car' && alarm),
      'calendar': show,
      'n': (number(interval.text) ?? 1)
          .clamp(1, maximumInterval)
          .toInt(),
      'unit': mode,
      'lead': lead,
      'type': type,
      'love': love,
      'cups': (number(cups.text) ?? 8).clamp(1, 24).toInt(),
      'waterUnit': waterUnit,
      'waterRepeat': waterRepeat,
      'medicineUnit': medicineUnit,
      'medicineEveryDay': medicineEveryDay,
      'medicineDays': selectedDays,
      'paused': _paused,
      if (kind == 'custom') 'customColor': _customColor,
      if (kind == 'custom') 'customIcon': _customIcon,
    };
  }

  Future<void> pickDate(bool finish) async {
    if (widget.busy) return;

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => SolarPicker(
        initial: finish ? (end ?? start) : start,
      ),
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (finish) {
        end = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
          999,
          999,
        );
      } else {
        _waterStartNow = false;
        _medicineStartNow = false;
        start = DateTime(
          picked.year,
          picked.month,
          picked.day,
          start.hour,
          start.minute,
        );
      }
    });
  }

  Future<void> pickTime() async {
    if (widget.busy) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _waterStartNow = false;
      _medicineStartNow = false;
      start = DateTime(
        start.year,
        start.month,
        start.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _useNow() {
    if (widget.busy) return;

    FocusScope.of(context).unfocus();
    final now = DateTime.now();

    setState(() {
      _waterStartNow = kind == 'water';
      _medicineStartNow = kind == 'medicine';
      start = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
      );
    });
  }

  void _backToCategories() {
    if (widget.busy) return;
    FocusScope.of(context).unfocus();

    void showCategories() {
      if (!mounted) return;
      categoryPickerVisible.value = true;
      setState(() => _showCategories = true);
    }

    final reveal = context.findAncestorStateOfType<_ThemeRevealState>();

    if (reveal != null && selectedTheme.value != null) {
      reveal.changeTo(null, onChange: showCategories);
    } else {
      selectedTheme.value = null;
      showCategories();
    }
  }

  Future<void> _submitReminder() async {
    if (widget.busy) return;
    if (!(form.currentState?.validate() ?? false)) return;

    void error(String persian, String english) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text(persian, english))),
      );
    }

    if (kind == 'medicine' &&
        !medicineEveryDay &&
        medicineDays.isEmpty) {
      error(
        'حداقل یک روز هفته رو انتخاب کن.',
        'Choose at least one weekday.',
      );
      return;
    }

    final immediate = (kind == 'water' && _waterStartNow) ||
        (kind == 'medicine' && _medicineStartNow);

    if (immediate) {
      final now = DateTime.now();
      start = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
      );
    }

    if (end?.isBefore(start) ?? false) {
      setState(() {});
      error(
        'تاریخ پایان باید بعد از شروع باشد.',
        'The end date must be after the start.',
      );
      return;
    }

    final custom =
        kind == 'custom' || (kind == 'love' && love == 'custom');

    if (custom && unit == 'once' && start.isBefore(DateTime.now())) {
      error(
        'زمان یادآوری یک‌باره باید در آینده باشد.',
        'Choose a future time for a one-time reminder.',
      );
      return;
    }

    final reminder = value();
    reminder['startNow'] = immediate;

    if (kind == 'medicine' && !_paused) {
      final from = immediate ? start : DateTime.now();
      final next = events(reminder, from, day(from, 405))
          .where((event) => !event.calendar);

      if (next.isEmpty) {
        error(
          'با این فاصله، روزهای انتخابی و تاریخ پایان، نوبتی پیدا نشد.',
          'No occurrence matches the interval, weekdays and end date.',
        );
        return;
      }
    }

    FocusScope.of(context).unfocus();
    await widget.onSave(reminder);
  }

  Widget field(
    TextEditingController controller,
    String label, {
    bool mandatory = true,
    bool numeric = false,
    int max = 365,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !widget.busy,
      onChanged: (_) => setState(() {}),
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (input) {
        if (mandatory && (input ?? '').trim().isEmpty) {
          return tr('این فیلد را کامل کن');
        }

        final parsed = number(input) ?? 0;

        if (numeric && (parsed < 1 || parsed > max)) {
          return _text(
            'عددی از ۱ تا ${fa(max)} وارد کن',
            'Enter a number from 1 to $max',
          );
        }

        return null;
      },
    );
  }

  Widget drop<T>(
    String label,
    T? current,
    Map<T, String> options,
    ValueChanged<T?> change,
  ) {
    return DropdownButtonFormField<T>(
      key: ValueKey('$label:$current'),
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options.entries)
          DropdownMenuItem(
            value: option.key,
            child: Text(option.value),
          ),
      ],
      onChanged: widget.busy ? null : change,
    );
  }

  Widget _caption(String persian, String english) {
    return Text(
      _text(persian, english),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _colors.onSurface.withValues(alpha: 0.65),
            fontWeight: FontWeight.w500,
          ),
    );
  }

  Widget _formCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
      child: child,
    );
  }

  ButtonStyle get _dateButtonStyle => OutlinedButton.styleFrom(
        foregroundColor: _colors.onSurface,
        backgroundColor: Colors.white.withValues(alpha: 0.60),
        side: BorderSide(
          color: _colors.primary.withValues(alpha: 0.22),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      );

  Widget _endDateControl() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: _dateButtonStyle,
            onPressed: widget.busy ? null : () => pickDate(true),
            icon: const Icon(Icons.event_available_outlined, size: 18),
            label: Text(
              end == null
                  ? _text('پایان · اختیاری', 'End · optional')
                  : '${_text("تا", "Until")} ${date(end!)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        if (end != null)
          IconButton(
            tooltip: _text('حذف تاریخ پایان', 'Remove end date'),
            onPressed:
                widget.busy ? null : () => setState(() => end = null),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
      ],
    );
  }

  Widget _startControls({
    bool allowNow = false,
    bool allowEnd = false,
    bool compact = false,
  }) {
    final colors = _colors;

    final dateButton = OutlinedButton.icon(
      style: _dateButtonStyle,
      onPressed: widget.busy ? null : () => pickDate(false),
      icon: Icon(
        Icons.calendar_today_outlined,
        size: 18,
        color: colors.primary,
      ),
      label: Text(
        date(start),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
      ),
    );

    final timeButton = OutlinedButton.icon(
      style: _dateButtonStyle,
      onPressed: widget.busy ? null : pickTime,
      icon: Icon(Icons.schedule_rounded, size: 19, color: colors.primary),
      label: Text(clock(start), style: const TextStyle(fontSize: 12)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caption('شروع یادآوری از', 'Start reminders from'),
        const SizedBox(height: 12),
        if (compact)
          Row(
            children: [
              Expanded(flex: 3, child: dateButton),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: timeButton),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: kind == 'water'
                  ? WrapAlignment.center
                  : WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                dateButton,
                timeButton,
                if (allowNow)
                  TextButton(
                    onPressed: widget.busy ? null : _useNow,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      backgroundColor: colors.primary.withValues(
                        alpha: _waterStartNow || _medicineStartNow
                            ? 0.20
                            : 0.10,
                      ),
                      minimumSize: const Size(60, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _text('الان', 'NOW'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (allowEnd) ...[
          const SizedBox(height: 10),
          _endDateControl(),
        ],
      ],
    );
  }

  Widget _switchTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = _colors;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colors.onSurface,
        ),
      ),
      value: value,
      activeThumbColor: colors.primary,
      activeTrackColor: colors.primary.withValues(alpha: 0.22),
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: colors.onSurface.withValues(alpha: 0.10),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      onChanged: widget.busy ? null : onChanged,
    );
  }

  Widget _waterCupsStepper() {
    final count = (number(cups.text) ?? 8).clamp(1, 24).toInt();
    final colors = _colors;

    Widget button(int delta, IconData icon, String label) {
      final enabled = !widget.busy &&
          (delta < 0 ? count > 1 : count < 24);

      return SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          tooltip: label,
          onPressed: enabled
              ? () {
                  setState(() {
                    cups.text = (count + delta).clamp(1, 24).toString();
                  });
                }
              : null,
          style: IconButton.styleFrom(
            backgroundColor: colors.primary.withValues(alpha: 0.09),
            foregroundColor: colors.primary,
            disabledBackgroundColor:
                colors.primary.withValues(alpha: 0.04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: Icon(icon, size: 23),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caption('لیوان در روز', 'Glasses per day'),
        const SizedBox(height: 14),
        Row(
          textDirection: TextDirection.ltr,
          children: [
            button(
              -1,
              Icons.remove_rounded,
              _text('کاهش تعداد لیوان', 'Fewer glasses'),
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                label: _text('لیوان در روز', 'Glasses per day'),
                value: fa(count),
                child: ExcludeSemantics(
                  child: Text(
                    fa(count),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            button(
              1,
              Icons.add_rounded,
              _text('افزایش تعداد لیوان', 'More glasses'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _intervalPicker({required bool medicine}) {
    final colors = _colors;
    final selectedUnit = medicine ? medicineUnit : waterUnit;
    final maximum = medicine ? _medicineIntervalMax : _waterIntervalMax;
    final amount = (number(interval.text) ?? 1).clamp(1, maximum).toInt();

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 144,
            child: Stack(
              alignment: Alignment.center,
              children: [
                IgnorePointer(
                  child: Container(
                    height: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                ),
                _WaterIntervalWheel(
                  unit: '${medicine ? "medicine" : "water"}:$selectedUnit',
                  value: amount,
                  maximum: maximum,
                  enabled: !widget.busy,
                  color: colors.onSurface,
                  semanticLabel: _text(
                    'فاصلهٔ یادآوری',
                    'Reminder interval',
                  ),
                  onChanged: (value) {
                    setState(() => interval.text = '$value');
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.18),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedUnit,
              borderRadius: BorderRadius.circular(17),
              dropdownColor: colors.surface,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.primary,
                size: 20,
              ),
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              items: [
                if (!medicine)
                  DropdownMenuItem(
                    value: 'second',
                    child: Text(_text('ثانیه', 'SEC')),
                  ),
                DropdownMenuItem(
                  value: 'minute',
                  child: Text(_text('دقیقه', 'MIN')),
                ),
                DropdownMenuItem(
                  value: 'hour',
                  child: Text(_text('ساعت', 'HOUR')),
                ),
              ],
              onChanged: widget.busy
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        if (medicine) {
                          medicineUnit = value;
                        } else {
                          waterUnit = value;
                        }

                        final newMaximum = medicine
                            ? _medicineIntervalMax
                            : _waterIntervalMax;

                        interval.text =
                            amount.clamp(1, newMaximum).toString();
                      });
                    },
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _waterFields() {
    return [
      _waterCupsStepper(),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _caption('فاصله بین هر لیوان', 'Time between glasses'),
          const SizedBox(height: 12),
          _intervalPicker(medicine: false),
        ],
      ),
      _startControls(allowNow: true),
      _switchTile(
        label: _text('تکرار روزانه', 'Repeat daily'),
        value: waterRepeat,
        onChanged: (enabled) => setState(() => waterRepeat = enabled),
      ),
    ];
  }

  Widget _medicineTypePicker() {
    const options = <String, String>{
      'قرص': 'Tablet',
      'کپسول': 'Capsule',
      'شربت': 'Syrup',
      'پماد': 'Ointment',
      'کرم': 'Cream',
      'آمپول': 'Injection',
      'قطره': 'Drops',
      'سایر': 'Other',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caption('نوع دارو', 'Medicine type'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options.entries)
              ChoiceChip(
                label: Text(_text(option.key, option.value)),
                selected: type == option.key,
                showCheckmark: false,
                backgroundColor: Colors.white.withValues(alpha: 0.55),
                selectedColor: _colors.primary.withValues(alpha: 0.14),
                side: BorderSide(
                  color: _colors.primary.withValues(
                    alpha: type == option.key ? 0.35 : 0.12,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: type == option.key
                      ? _colors.primary
                      : _colors.onSurface,
                  fontWeight: type == option.key
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
                onSelected: widget.busy
                    ? null
                    : (_) => setState(() => type = option.key),
              ),
          ],
        ),
      ],
    );
  }

  Widget _medicineSchedulePicker() {
    const presets = <int, int>{1: 24, 2: 12, 3: 8, 4: 6, 6: 4};

    final amount = number(interval.text) ?? 1;
    final minutes = medicineUnit == 'minute' ? amount : amount * 60;
    int? matchingCount;

    for (final entry in presets.entries) {
      if (entry.value * 60 == minutes) matchingCount = entry.key;
    }

    final customMode = _medicineCustomInterval || matchingCount == null;
    final selectedCount = customMode ? null : matchingCount;
    final selectedHours =
        selectedCount == null ? null : presets[selectedCount];

    final preview = selectedCount == null
        ? <DateTime>[]
        : medicineOccurrences(
            {...value(), 'paused': false},
            start,
            DateTime(start.year, start.month + 1, start.day),
            limit: selectedCount,
          ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caption('برنامهٔ مصرف', 'Schedule'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in presets.entries)
              ChoiceChip(
                label: Text(
                  _text('${fa(entry.key)} بار در روز', '${entry.key}/day'),
                ),
                selected: selectedCount == entry.key,
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: widget.busy
                    ? null
                    : (_) {
                        setState(() {
                          _medicineCustomInterval = false;
                          medicineUnit = 'hour';
                          interval.text = '${entry.value}';
                        });
                      },
              ),
            ChoiceChip(
              label: Text(_text('دلخواه', 'Custom')),
              selected: customMode,
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: widget.busy
                  ? null
                  : (_) {
                      setState(() => _medicineCustomInterval = true);
                    },
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (customMode) ...[
          _caption('فاصلهٔ مصرف', 'Time between doses'),
          const SizedBox(height: 8),
          _intervalPicker(medicine: true),
        ] else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _colors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _colors.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 18,
                      color: _colors.primary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _text(
                          'هر ${fa(selectedHours!)} ساعت',
                          'Every $selectedHours hours',
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _caption('نوبت‌های ابتدایی', 'First doses'),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final time in preview)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            DateUtils.isSameDay(time, start)
                                ? clock(time)
                                : '${date(time)} · ${clock(time)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 9),
                Text(
                  _text(
                    'ساعت‌ها بر اساس زمان شروع و روزهای انتخابی تنظیم می‌شوند.',
                    'Times follow your selected start and weekdays.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _medicineWeekdayPicker() {
    const days = [
      (6, 'شنبه', 'Sat'),
      (7, 'یکشنبه', 'Sun'),
      (1, 'دوشنبه', 'Mon'),
      (2, 'سه‌شنبه', 'Tue'),
      (3, 'چهارشنبه', 'Wed'),
      (4, 'پنجشنبه', 'Thu'),
      (5, 'جمعه', 'Fri'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _switchTile(
          label: _text('هر روز', 'Every day'),
          value: medicineEveryDay,
          onChanged: (enabled) {
            setState(() => medicineEveryDay = enabled);
          },
        ),
        if (!medicineEveryDay) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final day in days)
                FilterChip(
                  label: Text(_text(day.$2, day.$3)),
                  selected: medicineDays.contains(day.$1),
                  showCheckmark: false,
                  selectedColor: _colors.primary.withValues(alpha: 0.14),
                  backgroundColor: Colors.white.withValues(alpha: 0.55),
                  side: BorderSide(
                    color: _colors.primary.withValues(
                      alpha: medicineDays.contains(day.$1) ? 0.35 : 0.12,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: widget.busy
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected) {
                              medicineDays.add(day.$1);
                            } else {
                              medicineDays.remove(day.$1);
                            }
                          });
                        },
                ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _medicineFields() => [
        _medicineTypePicker(),
        field(title, tr('نام دارو')),
        field(
          note,
          tr('یادداشت مصرف (اختیاری)'),
          mandatory: false,
        ),
        _startControls(allowNow: true, allowEnd: true),
        _medicineSchedulePicker(),
        _medicineWeekdayPicker(),
      ];

  Widget _customColorPicker() {
    const options = [
      (0xffddd5f3, 'یاسی', 'Lilac'),
      (0xffcce7f5, 'آبی', 'Blue'),
      (0xffcfe9dd, 'سبز', 'Green'),
      (0xfff5d5df, 'صورتی', 'Pink'),
      (0xfff5ddc9, 'هلویی', 'Peach'),
      (0xfff2e7bb, 'زرد', 'Yellow'),
      (0xffcce8e7, 'فیروزه‌ای', 'Teal'),
      (0xffdfdfee, 'اسطوخودوسی', 'Lavender'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caption('رنگ دسته‌بندی', 'Category color'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              Semantics(
                button: true,
                selected: _customColor == option.$1,
                label: _text(option.$2, option.$3),
                child: Tooltip(
                  message: _text(option.$2, option.$3),
                  child: Material(
                    color: Color(option.$1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: _customColor == option.$1
                            ? const Color(0xff51465f)
                            : Colors.white.withValues(alpha: 0.8),
                        width: _customColor == option.$1 ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.busy
                          ? null
                          : () => setState(() => _customColor = option.$1),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: _customColor == option.$1
                            ? const Icon(
                                Icons.check_rounded,
                                size: 23,
                                color: Color(0xff51465f),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _customIconPicker() {
    const labels = {
      'bookmark': ('نشانک', 'Bookmark'),
      'star': ('ستاره', 'Star'),
      'work': ('کار', 'Work'),
      'book': ('مطالعه', 'Reading'),
      'fitness': ('ورزش', 'Exercise'),
      'shopping': ('خرید', 'Shopping'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caption('آیکون', 'Icon'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _customReminderIcons.entries)
              Semantics(
                button: true,
                selected: _customIcon == entry.key,
                label: _text(
                  labels[entry.key]!.$1,
                  labels[entry.key]!.$2,
                ),
                child: Tooltip(
                  message: _text(
                    labels[entry.key]!.$1,
                    labels[entry.key]!.$2,
                  ),
                  child: Material(
                    color: _customIcon == entry.key
                        ? Color(_customColor)
                        : Colors.white.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: _colors.primary.withValues(
                          alpha: _customIcon == entry.key ? 0.50 : 0.12,
                        ),
                        width: _customIcon == entry.key ? 1.5 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.busy
                          ? null
                          : () => setState(() => _customIcon = entry.key),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          entry.value,
                          size: 23,
                          color: _colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _customToggles() {
    Widget toggle(
      String label,
      bool current,
      ValueChanged<bool> onChanged,
    ) {
      return Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: _colors.onSurface,
              ),
            ),
          ),
          Switch(
            value: current,
            activeThumbColor: _colors.primary,
            activeTrackColor: _colors.primary.withValues(alpha: 0.22),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor:
                _colors.onSurface.withValues(alpha: 0.10),
            trackOutlineColor:
                const WidgetStatePropertyAll(Colors.transparent),
            onChanged: widget.busy ? null : onChanged,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: toggle(
            _text('تکرار', 'Repeat'),
            repeat,
            (enabled) {
              setState(() {
                repeat = enabled;
                unit = enabled ? 'day' : 'once';
                if (!enabled) end = null;
              });
            },
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 1,
          height: 30,
          color: _colors.primary.withValues(alpha: 0.12),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: toggle(
            _text('نمایش در تقویم', 'Show on calendar'),
            show,
            (enabled) => setState(() => show = enabled),
          ),
        ),
      ],
    );
  }

  Widget _customMethodPicker() {
    Widget option(bool isAlarm, IconData icon, String label) {
      final selected = alarm == isAlarm;

      return Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected
              ? _colors.primary.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: _colors.primary.withValues(
                alpha: selected ? 0.45 : 0.12,
              ),
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.busy
                ? null
                : () => setState(() => alarm = isAlarm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 17,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 25,
                    color: selected
                        ? _colors.primary
                        : _colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? _colors.primary
                          : _colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caption('روش یادآوری', 'Reminder method'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: option(
                false,
                Icons.notifications_none_rounded,
                _text('اعلان', 'Notification'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: option(
                true,
                Icons.alarm_rounded,
                _text('آلارم', 'Alarm'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _repeatControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caption('فاصلهٔ تکرار', 'Repeat every'),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: field(
                interval,
                _text('تعداد', 'Number'),
                numeric: true,
                max: unit == 'year' ? 20 : 365,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: drop<String>(
                _text('واحد', 'Unit'),
                unit,
                {
                  for (final entry in units.entries)
                    if (entry.key != 'once') entry.key: tr(entry.value),
                },
                (selected) {
                  if (selected == null) return;
                  setState(() {
                    unit = selected;
                    final maximum = unit == 'year' ? 20 : 365;
                    interval.text = (number(interval.text) ?? 1)
                        .clamp(1, maximum)
                        .toInt()
                        .toString();
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _customFields() => [
        field(title, _text('نام یادآور', 'Reminder name')),
        _customIconPicker(),
        _customColorPicker(),
        _startControls(compact: true, allowEnd: repeat),
        _customToggles(),
        if (repeat) _repeatControls(),
        _customMethodPicker(),
      ];

  List<Widget> _fields(String category, {required bool custom}) {
    if (category == 'water') return _waterFields();
    if (category == 'medicine') return _medicineFields();
    if (category == 'custom') return _customFields();

    final cadence =
        category == 'car' || category == 'plant' || (custom && repeat);

    final dateLabel = tr(
      switch (category) {
        'birthday' => 'تاریخ تولد',
        'memorial' => 'تاریخ فوت',
        'car' => 'آخرین تعویض',
        'love' => 'تاریخ مبنا',
        _ => 'تاریخ شروع',
      },
    );

    return [
      if (category == 'love')
        drop<String>(
          tr('مناسبت'),
          love,
          {
            'year': tr('سالگرد'),
            'month': tr('ماهگرد'),
            'week': tr('هفته‌گرد'),
            'custom': tr('مناسبت دلخواه'),
          },
          (v) {
            if (v == null) return;
            setState(() {
              love = v;
              unit = 'once';
              repeat = false;
              end = null;
            });
          },
        ),
      field(
        title,
        tr(
          switch (category) {
            'birthday' => 'نام فرد',
            'memorial' => 'نام عزیز',
            'car' => 'نام قطعه',
            'plant' => 'نام گیاه',
            _ => 'عنوان',
          },
        ),
      ),
      if (category == 'birthday') field(note, tr('نسبت')),
      OutlinedButton.icon(
        onPressed: widget.busy ? null : () => pickDate(false),
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text('$dateLabel · ${date(start)}'),
      ),
      OutlinedButton.icon(
        onPressed: widget.busy ? null : pickTime,
        icon: const Icon(Icons.schedule),
        label: Text('${tr("ساعت")} · ${clock(start)}'),
      ),
      if (custom)
        _switchTile(
          label: tr('تکرار شود'),
          value: repeat,
          onChanged: (v) {
            setState(() {
              repeat = v;
              unit = v ? 'day' : 'once';
              if (!v) end = null;
            });
          },
        ),
      if (cadence) ...[
        field(
          interval,
          tr('فاصلهٔ تکرار'),
          numeric: true,
          max: unit == 'year' ? 20 : 365,
        ),
        drop<String>(
          tr('واحد فاصله'),
          unit,
          {
            for (final item in units.entries)
              if (item.key != 'once') item.key: tr(item.value),
          },
          (v) {
            if (v != null) setState(() => unit = v);
          },
        ),
      ],
      if (custom && repeat) _endDateControl(),
      if (category == 'love' && love == 'month')
        drop<int>(
          tr('چند روز قبل؟'),
          lead,
          {2: tr('۲ روز'), 3: tr('۳ روز')},
          (v) {
            if (v != null) setState(() => lead = v);
          },
        ),
      if (category == 'car')
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('روش یادآوری · اعلان')),
        )
      else
        drop<bool>(
          tr('روش یادآوری'),
          alarm,
          {false: tr('اعلان'), true: tr('آلارم')},
          (v) {
            if (v != null) setState(() => alarm = v);
          },
        ),
    ];
  }

  Widget _categorySelector() {
    return _ReminderCards(
      saved: widget.customReminders,
      busy: widget.busy,
      onCalendar: widget.onCalendar,
      onChoose: choose,
      onOpen: widget.onOpenCustom,
      onCreate: () => choose('custom', createNew: true),
      onDelete: widget.onDeleteCustom,
    );
  }

  IconData _formIcon(String category) => switch (category) {
        'water' => Icons.water_drop_outlined,
        'medicine' => Icons.medication_outlined,
        'birthday' => Icons.cake_outlined,
        'love' => Icons.favorite_border_rounded,
        'plant' => Icons.eco_outlined,
        'car' => Icons.directions_car_outlined,
        'memorial' => Icons.local_florist_outlined,
        'custom' => _customReminderIcons[_customIcon] ??
            Icons.bookmark_border_rounded,
        _ => Icons.bookmark_border_rounded,
      };

  ThemeData _formTheme() {
    final theme = Theme.of(context);
    final colors = _colors;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: color),
        );

    return theme.copyWith(
      colorScheme: colors,
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.60),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: TextStyle(
          color: colors.onSurface.withValues(alpha: 0.65),
          fontSize: 13,
        ),
        border: border(colors.primary.withValues(alpha: 0.18)),
        enabledBorder: border(colors.primary.withValues(alpha: 0.18)),
        focusedBorder: border(colors.primary),
        errorBorder: border(colors.error),
        focusedErrorBorder: border(colors.error),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          minimumSize: const Size(0, 52),
          side: BorderSide(
            color: colors.primary.withValues(alpha: 0.20),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: const TextStyle(fontSize: 14),
        ),
      ),
      listTileTheme: theme.listTileTheme.copyWith(
        contentPadding: EdgeInsets.zero,
        iconColor: colors.primary,
        textColor: colors.onSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = kind;

    if (category == null || _showCategories) {
      return _categorySelector();
    }

    final colors = _colors;
    final custom =
        category == 'custom' || (category == 'love' && love == 'custom');
    final invalidEnd = end?.isBefore(start) ?? false;

    final now = DateTime.now();
    final immediate = (category == 'water' && _waterStartNow) ||
        (category == 'medicine' && _medicineStartNow);

    final previewFrom = immediate ? now : now;
    final previewRow = <String, dynamic>{
      ...value(),
      if (immediate) 'start': now.toIso8601String(),
    };

    final preview = invalidEnd
        ? <Event>[]
        : (events(previewRow, previewFrom, day(now, 405))
            .where((event) => !event.calendar)
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time)));

    final background = category == 'water'
        ? const Color(0xffdceffa)
        : category == 'custom'
            ? Color(_customColor)
            : kinds[category]!.$3;

    final fields = _fields(category, custom: custom);
    final theme = _formTheme();

    final page = Theme(
      data: theme,
      child: ColoredBox(
        color: background,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Form(
                  key: form,
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 88, 20, 28),
                    children: [
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          child: Icon(
                            _formIcon(category),
                            size: 38,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr(kinds[category]!.$1),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 28),
                      for (var i = 0; i < fields.length; i++) ...[
                        _formCard(
                          padding: EdgeInsets.all(
                            category == 'water' ? 20 : 16,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: fields[i],
                          ),
                        ),
                        if (i < fields.length - 1)
                          const SizedBox(height: 14),
                      ],
                      if (invalidEnd) ...[
                        const SizedBox(height: 16),
                        _formCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: colors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tr('تاریخ پایان باید بعد از شروع باشد.'),
                                  style: TextStyle(color: colors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _formCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('نوبت‌های بعدی'),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                preview
                                    .take(category == 'medicine' ? 4 : 1)
                                    .map(
                                      (e) =>
                                          '${date(e.time)}، ${clock(e.time)}',
                                    )
                                    .join('\n'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: widget.busy || invalidEnd
                            ? null
                            : _submitReminder,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: widget.busy
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(tr('در حال ذخیره…')),
                                ],
                              )
                            : Text(
                                tr('ذخیره یادآور'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 20,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.85),
                    elevation: 2,
                    shadowColor: colors.primary.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.90),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      tooltip: _text('بازگشت', 'Back'),
                      onPressed: widget.busy ? null : _backToCategories,
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        textDirection: TextDirection.ltr,
                        size: 28,
                      ),
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return PopScope<void>(
      canPop: !widget.isActive,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !widget.isActive || widget.busy) return;
        _backToCategories();
      },
      child: page,
    );
  }
}

class _ReminderCards extends StatefulWidget {
  const _ReminderCards({
    required this.saved,
    required this.busy,
    required this.onChoose,
    required this.onOpen,
    required this.onCalendar,
    required this.onCreate,
    required this.onDelete,
  });

  final List<Reminder> saved;
  final bool busy;
  final ValueChanged<String> onChoose;
  final ValueChanged<Reminder> onOpen;
  final VoidCallback onCalendar;
  final VoidCallback onCreate;
  final Future<void> Function(Reminder) onDelete;

  @override
  State<_ReminderCards> createState() => _ReminderCardsState();
}

class _ReminderCardsState extends State<_ReminderCards> {
  static const _categories = [
    'water',
    'medicine',
    'birthday',
    'love',
    'plant',
    'car',
    'memorial',
  ];

  static const double _rowHeight = 78;
  static const double _magnification = 1.20;
  static const double _lensHeight = _rowHeight * _magnification;
  static const _ink = Color(0xff29232e);
  static const double _glassOpacity = 0.10;

  static String? _lastOpenedItemKey;

  late final FixedExtentScrollController _wheelController;
  late int _selectedIndex;
  bool _deleting = false;

  static void rememberCustom(String id) {
    _lastOpenedItemKey = 'custom:$id';
  }

  List<String> get _itemKeys => [
        for (final category in _categories) 'category:$category',
        for (final reminder in widget.saved) 'custom:${reminder['id']}',
      ];

  int _rememberedIndex() {
    final keys = _itemKeys;
    final index = _lastOpenedItemKey == null
        ? -1
        : keys.indexOf(_lastOpenedItemKey!);

    return index >= 0 ? index : keys.length ~/ 2;
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = _rememberedIndex();
    _wheelController = FixedExtentScrollController(
      initialItem: _selectedIndex,
      keepScrollOffset: false,
    );
  }

  @override
  void didUpdateWidget(covariant _ReminderCards oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldKeys = [
      for (final category in _categories) 'category:$category',
      for (final reminder in oldWidget.saved) 'custom:${reminder['id']}',
    ];
    final newKeys = _itemKeys;

    var sameOrder = oldKeys.length == newKeys.length;
    if (sameOrder) {
      for (var i = 0; i < oldKeys.length; i++) {
        if (oldKeys[i] != newKeys[i]) {
          sameOrder = false;
          break;
        }
      }
    }
    if (sameOrder) return;

    final oldIndex = _selectedIndex.clamp(0, oldKeys.length - 1).toInt();
    final matchingIndex = newKeys.indexOf(oldKeys[oldIndex]);

    _selectedIndex = matchingIndex >= 0
        ? matchingIndex
        : oldIndex.clamp(0, newKeys.length - 1).toInt();

    if (_lastOpenedItemKey != null &&
        !newKeys.contains(_lastOpenedItemKey)) {
      _lastOpenedItemKey = newKeys[_selectedIndex];
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_wheelController.hasClients) return;
      _wheelController.jumpToItem(_selectedIndex);
    });
  }

  @override
  void dispose() {
    _wheelController.dispose();
    super.dispose();
  }

  void _openCalendar() {
    if (widget.busy || _deleting) return;
    final index = _rememberedIndex();

    setState(() => _selectedIndex = index);

    if (_wheelController.hasClients) {
      _wheelController.jumpToItem(index);
    }

    widget.onCalendar();
  }

  Future<void> _deleteCustom(Reminder reminder) async {
    if (widget.busy || _deleting) return;
    setState(() => _deleting = true);

    try {
      await widget.onDelete(reminder);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Color _rowColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(
          (hsl.saturation + 0.10).clamp(0.0, 1.0).toDouble(),
        )
        .withLightness(
          (hsl.lightness - 0.025).clamp(0.0, 1.0).toDouble(),
        )
        .toColor();
  }

  Color _glassColor(Color color) => Color.alphaBlend(
        Colors.white.withValues(alpha: _glassOpacity),
        color,
      );

  IconData _categoryIcon(String category) => switch (category) {
        'water' => Icons.water_drop_outlined,
        'medicine' => Icons.medication_outlined,
        'birthday' => Icons.cake_outlined,
        'love' => Icons.favorite_border_rounded,
        'plant' => Icons.eco_outlined,
        'car' => Icons.directions_car_outlined,
        'memorial' => Icons.local_florist_outlined,
        _ => Icons.bookmark_border_rounded,
      };

  Widget _glass() => IgnorePointer(
        child: ColoredBox(
          color: Colors.white.withValues(alpha: _glassOpacity),
          child: const SizedBox.expand(),
        ),
      );

  Widget _lensButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    double iconSize = 23,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.75),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 48,
        height: 52,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(
            icon,
            textDirection: TextDirection.ltr,
            size: iconSize,
            color: _ink,
          ),
        ),
      ),
    );
  }

  Widget _floatingButton({
    required String tag,
    required String tooltip,
    required Color color,
    required IconData icon,
    required VoidCallback? onPressed,
    double iconSize = 23,
  }) {
    return SizedBox(
      width: 52,
      height: 52,
      child: FloatingActionButton(
        heroTag: tag,
        onPressed: onPressed,
        tooltip: tooltip,
        backgroundColor: color,
        foregroundColor: _ink,
        elevation: 2,
        highlightElevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.70),
          ),
        ),
        child: Icon(icon, size: iconSize),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: _rowHeight,
      child: ColoredBox(
        color: color,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 68),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 25, color: _ink),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _ink,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <
        ({
          String title,
          IconData icon,
          Color color,
          VoidCallback onSelect,
        })>[
      for (final category in _categories)
        (
          title: tr(kinds[category]!.$1),
          icon: _categoryIcon(category),
          color: _rowColor(kinds[category]!.$3),
          onSelect: () {
            _lastOpenedItemKey = 'category:$category';
            widget.onChoose(category);
          },
        ),
      for (final reminder in widget.saved)
        (
          title: reminder['title'] as String? ?? tr('یادآور دلخواه'),
          icon: _customReminderIcons[reminder['customIcon']] ??
              Icons.bookmark_border_rounded,
          color: Color(
            (reminder['customColor'] as num?)?.toInt() ?? 0xffddd5f3,
          ),
          onSelect: () {
            _lastOpenedItemKey = 'custom:${reminder['id']}';
            widget.onOpen(reminder);
          },
        ),
    ];

    final selectedIndex = _selectedIndex.clamp(0, items.length - 1).toInt();
    final selected = items[selectedIndex];
    final Reminder? selectedCustom = selectedIndex >= _categories.length
        ? widget.saved[selectedIndex - _categories.length]
        : null;

    final disabled = widget.busy || _deleting;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final headerColor = _glassColor(items.first.color);
    final footerColor = _glassColor(items.last.color);

    return LayoutBuilder(
      builder: (context, constraints) {
        final outsideHeight = ((constraints.maxHeight - _lensHeight) / 2)
            .clamp(0.0, double.infinity)
            .toDouble();

        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                Expanded(
                  child: ColoredBox(
                    color: items.first.color,
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: items.last.color,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
            ListWheelScrollView.useDelegate(
              controller: _wheelController,
              physics: disabled
                  ? const NeverScrollableScrollPhysics()
                  : const FixedExtentScrollPhysics(),
              itemExtent: _rowHeight,
              diameterRatio: 100,
              perspective: 0.001,
              useMagnifier: true,
              magnification: _magnification,
              overAndUnderCenterOpacity: 1,
              onSelectedItemChanged: (index) {
                if (_selectedIndex == index) return;
                setState(() => _selectedIndex = index);
              },
              childDelegate: ListWheelChildListDelegate(
                children: [
                  for (final item in items)
                    _buildRow(
                      context,
                      title: item.title,
                      icon: item.icon,
                      color: item.color,
                    ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: outsideHeight,
              child: _glass(),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: outsideHeight,
              child: _glass(),
            ),
            Center(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  width: double.infinity,
                  height: _lensHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.90),
                      width: 1.6,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                      stops: const [0, 0.5, 1],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _ink.withValues(alpha: 0.13),
                        blurRadius: 24,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: (constraints.maxHeight - 52) / 2,
              child: _lensButton(
                icon: Icons.chevron_right_rounded,
                iconSize: 28,
                tooltip: isEnglish
                    ? 'Open ${selected.title}'
                    : 'باز کردن ${selected.title}',
                onPressed: disabled ? null : selected.onSelect,
              ),
            ),
            if (selectedCustom != null)
              Positioned(
                left: 12,
                top: (constraints.maxHeight - 52) / 2,
                child: _lensButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: isEnglish
                      ? 'Delete custom reminder'
                      : 'حذف یادآور دلخواه',
                  onPressed: disabled
                      ? null
                      : () => _deleteCustom(selectedCustom),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  padding: EdgeInsets.only(top: topInset),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        headerColor,
                        headerColor,
                        headerColor.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.65, 1],
                    ),
                  ),
                  child: const SizedBox(
                    height: 88,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: 56,
                        child: Center(
                          child: Text(
                            'Reminder',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: bottomInset + 20,
              child: _floatingButton(
                tag: 'category-create-custom',
                tooltip: isEnglish
                    ? 'Create a custom reminder'
                    : 'ساخت یادآور دلخواه',
                color: footerColor,
                icon: Icons.add_rounded,
                iconSize: 25,
                onPressed: disabled ? null : widget.onCreate,
              ),
            ),
            Positioned(
              right: 20,
              bottom: bottomInset + 20,
              child: _floatingButton(
                tag: 'category-calendar',
                tooltip: isEnglish ? 'Calendar' : 'تقویم',
                color: footerColor,
                icon: Icons.calendar_today_outlined,
                onPressed: disabled ? null : _openCalendar,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WaterIntervalWheel extends StatefulWidget {
  const _WaterIntervalWheel({
    required this.unit,
    required this.value,
    required this.maximum,
    required this.enabled,
    required this.color,
    required this.semanticLabel,
    required this.onChanged,
  });

  final String unit;
  final int value;
  final int maximum;
  final bool enabled;
  final Color color;
  final String semanticLabel;
  final ValueChanged<int> onChanged;

  @override
  State<_WaterIntervalWheel> createState() => _WaterIntervalWheelState();
}

class _WaterIntervalWheelState extends State<_WaterIntervalWheel> {
  late final FixedExtentScrollController _controller;
  late int _current;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _current = widget.value.clamp(1, widget.maximum).toInt();
    _controller = FixedExtentScrollController(
      initialItem: _current - 1,
      keepScrollOffset: false,
    );
  }

  @override
  void didUpdateWidget(covariant _WaterIntervalWheel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.unit != oldWidget.unit ||
        widget.maximum != oldWidget.maximum ||
        widget.value != _current) {
      _current = widget.value.clamp(1, widget.maximum).toInt();
      _syncing = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (_controller.hasClients) {
          _controller.jumpToItem(_current - 1);
        }

        _syncing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _step(int delta) {
    if (!widget.enabled || !_controller.hasClients) return;

    final next = (_current + delta).clamp(1, widget.maximum).toInt();

    _controller.animateToItem(
      next - 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      value: fa(_current),
      onIncrease: widget.enabled && _current < widget.maximum
          ? () => _step(1)
          : null,
      onDecrease: widget.enabled && _current > 1
          ? () => _step(-1)
          : null,
      child: ExcludeSemantics(
        child: ListWheelScrollView.useDelegate(
          controller: _controller,
          itemExtent: 48,
          physics: widget.enabled
              ? const FixedExtentScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          diameterRatio: 1.8,
          perspective: 0.003,
          useMagnifier: true,
          magnification: 1.12,
          overAndUnderCenterOpacity: 0.35,
          onSelectedItemChanged: (index) {
            if (_syncing || !widget.enabled) return;

            final value = index + 1;
            if (value == _current) return;

            setState(() => _current = value);
            widget.onChanged(value);
          },
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: widget.maximum,
            builder: (context, index) {
              return Center(
                child: Text(
                  fa(index + 1),
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    color: widget.color,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}