import 'package:shamsi_date/shamsi_date.dart';

typedef Reminder = Map<String, dynamic>;
typedef Event = ({DateTime time, String message, bool alarm, bool calendar});

DateTime day(DateTime d, [int offset = 0]) =>
    DateTime(d.year, d.month, d.day + offset, d.hour, d.minute);
DateTime month(DateTime d, int offset) {
  final j = Jalali.fromDateTime(d);
  final index = j.year * 12 + j.month - 1 + offset;
  final first = Jalali(index ~/ 12, index % 12 + 1);
  final date = Jalali(first.year, first.month,
      j.day.clamp(1, first.monthLength).toInt()).toDateTime();
  return DateTime(date.year, date.month, date.day, d.hour, d.minute);
}

Iterable<Event> events(Reminder r, DateTime from, DateTime until) sync* {
  if (r['paused'] == true) return;
  final start = DateTime.parse(r['start'] as String);
  final end = r['end'] == null ? null : DateTime.parse(r['end'] as String);
  final title = r['title'] as String;
  final kind = r['kind'] as String;
  final n = r['n'] as int;
  final unit = r['unit'] as String;
  final alarm = r['alarm'] == true;
  Event? make(DateTime t, String message, {bool? ring, bool calendar = false}) =>
      t.isBefore(from) || !t.isBefore(until) || (end != null && t.isAfter(end))
          ? null
          : (time: t, message: message, alarm: ring ?? alarm, calendar: calendar);
if (kind == 'water') {
  final step = Duration(seconds: waterIntervalSeconds(r));
  final stepMs = step.inMilliseconds;

  final count = (r['cups'] as num).toInt().clamp(1, 24).toInt();
  final repeating = r['waterRepeat'] == true;

  final elapsed = from.difference(start).inMilliseconds;

  final firstIndex = elapsed <= 0
      ? 0
      : (elapsed + stepMs - 1) ~/ stepMs;

  // برای نمایش و تحویل نوبت بعدی، فقط یک دستهٔ کوچک می‌سازیم.
  // ادامهٔ تکرار در اندروید زمان‌بندی می‌شود.
  final endIndex = repeating ? firstIndex + count : count;

  for (var index = firstIndex; index < endIndex; index++) {
    final time = start.add(step * index);

    if (!time.isBefore(until)) break;
    if (end != null && time.isAfter(end)) break;

    final event = make(
      time,
      'وقت یک لیوان آب است',
      ring: true,
    );

    if (event != null) yield event;
  }

  return;
}
  
if (kind == 'medicine') {
  for (final time in medicineOccurrences(
    r,
    from,
    until,
    limit: 4,
  )) {
    final event = make(
      time,
      'نوبت مصرف «$title»',
      ring: true,
    );

    if (event != null) yield event;
  }

  return;
}

  final birthday = kind == 'birthday';
  final memorial = kind == 'memorial';
  final love = kind == 'love' && r['love'] != 'custom';
  final annual = birthday || memorial || (love && unit == 'year');
  final period = annual ? 'year' : unit;
  final initial = kind == 'car' || (love && ['year','month','week'].contains(unit)) ? 1 : 0;
  final calendar = kind != 'custom' || r['calendar'] == true;
  final last = day(until, 35);
  for (var i = initial; ; i++) {
    final interval = i * (annual || (love && ['month','week'].contains(unit)) ? 1 : n);
    final t = switch (period) {
      'year' => month(start, 12 * interval),
      'month' => month(start, interval),
      'week' => day(start, interval * 7),
      'day' => day(start, interval),
      _ => start,
    };
    if (!t.isBefore(last) || (end != null && t.isAfter(end))) break;
    final items = <Event?>[];
    if (birthday || memorial || (love && (unit == 'year' || unit == 'month'))) {
      items.add(make(t, title, calendar: true));
      if (birthday) {
        final first = month(t, -1);
        const messages = ['وقت انتخاب هدیه است', 'وقت دعوت مهمان‌هاست', 'وقت هماهنگی جزئیات است', 'تولد نزدیک است، آماده‌ای؟'];
        for (var w = 0; w < messages.length; w++) {
          items.add(make(day(first, 7 * w), 'تولد $title نزدیک است. ${messages[w]}'));
        }
        items.add(make(DateTime(t.year, t.month, t.day - 1, 23), 'یک ساعت دیگر تولد $title است', ring: true));
      } else if (memorial) {
        items.add(make(day(t, -2), 'دو روز دیگر سالگرد درگذشت $title است'));
      } else if (unit == 'month') {
        items.add(make(day(t, -(r['lead'] as int)), 'ماهگرد «$title» نزدیک است'));
      } else {
        items.add(make(day(t, -14), 'دو هفته تا «$title» مانده است'));
        items.add(make(day(t, -7), 'یک هفته تا «$title» مانده است'));
        items.add(make(DateTime(t.year, t.month, t.day - 1, 21), 'فردا سالگرد «$title» است'));
      }
    } else {
      items.add(make(t, title));
      if (calendar) items.add(make(t, title, calendar: true));
    }
    for (final e in items) {
      if (e != null) yield e;
    }
    if (period == 'once') break;
  }
}

int waterIntervalSeconds(Reminder reminder) {
  final amount = (reminder['n'] as num?)?.toInt() ?? 1;
  final safeAmount = amount < 1 ? 1 : amount;

  return switch (reminder['waterUnit'] ?? 'minute') {
    'second' => safeAmount,
    'hour' => safeAmount * 3600,
    _ => safeAmount * 60,
  };
}

int medicineIntervalSeconds(Reminder reminder) {
  final amount = (reminder['n'] as num?)?.toInt() ?? 1;
  final safeAmount = amount < 1 ? 1 : amount;

  return reminder['medicineUnit'] == 'minute'
      ? safeAmount * 60
      : safeAmount * 3600;
}

Set<int> medicineWeekdays(Reminder reminder) {
  if (reminder['medicineEveryDay'] != false) {
    return {1, 2, 3, 4, 5, 6, 7};
  }

  final raw = reminder['medicineDays'];

  if (raw is! List) return {};

  return raw
      .whereType<num>()
      .map((value) => value.toInt())
      .where((value) => value >= 1 && value <= 7)
      .toSet();
}

Iterable<DateTime> medicineOccurrences(
  Reminder reminder,
  DateTime from,
  DateTime until, {
  int? limit,
}) sync* {
  if (reminder['paused'] == true) return;

  final start = DateTime.parse(reminder['start'] as String);
  final end = reminder['end'] == null
      ? null
      : DateTime.parse(reminder['end'] as String);

  final allowedDays = medicineWeekdays(reminder);
  if (allowedDays.isEmpty) return;

  final step = Duration(
    seconds: medicineIntervalSeconds(reminder),
  );

  final stepUs = step.inMicroseconds;

  int indexAtOrAfter(DateTime time) {
    final elapsed = time.difference(start).inMicroseconds;

    return elapsed <= 0
        ? 0
        : (elapsed + stepUs - 1) ~/ stepUs;
  }

  var index = indexAtOrAfter(from);
  var emitted = 0;

  while (limit == null || emitted < limit) {
    final time = start.add(step * index);

    if (!time.isBefore(until)) break;
    if (end != null && time.isAfter(end)) break;

    if (!allowedDays.contains(time.weekday)) {
      final nextDay = DateTime(
        time.year,
        time.month,
        time.day + 1,
      );

      index = indexAtOrAfter(nextDay);
      continue;
    }

    yield time;
    emitted++;
    index++;
  }
}