package ir.yadavar.yadavar;

import android.app.Activity;
import android.content.Intent;
import android.os.*;
import android.view.*;
import android.widget.*;

public class RingActivity extends Activity {
    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        if (Build.VERSION.SDK_INT>=27) { setShowWhenLocked(true); setTurnScreenOn(true); }
        else getWindow().addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        LinearLayout layout=new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setGravity(Gravity.CENTER);
        layout.setPadding(28,28,28,28);
        layout.setBackgroundColor(0xfff7effa);
        TextView title=new TextView(this);
        title.setText(getIntent().getStringExtra("message"));
        title.setTextSize(24);
        title.setGravity(Gravity.CENTER);
        title.setTextColor(0xff302437);
        layout.addView(title);
        add(layout,"قطع آلارم","stop");
        if (Alarms.exact(this)) add(layout,"۱۰ دقیقه بعد","snooze");
        if (getIntent().getBooleanExtra("medicine",false)) add(layout,"مصرف شد","taken");
        setContentView(layout);
    }
    private void add(LinearLayout layout,String label,String action) {
        Button b=new Button(this);
        b.setText(label);
        b.setOnClickListener(v -> {
            startService(new Intent(this,RingService.class).setAction(action)
                .putExtra("token",getIntent().getStringExtra("token")));
            finish();
        });
        layout.addView(b);
    }
}
