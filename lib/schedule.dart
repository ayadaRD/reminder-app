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
    for (var d = DateTime(from.year, from.month, from.day, start.hour, start.minute);
        d.isBefore(until); d = day(d, 1)) {
      if (d.isBefore(start)) continue;
      for (var i = 0; i < (r['cups'] as int); i++) {
        final e = make(d.add(Duration(minutes: n * i)), 'وقت یک لیوان آب است', ring: true);
        if (e != null) yield e;
      }
    }
    return;
  }
  if (kind == 'medicine') {
    final step = Duration(hours: n);
    final elapsed = from.difference(start).inMilliseconds;
    final first = elapsed <= 0 ? 0 : (elapsed + step.inMilliseconds - 1) ~/ step.inMilliseconds;
    for (var t = start.add(step * first); t.isBefore(until); t = t.add(step)) {
      if (end != null && t.isAfter(end)) break;
      final e = make(t, 'نوبت مصرف «$title»', ring: true);
      if (e != null) yield e;
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
