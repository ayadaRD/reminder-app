package ir.yadavar.yadavar;

import android.app.*;
import android.content.*;
import android.media.MediaPlayer;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.os.IBinder;
import org.json.*;
import java.util.ArrayDeque;

public class RingService extends Service {
    private static RingService running;
    private final ArrayDeque<JSONObject> queue=new ArrayDeque<>();
    private MediaPlayer player;
    private Ringtone fallback;
    private String displayed="";
    static void cancel(Context c,String id) {
        if (running == null) return;
        running.queue.removeIf(item -> id.equals(item.optString("id")));
        if (!running.displayed.isEmpty() && (running.queue.isEmpty() ||
                !running.displayed.equals(token(running.queue.peek())))) running.showNext();
    }
    static String token(JSONObject item) { return item.optString("id")+":"+item.optLong("when"); }
    @Override public void onCreate() { super.onCreate(); running=this; }
    @Override public IBinder onBind(Intent intent) { return null; }
    @Override public int onStartCommand(Intent intent,int flags,int startId) {
        if (intent==null) { stopSelf(); return START_NOT_STICKY; }
        if (intent.hasExtra("events")) {
            try {
                JSONArray items=new JSONArray(intent.getStringExtra("events"));
                for (int i=0; i<items.length(); i++) queue.add(items.getJSONObject(i));
            } catch (JSONException ignored) {}
            if (displayed.isEmpty()) showNext();
            return START_NOT_STICKY;
        }
        JSONObject item=queue.peek();
        if (item==null || !token(item).equals(intent.getStringExtra("token"))) {
            if (item==null) stopSelf();
            return START_NOT_STICKY;
        }
        try {
            if ("snooze".equals(intent.getAction()) && Alarms.exact(this)) {
                item.put("when",System.currentTimeMillis()+600000L);
                JSONArray snoozes=Alarms.read(this,"snoozes").put(item);
                Alarms.prefs(this).edit().putString("snoozes",snoozes.toString()).commit();
                Alarms.arm(this);
            } else if ("taken".equals(intent.getAction()) && "medicine".equals(item.optString("kind"))) {
                var prefs=Alarms.prefs(this);
                JSONObject history=new JSONObject(prefs.getString("history","{}"));
                history.put(item.optString("id"),System.currentTimeMillis());
                prefs.edit().putString("history",history.toString()).commit();
            }
        } catch (JSONException ignored) {}
        queue.remove();
        showNext();
        return START_NOT_STICKY;
    }
    private void showNext() {
        if (player!=null) { player.release(); player=null; }
        if (fallback!=null) { fallback.stop(); fallback=null; }
        JSONObject item=queue.peek();
        if (item==null) { displayed=""; stopForeground(true); stopSelf(); return; }
        displayed=token(item);
        String message=item.optString("message");
        boolean medicine="medicine".equals(item.optString("kind"));
        Alarms.channels(this);
        Intent screen=new Intent(this,RingActivity.class)
            .putExtra("token",displayed).putExtra("message",message).putExtra("medicine",medicine);
        PendingIntent open=PendingIntent.getActivity(this,100,screen,Alarms.FLAGS);
        var notice=Alarms.builder(this,"ring").setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("آلارم یادآور").setContentText(message)
            .setCategory(Notification.CATEGORY_ALARM).setPriority(Notification.PRIORITY_MAX)
            .setContentIntent(open).setFullScreenIntent(open,true).setOngoing(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC);
        notice.addAction(0,"قطع",action("stop",101));
        if (Alarms.exact(this)) notice.addAction(0,"۱۰ دقیقه بعد",action("snooze",102));
        if (medicine) notice.addAction(0,"مصرف شد",action("taken",103));
        startForeground(11,notice.build());
        try { player=Alarms.player(this,true); player.start(); }
        catch (Exception e) {
            fallback=RingtoneManager.getRingtone(this,RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM));
            if (fallback!=null) {
                if (android.os.Build.VERSION.SDK_INT>=28) fallback.setLooping(true);
                fallback.play();
            }
        }
    }
    private PendingIntent action(String name,int request) {
        return PendingIntent.getService(this,request,new Intent(this,RingService.class)
            .setAction(name).putExtra("token",displayed),Alarms.FLAGS);
    }
    @Override public void onDestroy() {
        if (player!=null) player.release();
        if (fallback!=null) fallback.stop();
        running=null;
        super.onDestroy();
    }
}
