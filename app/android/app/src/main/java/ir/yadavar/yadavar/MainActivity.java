package ir.yadavar.yadavar;

import android.Manifest;
import android.content.*;
import android.content.pm.PackageManager;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.*;
import android.provider.Settings;
import android.provider.OpenableColumns;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;

public class MainActivity extends FlutterActivity {
    private MethodChannel.Result picker;
    private MediaPlayer preview;
    static boolean isVisible = false;

    @Override
protected void onResume() {
    super.onResume();
    isVisible = true;

    try {
        Alarms.arm(this);
    } catch (Exception e) {
        android.util.Log.e("Yadavar", "Schedule after resume", e);
    }
}

@Override
protected void onPause() {
    isVisible = false;
    super.onPause();
}
    @Override public void configureFlutterEngine(FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "ir.yadavar/alarms")
            .setMethodCallHandler((call, result) -> {
                try {
                    var prefs = Alarms.prefs(this);
                    switch (call.method) {
                        case "getLanguage":
                            result.success(prefs.getString("language", "fa"));
                            break;
                        case "setLanguage":
                            String language = "en".equals(call.arguments) ? "en" : "fa";
                            if (prefs.edit().putString("language", language).commit()) {
                                result.success(null);
                            } else {
                                result.error("save_language", "Could not save the language", null);
                            }
                            break;
                        case "load": result.success(prefs.getString("rows", "[]")); break;
                        case "needsRefresh": result.success(System.currentTimeMillis() - prefs.getLong("updated", 0) > 604800000L); break;
case "history":
    result.success(Alarms.historyForUi(this));
    break;
                        case "save":
                            Alarms.save(this, call.argument("rows"), call.argument("events"));
                            result.success(Alarms.exact(this)); break;
                        case "status":
                            var state = new HashMap<String,Object>();
                            state.put("sound", prefs.getString("sound", "system"));
                            state.put("file", prefs.getString("filename", "فایل گوشی"));
                            state.put("hasFile", prefs.contains("uri"));
                            state.put("exact", Alarms.exact(this));
                            state.put("notification", Alarms.notifications(this).areNotificationsEnabled());
                            state.put("fullscreen", Build.VERSION.SDK_INT < 34 || Alarms.notifications(this).canUseFullScreenIntent());
                            result.success(state); break;
                        case "sound":
                            prefs.edit().putString("sound", (String) call.arguments).apply();
                            result.success(null); break;
                        case "pick":
                            if (picker != null) { result.error("busy", "انتخاب فایل باز است", null); break; }
                            var intent = new Intent(Intent.ACTION_OPEN_DOCUMENT).setType("audio/*").addCategory(Intent.CATEGORY_OPENABLE);
                            startActivityForResult(intent, 501);
                            picker = result; break;
                        case "preview":
                            stopPreview();
                            preview = Alarms.player(this, false);
                            preview.start();
                            new Handler(Looper.getMainLooper()).postDelayed(this::stopPreview, 4500);
                            result.success(null); break;
                        case "stopPreview": stopPreview(); result.success(null); break;
                        case "notification":
                            if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                                && !prefs.getBoolean("notificationAsked", false)) {
                                prefs.edit().putBoolean("notificationAsked", true).apply();
                                requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 502);
                            } else startActivity(new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName()));
                            result.success(null); break;
                        case "exact":
                            if (Build.VERSION.SDK_INT >= 31 && !Alarms.exact(this))
                                startActivity(new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:" + getPackageName())));
                            result.success(null); break;
                        case "fullscreen":
                            if (Build.VERSION.SDK_INT >= 34)
                                startActivity(new Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:" + getPackageName())));
                            result.success(null); break;
                        default: result.notImplemented();
                    }
                } catch (Exception e) { result.error("android", e.getMessage(), null); }
            });
        Alarms.arm(this);
    }
    private void stopPreview() { if (preview != null) { preview.release(); preview = null; } }
    @Override protected void onStop() { stopPreview(); super.onStop(); }
    @Override protected void onActivityResult(int request, int code, Intent data) {
        super.onActivityResult(request, code, data);
        if (request != 501 || picker == null) return;
        try {
            if (code == RESULT_OK && data != null && data.getData() != null) {
                Uri uri = data.getData();
                getContentResolver().takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
                String name = "فایل گوشی";
                try (var cursor = getContentResolver().query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
                    if (cursor != null && cursor.moveToFirst()) name = cursor.getString(0);
                }
                Alarms.prefs(this).edit().putString("uri", uri.toString()).putString("filename", name).putString("sound", "file").apply();
            }
            picker.success(null);
        } catch (Exception e) { picker.error("file", e.getMessage(), null); }
        finally { picker = null; }
    }
}
