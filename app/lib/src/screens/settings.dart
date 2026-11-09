part of '../../main.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});
  @override
  State<Settings> createState() => _Settings();
}

class _Settings extends State<Settings> with WidgetsBindingObserver {
  String sound = 'system', file = 'فایل گوشی';
  Map<dynamic, dynamic> status = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    native.invokeMethod('stopPreview');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    final next = await native.invokeMapMethod('status') ?? {};
    if (mounted)
      setState(() {
        status = next;
        sound = next['sound'] ?? 'system';
        file = next['file'] ?? 'فایل گوشی';
      });
  }

  Future<void> action(String method, [Object? argument]) async {
    try {
      await native.invokeMethod(method, argument);
      await refresh();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${tr("انجام نشد")}: $e')));
    }
  }

@override
Widget build(BuildContext context) {
  return ValueListenableBuilder<String>(
    valueListenable: appLanguage,
    builder: (context, language, child) => _buildSettings(context),
  );
}

Widget _buildSettings(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('تنظیمات'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(tr('زبان برنامه')),
          trailing: DropdownButton<String>(
            value: appLanguage.value,
            items: const [
              DropdownMenuItem(value: 'fa', child: Text('فارسی')),
              DropdownMenuItem(value: 'en', child: Text('English')),
            ],
            onChanged: (value) async {
              if (value == null || value == appLanguage.value) return;
              try {
                await native.invokeMethod<void>('setLanguage', value);
                if (mounted) appLanguage.value = value;
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${tr("انجام نشد")}: $e')),
                  );
                }
              }
            },
          ),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey(sound),
          initialValue: sound,
          decoration: InputDecoration(labelText: tr('صدای آلارم')),
          items: [
            for (final x in {
              'system': tr('زنگ گوشی'),
              'soft': tr('زنگ ملایم'),
              'bright': tr('زنگ روشن'),
              'file': tr(file),
            }.entries)
              if (x.key != 'file' || status['hasFile'] == true)
                DropdownMenuItem(
                  value: x.key,
                  child: Text(x.value, overflow: TextOverflow.ellipsis),
                ),
          ],
          isExpanded: true,
          onChanged: (v) {
            if (v != null) action('sound', v);
          },
        ),
        ListTile(
          leading: const Icon(Icons.audio_file_outlined),
          title: Text(tr('انتخاب فایل صوتی از گوشی')),
          onTap: () => action('pick'),
        ),
        ListTile(
          leading: const Icon(Icons.play_arrow),
          title: Text(tr('پخش نمونه')),
          onTap: () => action('preview'),
        ),
        for (final p in {
          'notification': tr('اعلان‌ها'),
          'exact': tr('آلارم دقیق'),
          'fullscreen': tr('نمایش آلارم روی صفحه قفل'),
        }.entries)
          ListTile(
            title: Text(p.value),
            subtitle: Text(
              status[p.key] == true ? tr('فعال') : tr('نیاز به مجوز'),
            ),
            onTap: () => action(p.key),
          ),
        ListTile(
          subtitle: Text(
            tr(
              'روی گوشی شیائومی، آلارم را با صفحهٔ قفل و پس از بستن برنامه آزمایش کن.',
            ),
          ),
        ),
      ],
    ),
  );
}
