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
        long now=System.currentTimeMillis();
        long nextRing=Long.MAX_VALUE, nextNotice=Long.MAX_VALUE;
        for (String key : new String[]{"events","snoozes"}) {
            JSONArray items=read(c,key);
            for (int i=0; i<items.length(); i++) {
                JSONObject item=items.optJSONObject(i);
                long when=item.optLong("when");
                if (when < now - (item.optBoolean("alarm") ? 60000L : 86400000L)) continue;
                if (item.optBoolean("alarm")) nextRing=Math.min(nextRing,when);
                else nextNotice=Math.min(nextNotice,when);
            }
        }
        set(c,true,nextRing,now);
        set(c,false,nextNotice,now);
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
        long now=System.currentTimeMillis();
        JSONArray due=new JSONArray();
        var edit=prefs(c).edit();
        for (String key : new String[]{"events","snoozes"}) {
            JSONArray keep=new JSONArray(), items=read(c,key);
            for (int i=0; i<items.length(); i++) {
                JSONObject item=items.optJSONObject(i);
                long when=item.optLong("when");
                if (item.optBoolean("alarm") != ring || when > now) keep.put(item);
                else if (when >= now - (ring ? 60000L : 86400000L)) due.put(item);
            }
            edit.putString(key,keep.toString());
        }
        edit.commit();
        arm(c);
        if (due.length()==0) return;
        if (ring) {
            Intent service=new Intent(c,RingService.class).putExtra("events",due.toString());
            if (Build.VERSION.SDK_INT>=26) c.startForegroundService(service);
            else c.startService(service);
        } else {
            channels(c);
            for (int i=0; i<due.length(); i++) {
                JSONObject item=due.optJSONObject(i);
                PendingIntent open=PendingIntent.getActivity(c,40,new Intent(c,MainActivity.class),FLAGS);
                notifications(c).notify((item.optString("id")+item.optLong("when")).hashCode(),
                    builder(c,"reminder").setSmallIcon(android.R.drawable.ic_popup_reminder)
                        .setContentTitle("یادآور").setContentText(item.optString("message"))
                        .setContentIntent(open).setAutoCancel(true).build());
            }
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
}
