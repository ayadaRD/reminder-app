package ir.yadavar.yadavar;

import android.app.*;
import android.content.*;
import android.media.*;
import android.os.*;
import android.widget.Toast;
import org.json.*;
import java.util.ArrayDeque;

public class RingService extends Service {
    private static RingService running;

    private final ArrayDeque<JSONObject> queue = new ArrayDeque<>();
    private MediaPlayer player;
    private Ringtone fallback;
    private String displayed = "";

    static String token(JSONObject item) {
        return Alarms.occurrence(item);
    }

    static JSONObject current() {
        return running == null ? null : running.queue.peek();
    }

    static void cancel(Context context, String id) {
        if (running == null) return;

        running.queue.removeIf(
            item -> id.equals(item.optString("id"))
        );

        running.persistQueue();

        if (!running.displayed.isEmpty() &&
            (running.queue.isEmpty() ||
             !running.displayed.equals(token(running.queue.peek())))) {
            running.showNext();
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        running = this;

        JSONArray stored = Alarms.read(this, "ringQueue");

        for (int i = 0; i < stored.length(); i++) {
            JSONObject item = stored.optJSONObject(i);
            if (item != null && !Alarms.completed(this, item)) {
                queue.add(item);
            }
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) {
            if (!queue.isEmpty()) showNext();
            else stopSelf();

            return START_NOT_STICKY;
        }

        if (intent.hasExtra("events")) {
            try {
                JSONArray items = new JSONArray(
                    intent.getStringExtra("events")
                );

                for (int i = 0; i < items.length(); i++) {
                    JSONObject item = items.getJSONObject(i);

                    if (!item.has("originalWhen")) {
                        item.put("originalWhen", item.getLong("when"));
                    }

                    if (!item.has("occurrence")) {
                        item.put(
                            "occurrence",
                            item.optString("id") + ":" +
                                item.getLong("originalWhen")
                        );
                    }

                    boolean exists = false;

                    for (JSONObject queued : queue) {
                        if (token(queued).equals(token(item))) {
                            exists = true;
                            break;
                        }
                    }

                    if (!exists && !Alarms.completed(this, item)) {
                        queue.add(item);
                    }
                }

                persistQueue();
            } catch (Exception e) {
                android.util.Log.e("Yadavar", "Read alarm events", e);
            }

            if (displayed.isEmpty()) showNext();

            return START_NOT_STICKY;
        }

        JSONObject item = queue.peek();

        if (item == null) {
            showNext();
            return START_NOT_STICKY;
        }

        if (!token(item).equals(intent.getStringExtra("token"))) {
            RingActivity.refreshActive();
            return START_NOT_STICKY;
        }

        String action = intent.getAction();

        try {
            if ("snooze".equals(action)) {
                if (!Alarms.exact(this)) {
                    Toast.makeText(
                        this,
                        Alarms.english(this)
                            ? "Enable exact alarms first"
                            : "اول مجوز آلارم دقیق رو فعال کن",
                        Toast.LENGTH_LONG
                    ).show();

                    RingActivity.refreshActive();
                    return START_NOT_STICKY;
                }

                JSONObject postponed = new JSONObject(item.toString());

                // شناسه و روز نوبت اصلی تغییر نمی‌کنند.
                postponed.put(
                    "when",
                    System.currentTimeMillis() + 600000L
                );

                JSONArray previous = Alarms.read(this, "snoozes");
                JSONArray updated = new JSONArray();

                for (int i = 0; i < previous.length(); i++) {
                    JSONObject old = previous.optJSONObject(i);

                    if (old != null &&
                        !token(old).equals(token(postponed))) {
                        updated.put(old);
                    }
                }

                updated.put(postponed);

                if (!Alarms.prefs(this).edit()
                    .putString("snoozes", updated.toString())
                    .commit()) {
                    throw new IllegalStateException("Snooze not saved");
                }

                Alarms.arm(this);
            } else if ("taken".equals(action)) {
                Alarms.recordTaken(this, item);
            } else {
                return START_NOT_STICKY;
            }

            queue.remove();
            persistQueue();
            showNext();
        } catch (Exception e) {
            android.util.Log.e("Yadavar", "Alarm action failed", e);

            Toast.makeText(
                this,
                Alarms.english(this)
                    ? "Could not save. Please try again."
                    : "ثبت نشد؛ دوباره امتحان کن.",
                Toast.LENGTH_LONG
            ).show();

            RingActivity.refreshActive();
        }

        return START_NOT_STICKY;
    }

    private void persistQueue() {
        JSONArray items = new JSONArray();

        for (JSONObject item : queue) {
            items.put(item);
        }

        Alarms.prefs(this).edit()
            .putString("ringQueue", items.toString())
            .commit();
    }

    private void stopSound() {
        if (player != null) {
            player.release();
            player = null;
        }

        if (fallback != null) {
            fallback.stop();
            fallback = null;
        }
    }

    private Notification alarmNotification(
    JSONObject item,
    PendingIntent open,
    boolean prominent
) {
    Alarms.channels(this);

    String channel = "ring";

    if (!prominent && Build.VERSION.SDK_INT >= 26) {
        channel = "ring_screen_active";

        NotificationChannel quiet = new NotificationChannel(
            channel,
            Alarms.english(this)
                ? "Active alarm"
                : "آلارم در حال پخش",
            NotificationManager.IMPORTANCE_LOW
        );

        quiet.setSound(null, null);
        quiet.enableVibration(false);

        Alarms.notifications(this).createNotificationChannel(quiet);
    }

    Notification.Builder notice = Alarms.builder(this, channel)
        .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
        .setContentTitle(
            Alarms.english(this) ? "Reminder" : "یادآور"
        )
        .setContentText(Alarms.alarmMessage(this, item))
        .setCategory(Notification.CATEGORY_ALARM)
        .setPriority(
            prominent
                ? Notification.PRIORITY_MAX
                : Notification.PRIORITY_LOW
        )
        .setContentIntent(open)
        .setOnlyAlertOnce(true)
        .setOngoing(true)
        .setVisibility(Notification.VISIBILITY_PUBLIC);

    if (prominent) {
        notice.setFullScreenIntent(open, true);
    }

    return notice.build();
}

static void onScreenVisible() {
    RingService service = running;

    if (service == null) return;

    JSONObject item = service.queue.peek();
    if (item == null) return;

    Intent screen = new Intent(service, RingActivity.class)
        .addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK |
            Intent.FLAG_ACTIVITY_SINGLE_TOP |
            Intent.FLAG_ACTIVITY_CLEAR_TOP
        );

    PendingIntent open = PendingIntent.getActivity(
        service,
        100,
        screen,
        Alarms.FLAGS
    );

    // وقتی صفحهٔ اختصاصی باز است، اعلان برجسته لازم نیست.
    service.startForeground(
        11,
        service.alarmNotification(item, open, false)
    );
}

private void showNext() {
    stopSound();

    JSONObject item = queue.peek();

    if (item == null) {
        displayed = "";
        RingActivity.refreshActive();
        stopForeground(true);
        stopSelf();
        return;
    }

    displayed = token(item);

    Intent screen = new Intent(this, RingActivity.class)
        .addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK |
            Intent.FLAG_ACTIVITY_SINGLE_TOP |
            Intent.FLAG_ACTIVITY_CLEAR_TOP
        );

    PendingIntent open = PendingIntent.getActivity(
        this,
        100,
        screen,
        Alarms.FLAGS
    );

    boolean overlayAllowed = Build.VERSION.SDK_INT >= 23 &&
        android.provider.Settings.canDrawOverlays(this);

    boolean direct = RingActivity.isVisible() ||
        MainActivity.isVisible ||
        overlayAllowed;

    startForeground(
        11,
        alarmNotification(item, open, !direct)
    );

    if (RingActivity.isVisible()) {
        RingActivity.refreshActive();
    } else if (direct) {
        try {
            startActivity(screen);
        } catch (Exception e) {
            android.util.Log.e(
                "Yadavar",
                "Direct alarm screen was blocked",
                e
            );
        }

        // بعضی سیستم‌ها بازشدن Activity را بدون Exception رد می‌کنند.
        // در آن حالت راه دسترسی به آلارم را از دست نمی‌دهیم.
        final String expectedToken = displayed;

        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            if (running != this ||
                !expectedToken.equals(displayed) ||
                RingActivity.isVisible()) {
                return;
            }

            JSONObject currentItem = queue.peek();
            if (currentItem == null) return;

            startForeground(
                11,
                alarmNotification(currentItem, open, true)
            );
        }, 1000);
    }

    try {
        player = Alarms.player(this, true);
        player.start();
    } catch (Exception e) {
        android.util.Log.e(
            "Yadavar",
            "Alarm audio fallback",
            e
        );

        fallback = RingtoneManager.getRingtone(
            this,
            RingtoneManager.getDefaultUri(
                RingtoneManager.TYPE_ALARM
            )
        );

        if (fallback != null) {
            fallback.setAudioAttributes(
                new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()
            );

            if (Build.VERSION.SDK_INT >= 28) {
                fallback.setLooping(true);
            }

            fallback.play();
        }
    }
}

    private PendingIntent action(String name, int request) {
        return PendingIntent.getService(
            this,
            request,
            new Intent(this, RingService.class)
                .setAction(name)
                .putExtra("token", displayed),
            Alarms.FLAGS
        );
    }

    @Override
    public void onDestroy() {
        stopSound();
        running = null;
        RingActivity.refreshActive();
        super.onDestroy();
    }
}