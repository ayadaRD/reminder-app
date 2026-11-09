part of '../../main.dart';

class SolarPicker extends StatefulWidget {
  final DateTime initial;
  const SolarPicker({super.key, required this.initial});
  @override
  State<SolarPicker> createState() => _SolarPicker();
}

class _SolarPicker extends State<SolarPicker> {
  late Jalali j = Jalali.fromDateTime(widget.initial);
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('انتخاب تاریخ شمسی')),
    content: SizedBox(
      width: 290,
      child: SingleChildScrollView(
        child: Column(
          children: [
            DropdownButton<int>(
              isExpanded: true,
              value: j.year,
              items: [
                for (var y = 1250; y <= 1500; y++)
                  DropdownMenuItem(value: y, child: Text(fa(y))),
              ],
              onChanged: (y) => change(y!, j.month, j.day),
            ),
            DropdownButton<int>(
              isExpanded: true,
              value: j.month,
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(
                    value: m,
                    child: Text(solarMonth(Jalali(j.year, m))),
                  ),
              ],
              onChanged: (m) => change(j.year, m!, j.day),
            ),
            DropdownButton<int>(
              isExpanded: true,
              value: j.day,
              items: [
                for (var d = 1; d <= j.monthLength; d++)
                  DropdownMenuItem(value: d, child: Text(fa(d))),
              ],
              onChanged: (d) => change(j.year, j.month, d!),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr('لغو')),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, j.toDateTime()),
        child: Text(tr('انتخاب')),
      ),
    ],
  );
  void change(int y, int m, int d) => setState(
    () => j = Jalali(y, m, d.clamp(1, Jalali(y, m).monthLength).toInt()),
  );
}
