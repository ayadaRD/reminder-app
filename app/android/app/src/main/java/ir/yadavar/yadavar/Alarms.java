package ir.yadavar.yadavar;

import android.app.*;
import android.content.*;
import android.media.*;
import android.net.Uri;
import android.os.Build;
import org.json.*;
import java.util.*;

final class Alarms {
    static final int FLAGS = PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE;
    static android.content.SharedPreferences prefs(Context c) { return c.getSharedPreferences("reminders", 0); }
    static AlarmManager manager(Context c) { return c.getSystemService(AlarmManager.class); }
    static NotificationManager notifications(Context c) { return c.getSystemService(NotificationManager.class); }
    static boolean exact(Context c) { return Build.VERSION.SDK_INT < 31 || manager(c).canScheduleExactAlarms(); }
    static JSONArray read(Context c, String key) {
        try { return new JSONArray(prefs(c).getString(key, "[]")); }
        catch (JSONException e) { throw new IllegalStateException(e); }
    }
    static void save(Context c, String rows, String events) throws JSONException {
        JSONArray keep = new JSONArray();
        JSONArray source = new JSONArray(rows);
        Map<String,JSONObject> active = new HashMap<>();
        for (int i=0; i<source.length(); i++) {
            JSONObject row=source.getJSONObject(i);
            if (!row.optBoolean("paused")) active.put(row.getString("id"),row);
        }
        JSONArray previous=read(c,"rows");
        for (int i=0; i<previous.length(); i++) {
            JSONObject row=previous.getJSONObject(i);
            String id=row.getString("id");
            if (!active.containsKey(id) || !row.toString().equals(active.get(id).toString())) {
                RingService.cancel(c,id);
                active.remove(id);
            }
        }
        JSONArray snoozes=read(c,"snoozes");
        for (int i=0; i<snoozes.length(); i++) {
            JSONObject item=snoozes.getJSONObject(i);
            if (active.containsKey(item.getString("id"))) keep.put(item);
        }
        if (!prefs(c).edit().putString("rows", rows).putString("events", events)
            .putLong("updated",System.currentTimeMillis()).putString("snoozes",keep.toString()).commit()) throw new IllegalStateException("ذخیره انجام نشد");
        arm(c);
    }
    static PendingIntent tick(Context c, boolean ring) {
        return PendingIntent.getBroadcast(c, ring ? 41 : 42,
            new Intent(c, AlarmReceiver.class).setAction(ring ? "ring" : "notify"), FLAGS);
    }
    
static void arm(Context c) {
    long now = System.currentTimeMillis();

    long nextRing = Long.MAX_VALUE;
    long nextNotice = Long.MAX_VALUE;

    var editor = prefs(c).edit();

    for (String key : new String[]{"events", "snoozes"}) {
        JSONArray source = read(c, key);
        JSONArray kept = new JSONArray();

        for (int i = 0; i < source.length(); i++) {
            JSONObject item = source.optJSONObject(i);
            if (item == null) continue;

            if ("events".equals(key)) {
                if (item.optLong("waterStepMs") > 0) {
                    item = normalizeWater(c, item, now);
                } else if (item.optLong("medicineStepMs") > 0) {
                    item = normalizeMedicine(c, item, now);
                }
            }

            if (item == null || completed(c, item)) continue;

            long when = item.optLong("when");
            boolean ring = item.optBoolean("alarm");

            if (when < now - (ring ? 60000L : 86400000L)) {
                continue;
            }

            kept.put(item);

            if (ring) {
                nextRing = Math.min(nextRing, when);
            } else {
                nextNotice = Math.min(nextNotice, when);
            }
        }

        editor.putString(key, kept.toString());
    }

    if (!editor.commit()) {
        throw new IllegalStateException("Could not update alarm queue");
    }

    set(c, true, nextRing, now);
    set(c, false, nextNotice, now);
}

    static void set(Context c, boolean ring, long next, long now) {
        PendingIntent operation=tick(c,ring);
        manager(c).cancel(operation);
        if (next==Long.MAX_VALUE || (ring && !exact(c))) return;
        long time=Math.max(next,now+100);
        if (ring) {
            PendingIntent show=PendingIntent.getActivity(c,40,new Intent(c,MainActivity.class),FLAGS);
            try { manager(c).setAlarmClock(new AlarmManager.AlarmClockInfo(time,show),operation); }
            catch (SecurityException ignored) { }
        } else if (exact(c)) {
            try { manager(c).setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,time,operation); }
            catch (SecurityException e) { manager(c).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,time,operation); }
        } else manager(c).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,time,operation);
    }

static void dispatch(Context c, boolean ring) {
    long now = System.currentTimeMillis();

    JSONArray due = new JSONArray();
    var editor = prefs(c).edit();

    for (String key : new String[]{"events", "snoozes"}) {
        JSONArray kept = new JSONArray();
        JSONArray items = read(c, key);

        for (int i = 0; i < items.length(); i++) {
            JSONObject item = items.optJSONObject(i);
            if (item == null) continue;

            boolean mainEvent = "events".equals(key);

            boolean waterChain = mainEvent &&
                item.optLong("waterStepMs") > 0;

            boolean medicineChain = mainEvent &&
                item.optLong("medicineStepMs") > 0;

            if (waterChain) {
                item = normalizeWater(c, item, now);
            } else if (medicineChain) {
                item = normalizeMedicine(c, item, now);
            }

            if (item == null || completed(c, item)) continue;

            long when = item.optLong("when");

            if (item.optBoolean("alarm") != ring || when > now) {
                kept.put(item);
                continue;
            }

            if (when >= now - (ring ? 60000L : 86400000L)) {
                due.put(item);
            }

            if (waterChain) {
                long index = item.optLong("waterIndex") + 1;
                long step = item.optLong("waterStepMs");
                long anchor = item.optLong("waterAnchor");

                long firstFuture = now < anchor
                    ? 0
                    : (now - anchor) / step + 1;

                JSONObject next = waterAt(
                    item,
                    Math.max(index, firstFuture)
                );

                if (next != null) kept.put(next);
            } else if (medicineChain) {
                JSONObject next = nextMedicine(
                    item,
                    now + 1
                );

                if (next != null) kept.put(next);
            }
        }

        editor.putString(key, kept.toString());
    }

    if (!editor.commit()) {
        throw new IllegalStateException("Could not update alarm queue");
    }

    arm(c);

    if (due.length() == 0) return;

    if (ring) {
        Intent service = new Intent(c, RingService.class)
            .putExtra("events", due.toString());

        if (Build.VERSION.SDK_INT >= 26) {
            c.startForegroundService(service);
        } else {
            c.startService(service);
        }

        return;
    }

    channels(c);

    for (int i = 0; i < due.length(); i++) {
        JSONObject item = due.optJSONObject(i);

        PendingIntent open = PendingIntent.getActivity(
            c,
            40,
            new Intent(c, MainActivity.class),
            FLAGS
        );

        notifications(c).notify(
            (item.optString("id") + item.optLong("when")).hashCode(),
            builder(c, "reminder")
                .setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setContentTitle(english(c) ? "Reminder" : "یادآور")
                .setContentText(item.optString("message"))
                .setContentIntent(open)
                .setAutoCancel(true)
                .build()
        );
    }
}

    static void channels(Context c) {
        if (Build.VERSION.SDK_INT<26) return;
        var ring=new NotificationChannel("ring","آلارم‌ها",NotificationManager.IMPORTANCE_HIGH);
        ring.setSound(null,null);
        notifications(c).createNotificationChannel(ring);
        notifications(c).createNotificationChannel(new NotificationChannel("reminder","یادآوری‌ها",NotificationManager.IMPORTANCE_DEFAULT));
    }
    static Notification.Builder builder(Context c,String channel) {
        return Build.VERSION.SDK_INT>=26 ? new Notification.Builder(c,channel) : new Notification.Builder(c);
    }
    static MediaPlayer player(Context c,boolean loop) throws Exception {
        var prefs=prefs(c);
        String sound=prefs.getString("sound","system");
        Uri uri=RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM);
        if ("file".equals(sound)) uri=Uri.parse(prefs.getString("uri",uri.toString()));
        else if ("soft".equals(sound) || "bright".equals(sound)) {
            int id=c.getResources().getIdentifier(sound,"raw",c.getPackageName());
            uri=Uri.parse("android.resource://"+c.getPackageName()+"/"+id);
        }
        var player=new MediaPlayer();
        try {
            player.setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build());
            if (loop) player.setWakeMode(c,android.os.PowerManager.PARTIAL_WAKE_LOCK);
            try { player.setDataSource(c,uri); }
            catch (Exception e) { player.reset();
                player.setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build());
                player.setDataSource(c,RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)); }
            player.setLooping(loop);
            player.prepare();
            return player;
        } catch (Exception e) { player.release(); throw e; }
    }

    static String occurrence(JSONObject item) {
    return item.optString(
        "occurrence",
        item.optString("id") + ":" +
            item.optLong("originalWhen", item.optLong("when"))
    );
}

static boolean completed(Context c, JSONObject item) {
    try {
        JSONObject done = new JSONObject(
            prefs(c).getString("completed", "{}")
        );
        return done.has(occurrence(item));
    } catch (JSONException e) {
        throw new IllegalStateException(e);
    }
}

static String localDay(long when) {
    return new java.text.SimpleDateFormat(
        "yyyy-MM-dd",
        java.util.Locale.US
    ).format(new java.util.Date(when));
}

static boolean english(Context c) {
    return "en".equals(prefs(c).getString("language", "fa"));
}

static String alarmMessage(Context c, JSONObject item) {
    if ("water".equals(item.optString("kind"))) {
        return english(c)
            ? "Remember to drink some water"
            : "یادت نره آب بخوری";
    }

    return item.optString("message", english(c) ? "Reminder" : "یادآور");
}

static String confirmLabel(Context c, JSONObject item) {
    String kind = item.optString("kind");

    if ("water".equals(kind)) {
        return english(c) ? "I'll drink now" : "الان می‌خورم";
    }

    if ("medicine".equals(kind)) {
        return english(c) ? "Taken" : "مصرف کردم";
    }

    return english(c) ? "Done" : "انجام دادم";
}

static void recordTaken(Context c, JSONObject item) throws JSONException {
    var preferences = prefs(c);
    long now = System.currentTimeMillis();

    JSONObject done = new JSONObject(
        preferences.getString("completed", "{}")
    );

    String key = occurrence(item);

    // یک نوبت فقط یک بار ثبت می‌شود.
    if (done.has(key)) return;

    JSONObject history = new JSONObject(
        preferences.getString("history", "{}")
    );

    String id = item.getString("id");
    String kind = item.optString("kind");

    if ("medicine".equals(kind)) {
        // سازگار با نمایش سابق آخرین مصرف دارو.
        history.put(id, now);
    }

    if ("water".equals(kind)) {
        JSONObject water = history.optJSONObject("__water");
        if (water == null) water = new JSONObject();

        JSONObject reminder = water.optJSONObject(id);
        if (reminder == null) reminder = new JSONObject();

        // تعویق بعد از نیمه‌شب هم متعلق به روز نوبت اصلی است.
        String date = item.optString(
            "waterDay",
            localDay(item.optLong("originalWhen", item.optLong("when")))
        );

        JSONObject slots = reminder.optJSONObject(date);
        if (slots == null) slots = new JSONObject();

        String slot = item.has("waterSlot")
            ? String.valueOf(item.optInt("waterSlot"))
            : key;

        slots.put(slot, now);
        reminder.put(date, slots);
        water.put(id, reminder);
        history.put("__water", water);
    }

    done.put(key, now);

    if (!preferences.edit()
        .putString("history", history.toString())
        .putString("completed", done.toString())
        .commit()) {
        throw new IllegalStateException("Could not record completion");
    }
}

static JSONObject waterAt(JSONObject source, long index) {
    try {
        long step = source.optLong("waterStepMs");
        if (step <= 0 || index < 0) return null;

        long limit = source.optLong("waterLimit");
        if (limit > 0 && index >= limit) return null;

        long when = source.getLong("waterAnchor") + index * step;

        if (source.has("waterEnd") &&
            when > source.getLong("waterEnd")) {
            return null;
        }

        JSONObject item = new JSONObject(source.toString());

        item.put("when", when);
        item.put("originalWhen", when);
        item.put(
            "occurrence",
            item.getString("id") + ":" + when
        );
        item.put("waterIndex", index);
        item.put("waterSlot", index);
        item.put("waterDay", localDay(when));

        return item;
    } catch (JSONException e) {
        throw new IllegalStateException(e);
    }
}

static JSONObject normalizeWater(
    Context context,
    JSONObject item,
    long now
) {
    long step = item.optLong("waterStepMs");
    if (step <= 0) return item;

    long index = item.optLong("waterIndex");
    long anchor = item.optLong("waterAnchor");

    // بعد از خاموش بودن طولانی گوشی، نوبت‌های خیلی قدیمی
    // یک‌جا پخش نمی‌شوند.
    long oldestAllowed = now - 60000L;

    if (item.optLong("when") < oldestAllowed) {
        long elapsed = now - anchor;

        index = Math.max(
            index,
            elapsed <= 0 ? 0 : (elapsed + step - 1) / step
        );

        item = waterAt(item, index);
    }

    // نوبت انجام‌شده دوباره اجرا نشود.
    while (item != null && completed(context, item)) {
        item = waterAt(item, item.optLong("waterIndex") + 1);
    }

    return item;
}

static JSONObject nextMedicine(JSONObject source, long from) {
    try {
        long step = source.optLong("medicineStepMs");
        if (step <= 0) return null;

        JSONArray days = source.optJSONArray("medicineDays");
        if (days == null || days.length() == 0) return null;

        long anchor = source.getLong("medicineAnchor");

        long elapsed = from - anchor;
        long index = elapsed <= 0
            ? 0
            : (elapsed + step - 1) / step;

        Calendar horizon = Calendar.getInstance();
        horizon.setTimeInMillis(Math.max(from, anchor));
        horizon.add(Calendar.DAY_OF_YEAR, 405);

        long limit = horizon.getTimeInMillis();

        while (true) {
            long when = anchor + index * step;

            if (when >= limit) return null;

            if (source.has("medicineEnd") &&
                when > source.getLong("medicineEnd")) {
                return null;
            }

            Calendar calendar = Calendar.getInstance();
            calendar.setTimeInMillis(when);

            // Monday=1 ... Sunday=7، مطابق Dart.
            int weekday =
                (calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1;

            boolean allowed = false;

            for (int i = 0; i < days.length(); i++) {
                if (days.optInt(i) == weekday) {
                    allowed = true;
                    break;
                }
            }

            if (allowed) {
                JSONObject item = new JSONObject(source.toString());

                item.put("when", when);
                item.put("originalWhen", when);
                item.put(
                    "occurrence",
                    item.getString("id") + ":" + when
                );

                return item;
            }

            // پرش به روز بعد، بدون پیمایش دقیقه‌به‌دقیقه.
            calendar.add(Calendar.DAY_OF_YEAR, 1);
            calendar.set(Calendar.HOUR_OF_DAY, 0);
            calendar.set(Calendar.MINUTE, 0);
            calendar.set(Calendar.SECOND, 0);
            calendar.set(Calendar.MILLISECOND, 0);

            long nextDay = calendar.getTimeInMillis();
            long difference = nextDay - anchor;

            index = difference <= 0
                ? 0
                : (difference + step - 1) / step;
        }
    } catch (JSONException e) {
        throw new IllegalStateException(e);
    }
}

static JSONObject normalizeMedicine(
    Context context,
    JSONObject item,
    long now
) {
    long from = item.optLong("when");

    // بعد از خاموشی طولانی، نوبت‌های قدیمی پشت سر هم پخش نشوند.
    if (from < now - 60000L) {
        from = now;
    }

    item = nextMedicine(item, from);

    while (item != null && completed(context, item)) {
        item = nextMedicine(item, item.optLong("when") + 1);
    }

    return item;
}

static String historyForUi(Context c) throws JSONException {
    JSONObject history = new JSONObject(
        prefs(c).getString("history", "{}")
    );

    JSONObject done = new JSONObject(
        prefs(c).getString("completed", "{}")
    );

    Set<String> medicineIds = new HashSet<>();
    JSONArray rows = read(c, "rows");

    for (int i = 0; i < rows.length(); i++) {
        JSONObject row = rows.optJSONObject(i);

        if (row != null &&
            "medicine".equals(row.optString("kind"))) {
            medicineIds.add(row.optString("id"));
        }
    }

    // id -> زمان اصلی نوبت -> زمان تأیید مصرف
    JSONObject medicineHistory = new JSONObject();

    Iterator<String> keys = done.keys();

    while (keys.hasNext()) {
        String key = keys.next();
        int separator = key.lastIndexOf(':');

        if (separator <= 0) continue;

        String id = key.substring(0, separator);
        if (!medicineIds.contains(id)) continue;

        long originalWhen;

        try {
            originalWhen = Long.parseLong(
                key.substring(separator + 1)
            );
        } catch (NumberFormatException ignored) {
            continue;
        }

        JSONObject doses = medicineHistory.optJSONObject(id);

        if (doses == null) doses = new JSONObject();

        doses.put(
            String.valueOf(originalWhen),
            done.optLong(key)
        );

        medicineHistory.put(id, doses);
    }

    // نزدیک‌ترین نوبت واقعی، شامل آلارم در حال نمایش و تعویق.
    JSONObject pending = new JSONObject();
    long now = System.currentTimeMillis();

    for (String storage : new String[]{
        "ringQueue", "snoozes", "events"
    }) {
        JSONArray items = read(c, storage);

        for (int i = 0; i < items.length(); i++) {
            JSONObject item = items.optJSONObject(i);

            if (item == null ||
                !"medicine".equals(item.optString("kind"))) {
                continue;
            }

            String id = item.optString("id");

            if (!medicineIds.contains(id) ||
                done.has(occurrence(item))) {
                continue;
            }

            long when = item.optLong("when");

            if (when <= 0) continue;

            boolean ringing = "ringQueue".equals(storage);

            // رویدادهای منقضی‌شده را نوبت بعد معرفی نکن.
            if (!ringing && when < now - 60000L) continue;

            JSONObject previous = pending.optJSONObject(id);

            if (previous != null &&
                previous.optLong("when") <= when) {
                continue;
            }

            JSONObject entry = new JSONObject();
            entry.put("when", when);
            entry.put(
                "state",
                ringing
                    ? "ringing"
                    : "snoozes".equals(storage)
                        ? "snoozed"
                        : "scheduled"
            );

            pending.put(id, entry);
        }
    }

    history.put("__medicine", medicineHistory);
    history.put("__medicinePending", pending);

    return history.toString();
}
}
