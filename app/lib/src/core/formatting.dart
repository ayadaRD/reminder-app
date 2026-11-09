part of '../../main.dart';

String fa(Object value) => isEnglish
    ? value.toString()
    : value.toString().replaceAllMapped(
        RegExp('[0-9]'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)],
      );
int? number(String? value) {
  var s = value ?? '';
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i').replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i');
  }
  return int.tryParse(s.trim());
}

String date(DateTime d) => fa(
  Jalali.fromDateTime(d).formatter.yyyy +
      '/' +
      Jalali.fromDateTime(d).formatter.mm +
      '/' +
      Jalali.fromDateTime(d).formatter.dd,
);
String clock(DateTime d) => fa(
  '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
);
