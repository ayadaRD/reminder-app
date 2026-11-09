package ir.yadavar.yadavar;

import android.content.*;

public class AlarmReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        String action=intent.getAction();
        if ("ring".equals(action) || "notify".equals(action)) Alarms.dispatch(context,"ring".equals(action));
        else Alarms.arm(context);
    }
}
