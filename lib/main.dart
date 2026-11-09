import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'schedule.dart';

const native = MethodChannel('ir.yadavar/alarms');
const kinds = {
  'birthday': ('تولد', '🎂', Color(0xffeee3fa)),
  'water': ('آب خوردن', '💧', Color(0xffdceffa)),
  'love': ('عشق زندگی', '❤️', Color(0xfff9dfe7)),
  'car': ('خودرو', '🚗', Color(0xffffedda)),
  'memorial': ('یادبود', '🕯️', Color(0xffe9e6ef)),
  'medicine': ('دارو', '💊', Color(0xffe3eafa)),
  'plant': ('آبیاری گیاه', '🪴', Color(0xffe0efdf)),
  'custom': ('یادآور دلخواه', '⭐', Color(0xfffff0cc)),
};
const units = {'once':'یک‌بار','day':'روز','week':'هفته','month':'ماه','year':'سال'};
String fa(Object value) => value.toString().replaceAllMapped(RegExp('[0-9]'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);
int? number(String? value) {
  var s = value ?? '';
  for (var i=0;i<10;i++) {
    s=s.replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i').replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i');
  }
  return int.tryParse(s.trim());
}
String date(DateTime d) => fa(Jalali.fromDateTime(d).formatter.yyyy+'/'+Jalali.fromDateTime(d).formatter.mm+'/'+Jalali.fromDateTime(d).formatter.dd);
String clock(DateTime d) => fa('${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}');

void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('fa'),
  supportedLocales: const [Locale('fa')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData(useMaterial3:true, colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff715785)),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
  home: const Home(),
));

class Home extends StatefulWidget {
  const Home({super.key});
  @override State<Home> createState()=>_Home();
}
class _Home extends State<Home> with WidgetsBindingObserver {
  List<Reminder> rows=[];
  Map<String,dynamic> taken={};
  int tab=0, revision=0;
  Reminder? edit;
  bool loading=true, saving=false;
  String? loadError;
  DateTime cursor=DateTime.now(), selected=DateTime.now();
  @override void initState(){super.initState(); WidgetsBinding.instance.addObserver(this); load();}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed && !loading && !saving && loadError==null) load();}
  Future<void> load() async {
    try {
      final data=await native.invokeMethod<String>('load');
      final history=await native.invokeMethod<String>('history');
      final dataRows=(jsonDecode(data ?? '[]') as List).cast<Reminder>();
      if (!mounted || saving) return;
      setState(() {
        rows=dataRows;
        taken=(jsonDecode(history ?? '{}') as Map).cast<String,dynamic>();
        loading=false; loadError=null;
      });
      if(dataRows.isNotEmpty && await native.invokeMethod<bool>('needsRefresh')==true && mounted && !saving){
        await save(dataRows, quiet:true);
      }
    } catch(e) {
      if(mounted) setState(() { loading=false; loadError=e.toString(); });
    }
  }
  void message(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  Future<bool> save(List<Reminder> updated,{bool quiet=false}) async {
    if(saving) return false;
    setState(()=>saving=true);
    try {
      final now=DateTime.now();
      final scheduled=<Reminder>[];
      for(final r in updated){
        final frequent=['water','medicine'].contains(r['kind']) ||
          (r['n']==1 && ['day','week'].contains(r['unit']));
        final until=frequent ? day(now,405) : month(now,240);
        final occurrences=events(r, now, until).where((e)=>!e.calendar).toList()
          ..sort((a,b)=>a.time.compareTo(b.time));
        for(final e in occurrences){
          scheduled.add({'id':r['id'],'kind':r['kind'],'when':e.time.millisecondsSinceEpoch,
            'message':e.message,'alarm':e.alarm});
        }
      }
      final exact=await native.invokeMethod<bool>('save',{'rows':jsonEncode(updated),'events':jsonEncode(scheduled)});
      if(!mounted) return false;
      setState(()=>rows=updated);
      if(!quiet) message(exact==true ? 'ذخیره شد' : 'ذخیره شد. مجوز آلارم دقیق را در تنظیمات فعال کن.');
      return true;
    } catch(e) {if(mounted) message('خطا در ذخیره یا زمان‌بندی: $e');return false;}
    finally {if(mounted) setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor: Colors.white,
    appBar:AppBar(backgroundColor:Colors.white,title:const Text('یادآور'),
      actions:[IconButton(tooltip:'تنظیمات',onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const Settings())),icon:const Icon(Icons.settings_outlined))]),
    body:loading ? const Center(child:CircularProgressIndicator()) : loadError!=null ?
      Center(child:TextButton(onPressed:load,child:const Text('خطا در خواندن داده‌ها؛ تلاش دوباره'))) :
      IndexedStack(index:tab,children:[
        ReminderForm(key:ValueKey(revision),row:edit,busy:saving,onSave:(r) async {
          if(await save([...rows.where((x)=>x['id']!=r['id']),r]) && mounted) {
            setState(() {edit=null; revision++; tab=2;});
          }
        }),
        calendar(),
        list(),
      ]),
    bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [
      NavigationDestination(icon:Icon(Icons.add_circle_outline),label:'ثبت یادآور'),
      NavigationDestination(icon:Icon(Icons.calendar_month_outlined),label:'تقویم'),
      NavigationDestination(icon:Icon(Icons.list_alt_outlined),label:'یادآورهای من'),
    ]),
  );
  Widget calendar(){
    final j=Jalali.fromDateTime(cursor);
    final first=Jalali(j.year,j.month).toDateTime();
    final limit=month(first,1);
    final startIndex=(first.weekday+1)%7;
    final marks=<int,Set<String>>{};
    final details=<String>[];
    for(final r in rows){
      for(final e in events(r,first,limit).where((e)=>e.calendar)){
        final d=Jalali.fromDateTime(e.time).day;
        (marks[d]??=<String>{}).add(r['kind'] as String);
        if(DateUtils.isSameDay(e.time, selected)) details.add('${kinds[r['kind']]!.$2}  ${r['title']}');
      }
    }
    return ListView(padding:const EdgeInsets.all(16),children:[
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
          IconButton(tooltip:'ماه قبل',onPressed:()=>setState(()=>cursor=month(first,-1)),icon:const Icon(Icons.chevron_right)),
          Text('${j.formatter.mN} ${fa(j.year)}',style:Theme.of(context).textTheme.titleLarge),
          IconButton(tooltip:'ماه بعد',onPressed:()=>setState(()=>cursor=limit),icon:const Icon(Icons.chevron_left)),
        ]),
        Row(children:['ش','ی','د','س','چ','پ','ج'].map((d)=>Expanded(child:Center(child:Text(d)))).toList()),
        const SizedBox(height:8),
        GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:7,
          childAspectRatio:.82,children:List.generate(startIndex+j.monthLength,(i){
            final d=i-startIndex+1;
            if(d<1) return const SizedBox();
            final t=day(first,d-1);
            final icons=(marks[d]??{}).map((k)=>kinds[k]!.$2).toList();
            return InkWell(borderRadius:BorderRadius.circular(12),onTap:()=>setState(()=>selected=t),
              child:DecoratedBox(decoration:BoxDecoration(color:DateUtils.isSameDay(t,selected)?const Color(0xffeee3fa):null,borderRadius:BorderRadius.circular(12)),
                child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(fa(d)),
                  if(icons.isNotEmpty) Text(icons.length>2 ? '${icons.first}+${fa(icons.length-1)}':icons.join(),style:const TextStyle(fontSize:11))])));
          })),
      ]))),
      ListTile(title:Text(date(selected)),subtitle:Text(details.isEmpty?'مناسبتی ثبت نشده است':details.join('\n'))),
    ]);
  }
  Widget list(){
    final now=DateTime.now();
    if(rows.isEmpty) return const Center(child:Text('اولین یادآورت را ثبت کن 🌱'));
    return ListView(padding:const EdgeInsets.all(16),children:[
      for(final k in kinds.keys)
        if(rows.any((r)=>r['kind']==k)) ...[
          Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text('${kinds[k]!.$2}  ${kinds[k]!.$1}',style:Theme.of(context).textTheme.titleMedium)),
          for(final r in rows.where((r)=>r['kind']==k))
            Builder(builder:(context){
              final times=events(r,now,['water','medicine'].contains(k)?day(now,405):month(now,240)).where((e)=>!e.calendar).map((e)=>e.time).toList()..sort();
              final consumed=taken[r['id']];
              return Card(color:kinds[k]!.$3,child:ListTile(
                title:Text(r['title'] as String),
                subtitle:Text([
                  if(r['paused']==true) 'متوقف' else if(times.isEmpty) 'نوبت فعالی در بازهٔ زمان‌بندی نیست'
                  else '${date(times.first)}، ${clock(times.first)}',
                  if(k=='medicine' && consumed is int)
                    'آخرین ثبت مصرف: ${date(DateTime.fromMillisecondsSinceEpoch(consumed))}، ${clock(DateTime.fromMillisecondsSinceEpoch(consumed))}',
                  if(r['note'] is String && (r['note'] as String).isNotEmpty) r['note'] as String,
                ].join('\n')),
                trailing:PopupMenuButton<String>(enabled:!saving,onSelected:(action) async {
                  if(action=='edit'){setState((){edit=r;revision++;tab=0;});return;}
                  if(action=='delete'){
                    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
                      title:const Text('این یادآور حذف شود؟'),actions:[
                        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('لغو')),
                        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حذف')),
                      ]));
                    if(yes==true && mounted) await save(rows.where((x)=>x['id']!=r['id']).toList());
                    return;
                  }
                  final replacement={...r};
                  if(action=='pause') replacement['paused']=r['paused']!=true;
                  if(action=='changed'){
                    final old=DateTime.parse(r['start'] as String);
                    replacement['start']=DateTime(now.year,now.month,now.day,old.hour,old.minute).toIso8601String();
                  }
                  await save([for(final x in rows) x['id']==r['id']?replacement:x]);
                },itemBuilder:(_)=>[
                  const PopupMenuItem(value:'edit',child:Text('ویرایش')),
                  PopupMenuItem(value:'pause',child:Text(r['paused']==true?'فعال‌سازی':'توقف موقت')),
                  if(k=='car') const PopupMenuItem(value:'changed',child:Text('تعویض شد')),
                  const PopupMenuItem(value:'delete',child:Text('حذف')),
                ])));
            }),
        ],
    ]);
  }
}

class ReminderForm extends StatefulWidget {
  final Reminder? row;
  final bool busy;
  final Future<void> Function(Reminder) onSave;
  const ReminderForm({super.key,this.row,required this.busy,required this.onSave});
  @override State<ReminderForm> createState()=>_ReminderForm();
}
class _ReminderForm extends State<ReminderForm> {
  final form=GlobalKey<FormState>();
  String? kind;
  String unit='once', type='قرص', love='year';
  final title=TextEditingController(), note=TextEditingController(), interval=TextEditingController(), cups=TextEditingController();
  DateTime start=DateTime.now().add(const Duration(minutes:5));
  DateTime? end;
  int lead=3;
  bool alarm=false, show=true, repeat=false;
  @override void initState(){
    super.initState();
    final r=widget.row;
    if(r!=null){
      kind=r['kind']; unit=r['unit']; love=r['love']??'year'; type=r['type']??'قرص';
      title.text=r['title']; note.text=r['note']??''; interval.text='${r['n']}'; cups.text='${r['cups']}';
      start=DateTime.parse(r['start']); end=r['end']==null?null:DateTime.parse(r['end']);
      lead=r['lead']; alarm=r['alarm']; show=r['calendar']; repeat=unit!='once';
    }
  }
  @override void dispose(){title.dispose();note.dispose();interval.dispose();cups.dispose();super.dispose();}
  void choose(String? k){
    setState((){
      kind=k; title.clear();note.clear();cups.text='8';
      interval.text=k=='water'?'90':k=='medicine'?'8':'1';
      unit=k=='car'?'month':k=='plant'?'day':'once'; love='year';
      alarm=false;end=null;repeat=false;show=true;
      final now=DateTime.now();
      start=k=='medicine'?now.add(const Duration(minutes:5)):DateTime(now.year,now.month,now.day,k=='water'?8:9);
    });
  }
  Widget drop<T>(String label,T? current,Map<T,String> options,ValueChanged<T?> change)=>DropdownButtonFormField<T>(
    initialValue:current, isExpanded:true,decoration:InputDecoration(labelText:label),
    items:[for(final option in options.entries) DropdownMenuItem(value:option.key,child:Text(option.value))],
    onChanged:change);
  Widget field(TextEditingController controller,String label,{bool mandatory=true,bool numeric=false,int max=365})=>TextFormField(
    controller:controller,onChanged:(_)=>setState((){}),keyboardType:numeric?TextInputType.number:TextInputType.text,
    decoration:InputDecoration(labelText:label),
    validator:(s){
      if(mandatory && (s??'').trim().isEmpty) return 'این فیلد را کامل کن';
      if(numeric && ((number(s)??0)<1 || (number(s)??0)>max)) return 'عددی از ۱ تا ${fa(max)} وارد کن';
      return null;
    });
  Reminder value(){
    final mode=kind=='love' && love!='custom'?love:unit;
    return {'id':widget.row?['id']??DateTime.now().microsecondsSinceEpoch.toString(),
      'kind':kind,'title':kind=='water'?'آب خوردن':title.text.trim(),'note':note.text.trim(),
      'start':start.toIso8601String(),'end':end?.toIso8601String(),
      'alarm':['water','medicine'].contains(kind)|| (kind!='car' && alarm),
      'calendar':show,'n':(number(interval.text)??1).clamp(1,1440).toInt(),
      'cups':(number(cups.text)??1).clamp(1,24).toInt(),'unit':mode,'lead':lead,
      'type':type,'love':love,'paused':widget.row?['paused']??false};
  }
  Future<void> pickDate(bool finish) async {
    final original=finish?(end??start):start;
    final picked=await showDialog<DateTime>(context:context,builder:(_)=>SolarPicker(initial:original));
    if(picked==null || !mounted) return;
    setState((){
      if(finish) {end=DateTime(picked.year,picked.month,picked.day,23,59,59);}
      else {start=DateTime(picked.year,picked.month,picked.day,start.hour,start.minute);}
    });
  }
  Future<void> pickTime() async {
    final t=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(start));
    if(t!=null && mounted) setState(()=>start=DateTime(start.year,start.month,start.day,t.hour,t.minute));
  }
  @override Widget build(BuildContext context){
    final k=kind;
    final custom=k=='custom'||(k=='love'&&love=='custom');
    final cadence=k=='car'||k=='plant'||(custom&&repeat);
    final invalidWater=k=='water' && start.hour*60+start.minute+((number(cups.text)??1)-1)*(number(interval.text)??1)>=1440;
    final invalidEnd=end!=null && end!.isBefore(start);
    final now=DateTime.now();
    final preview=k==null || invalidWater || invalidEnd ? <Event>[] :
      (events(value(),now,day(now,405)).where((e)=>!e.calendar).toList()..sort((a,b)=>a.time.compareTo(b.time)));
    return ColoredBox(color:k==null?Colors.white:kinds[k]!.$3,child:Form(key:form,
      child:ListView(padding:const EdgeInsets.all(20),children:[
        Text('برای چی یادآوری می‌خوای؟',style:Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height:14),
        drop('نوع یادآور',k,{for(final x in kinds.entries)x.key:'${x.value.$2}  ${x.value.$1}'},choose),
        if(k!=null) ...[
          const SizedBox(height:16),
          Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(16),child:Column(
            children:[
              if(k=='love') drop('مناسبت',love,{'year':'سالگرد','month':'ماهگرد','week':'هفته‌گرد','custom':'مناسبت دلخواه'},(v)=>setState((){love=v!;unit='once';repeat=false;end=null;})),
              if(k=='medicine') drop('نوع دارو',type,{for(final t in ['قرص','کپسول','شربت','پماد','کرم','آمپول','قطره','سایر'])t:t},(v)=>setState(()=>type=v!)),
              if(k!='water') field(title,switch(k){'birthday'=>'نام فرد','memorial'=>'نام عزیز','car'=>'نام قطعه','plant'=>'نام گیاه','medicine'=>'نام دارو',_=>'عنوان'}),
              if(k=='birthday') field(note,'نسبت'),
              if(k=='medicine') field(note,'یادداشت مصرف (اختیاری)',mandatory:false),
              OutlinedButton.icon(onPressed:()=>pickDate(false),icon:const Icon(Icons.calendar_today_outlined),
                label:Text('${switch(k){'birthday'=>'تاریخ تولد','memorial'=>'تاریخ فوت','car'=>'آخرین تعویض','love'=>'تاریخ مبنا',_=>'تاریخ شروع'}} · ${date(start)}')),
              OutlinedButton.icon(onPressed:pickTime,icon:const Icon(Icons.schedule),label:Text('ساعت · ${clock(start)}')),
              if(k=='water') ...[field(cups,'تعداد لیوان در روز',numeric:true,max:24),field(interval,'فاصله بین لیوان‌ها (دقیقه)',numeric:true,max:1440)],
              if(k=='medicine') field(interval,'هر چند ساعت؟',numeric:true,max:168),
              if(custom) SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('تکرار شود'),value:repeat,onChanged:(v)=>setState((){repeat=v;unit=v?'day':'once';if(!v)end=null;})),
              if(cadence) ...[
                field(interval,'فاصلهٔ تکرار',numeric:true,max:unit=='year'?20:365),
                drop('واحد فاصله',unit,{for(final u in units.entries.where((u)=>u.key!='once'))u.key:u.value},(v)=>setState(()=>unit=v!)),
              ],
              if(k=='medicine'||(custom&&repeat)) Row(children:[
                Expanded(child:OutlinedButton(onPressed:()=>pickDate(true),child:Text(end==null?'تاریخ پایان (اختیاری)':'پایان · ${date(end!)}'))),
                if(end!=null) IconButton(tooltip:'برداشتن تاریخ پایان',onPressed:()=>setState(()=>end=null),icon:const Icon(Icons.clear)),
              ]),
              if(k=='love'&&love=='month') drop('چند روز قبل؟',lead,{2:'۲ روز',3:'۳ روز'},(v)=>setState(()=>lead=v!)),
              if(k=='custom') SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('نمایش در تقویم'),value:show,onChanged:(v)=>setState(()=>show=v)),
              if(['water','medicine','car'].contains(k))
                ListTile(contentPadding:EdgeInsets.zero,title:Text(k=='car'?'روش یادآوری · اعلان':'روش یادآوری · آلارم'))
              else
                drop('روش یادآوری',alarm,{false:'اعلان',true:'آلارم'},(v)=>setState(()=>alarm=v!)),
            ].map((w)=>Padding(padding:const EdgeInsets.only(bottom:10),child:w)).toList(),
          ))),
          if(invalidWater) const Text('آخرین نوبت به روز بعد می‌افتد. ساعت شروع یا فاصله را تغییر بده.'),
          if(invalidEnd) const Text('تاریخ پایان باید بعد از شروع باشد.'),
          if(preview.isNotEmpty) ListTile(title:const Text('نوبت‌های بعدی'),subtitle:Text(preview.take(k=='medicine'?4:1).map((e)=>'${date(e.time)}، ${clock(e.time)}').join('\n'))),
          const SizedBox(height:10),
          FilledButton(onPressed:widget.busy||invalidWater||invalidEnd?null:(){
            if(form.currentState!.validate()){
              if(unit=='once' && (k=='custom'||(k=='love'&&love=='custom')) && start.isBefore(DateTime.now())){
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('زمان یادآوری یک‌باره باید در آینده باشد.')));return;
              }
              widget.onSave(value());
            }
          },child:Text(widget.busy?'در حال ذخیره…':'ذخیره یادآور')),
        ],
      ]),
    ));
  }
}

class SolarPicker extends StatefulWidget {
  final DateTime initial;
  const SolarPicker({super.key,required this.initial});
  @override State<SolarPicker> createState()=>_SolarPicker();
}
class _SolarPicker extends State<SolarPicker>{
  late Jalali j=Jalali.fromDateTime(widget.initial);
  @override Widget build(BuildContext context)=>AlertDialog(
    title:const Text('انتخاب تاریخ شمسی'),
    content:SizedBox(width:290,child:SingleChildScrollView(child:Column(children:[
      DropdownButton<int>(isExpanded:true,value:j.year,
        items:[for(var y=1250;y<=1500;y++) DropdownMenuItem(value:y,child:Text(fa(y)))],
        onChanged:(y)=>change(y!,j.month,j.day)),
      DropdownButton<int>(isExpanded:true,value:j.month,
        items:[for(var m=1;m<=12;m++) DropdownMenuItem(value:m,child:Text(Jalali(j.year,m).formatter.mN))],
        onChanged:(m)=>change(j.year,m!,j.day)),
      DropdownButton<int>(isExpanded:true,value:j.day,
        items:[for(var d=1;d<=j.monthLength;d++) DropdownMenuItem(value:d,child:Text(fa(d)))],
        onChanged:(d)=>change(j.year,j.month,d!)),
    ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('لغو')),
      FilledButton(onPressed:()=>Navigator.pop(context,j.toDateTime()),child:const Text('انتخاب'))],
  );
  void change(int y,int m,int d)=>setState(()=>j=Jalali(y,m,d.clamp(1,Jalali(y,m).monthLength).toInt()));
}

class Settings extends StatefulWidget{
  const Settings({super.key});
  @override State<Settings> createState()=>_Settings();
}
class _Settings extends State<Settings> with WidgetsBindingObserver{
  String sound='system', file='فایل گوشی';
  Map<dynamic,dynamic> status={};
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this); refresh();}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);native.invokeMethod('stopPreview');super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState s){if(s==AppLifecycleState.resumed)refresh();}
  Future<void> refresh() async {
    final next=await native.invokeMapMethod('status')??{};
    if(mounted)setState((){status=next;sound=next['sound']??'system';file=next['file']??'فایل گوشی';});
  }
  Future<void> action(String method,[Object? argument]) async {
    try{await native.invokeMethod(method,argument);await refresh();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('انجام نشد: $e')));}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('تنظیمات')),body:ListView(
    padding:const EdgeInsets.all(16),children:[
      DropdownButtonFormField<String>(key:ValueKey(sound),initialValue:sound,decoration:const InputDecoration(labelText:'صدای آلارم'),
        items:[for(final x in {'system':'زنگ گوشی','soft':'زنگ ملایم','bright':'زنگ روشن','file':file}.entries)
          if(x.key!='file'||status['hasFile']==true) DropdownMenuItem(value:x.key,child:Text(x.value,overflow:TextOverflow.ellipsis))],
        isExpanded:true,onChanged:(v){if(v!=null) action('sound',v);}),
      ListTile(leading:const Icon(Icons.audio_file_outlined),title:const Text('انتخاب فایل صوتی از گوشی'),onTap:()=>action('pick')),
      ListTile(leading:const Icon(Icons.play_arrow),title:const Text('پخش نمونه'),onTap:()=>action('preview')),
      for(final p in {'notification':'اعلان‌ها','exact':'آلارم دقیق','fullscreen':'نمایش آلارم روی صفحه قفل'}.entries)
        ListTile(title:Text(p.value),subtitle:Text(status[p.key]==true?'فعال':'نیاز به مجوز'),onTap:()=>action(p.key)),
      const ListTile(subtitle:Text('روی گوشی شیائومی، آلارم را با صفحهٔ قفل و پس از بستن برنامه آزمایش کن.')),
    ]));
}
