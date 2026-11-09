package ir.yadavar.yadavar;

import android.app.Activity;
import android.content.Intent;
import android.graphics.*;
import android.graphics.drawable.*;
import android.net.Uri;
import android.os.*;
import android.provider.Settings;
import android.view.*;
import android.widget.*;
import org.json.JSONObject;
import java.lang.ref.WeakReference;

public class RingActivity extends Activity {
    private static WeakReference<RingActivity> active =
        new WeakReference<>(null);

    private boolean submitting = false;

    private static final int INK = 0xff293641;

    static boolean isVisible() {
        RingActivity activity = active.get();

        return activity != null && !activity.isFinishing();
    }

    static void refreshActive() {
        RingActivity activity = active.get();

        if (activity != null && !activity.isFinishing()) {
            activity.runOnUiThread(activity::render);
        }
    }

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);

        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true);
            setTurnScreenOn(true);
        } else {
            getWindow().addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED |
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            );
        }

        getWindow().addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        );
    }

    @Override
    protected void onResume() {
        super.onResume();

        active = new WeakReference<>(this);
        render();

        if (!isFinishing()) {
            RingService.onScreenVisible();
        }
    }

    @Override
    protected void onPause() {
        if (active.get() == this) {
            active.clear();
        }

        super.onPause();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        render();
    }

    private int dp(int value) {
        return Math.round(
            value * getResources().getDisplayMetrics().density
        );
    }

    private int background(String kind) {
        switch (kind) {
            case "water": return 0xffdceffa;
            case "medicine": return 0xffe3eafa;
            case "birthday": return 0xffeee3fa;
            case "love": return 0xfff9dfe7;
            case "plant": return 0xffe0efdf;
            case "car": return 0xffffedda;
            case "memorial": return 0xffe9e6ef;
            default: return 0xfffff0cc;
        }
    }

    private GradientDrawable rounded(
        int color,
        int radius,
        boolean border
    ) {
        GradientDrawable drawable = new GradientDrawable();

        drawable.setColor(color);
        drawable.setCornerRadius(dp(radius));

        if (border) {
            drawable.setStroke(dp(1), 0x66ffffff);
        }

        return drawable;
    }

    private TextView text(String value, int size, int color) {
        TextView view = new TextView(this);

        view.setText(value);
        view.setTextSize(size);
        view.setTextColor(color);
        view.setGravity(Gravity.CENTER);
        view.setFontFeatureSettings("kern");

        return view;
    }

    private void render() {
        JSONObject item = RingService.current();

        if (item == null) {
            finish();
            return;
        }

        submitting = false;

        boolean english = Alarms.english(this);
        boolean water = "water".equals(item.optString("kind"));
        int base = background(item.optString("kind"));

        getWindow().setStatusBarColor(base);
        getWindow().setNavigationBarColor(base);

        int flags = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;

        if (Build.VERSION.SDK_INT >= 26) {
            flags |= View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
        }

        getWindow().getDecorView().setSystemUiVisibility(flags);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(base);
        root.setLayoutDirection(
            english
                ? View.LAYOUT_DIRECTION_LTR
                : View.LAYOUT_DIRECTION_RTL
        );

        root.setPadding(dp(24), dp(20), dp(24), dp(24));

        root.setOnApplyWindowInsetsListener((view, insets) -> {
            view.setPadding(
                dp(24) + insets.getSystemWindowInsetLeft(),
                dp(20) + insets.getSystemWindowInsetTop(),
                dp(24) + insets.getSystemWindowInsetRight(),
                dp(24) + insets.getSystemWindowInsetBottom()
            );

            return insets;
        });

        // دکمهٔ کوچک مجوزها، بالا سمت راست.
        FrameLayout top = new FrameLayout(this);

        ImageButton permission = new ImageButton(this);
        permission.setImageResource(
            android.R.drawable.ic_menu_preferences
        );
        permission.setColorFilter(INK);
        permission.setPadding(dp(13), dp(13), dp(13), dp(13));
        permission.setBackground(rounded(0x77ffffff, 16, true));
        permission.setContentDescription(
            english
                ? "Display over other apps"
                : "نمایش روی برنامه‌های دیگر"
        );

        permission.setOnClickListener(view -> {
            try {
                startActivity(
                    new Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:" + getPackageName())
                    )
                );
            } catch (Exception e) {
                Toast.makeText(
                    this,
                    english
                        ? "Open this permission from system settings."
                        : "این مجوز را از تنظیمات گوشی باز کن.",
                    Toast.LENGTH_LONG
                ).show();
            }
        });

        FrameLayout.LayoutParams permissionParams =
            new FrameLayout.LayoutParams(dp(48), dp(48));
        permissionParams.gravity = Gravity.RIGHT;

        top.addView(permission, permissionParams);

        root.addView(
            top,
            new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(52)
            )
        );

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setVerticalScrollBarEnabled(false);

        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(Gravity.CENTER);
        content.setPadding(0, dp(24), 0, dp(24));

        FrameLayout iconFrame = new FrameLayout(this);
        iconFrame.setBackground(rounded(0x66ffffff, 32, true));

        View lineIcon = new AlarmLineIcon(water);

        iconFrame.addView(
            lineIcon,
            new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        );

        LinearLayout.LayoutParams iconParams =
            new LinearLayout.LayoutParams(dp(112), dp(112));
        iconParams.bottomMargin = dp(28);

        content.addView(iconFrame, iconParams);

        TextView title = text(
            Alarms.alarmMessage(this, item),
            25,
            INK
        );

        title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        title.setLineSpacing(dp(5), 1);

        LinearLayout.LayoutParams titleParams =
            new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            );

        titleParams.bottomMargin = dp(36);
        content.addView(title, titleParams);

        String token = RingService.token(item);

        Button taken = button(
            Alarms.confirmLabel(this, item),
            INK,
            base,
            false
        );

        Button snooze = button(
            english ? "In 10 minutes" : "۱۰ دقیقه دیگه",
            0x88ffffff,
            INK,
            true
        );

        taken.setOnClickListener(
            view -> submit("taken", token, taken, snooze)
        );

        snooze.setOnClickListener(
            view -> submit("snooze", token, taken, snooze)
        );

        LinearLayout.LayoutParams primaryParams =
            new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            );
        primaryParams.bottomMargin = dp(12);

        content.addView(taken, primaryParams);

        content.addView(
            snooze,
            new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        );

        scroll.addView(
            content,
            new ScrollView.LayoutParams(
                ScrollView.LayoutParams.MATCH_PARENT,
                ScrollView.LayoutParams.MATCH_PARENT
            )
        );

        root.addView(
            scroll,
            new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1
            )
        );

        setContentView(root);
        root.requestApplyInsets();
    }

    private Button button(
        String label,
        int background,
        int foreground,
        boolean border
    ) {
        Button button = new Button(this);

        button.setText(label);
        button.setTextSize(16);
        button.setAllCaps(false);
        button.setTextColor(foreground);
        button.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        button.setMinHeight(dp(56));
        button.setPadding(dp(18), dp(16), dp(18), dp(16));
        button.setElevation(0);

        GradientDrawable shape = rounded(background, 17, border);

        button.setBackground(
            new RippleDrawable(
                android.content.res.ColorStateList.valueOf(0x18304050),
                shape,
                rounded(0xffffffff, 17, false)
            )
        );

        return button;
    }

    private void submit(
        String action,
        String token,
        Button first,
        Button second
    ) {
        if (submitting) return;

        submitting = true;
        first.setEnabled(false);
        second.setEnabled(false);

        try {
            startService(
                new Intent(this, RingService.class)
                    .setAction(action)
                    .putExtra("token", token)
            );
        } catch (Exception e) {
            submitting = false;
            first.setEnabled(true);
            second.setEnabled(true);

            Toast.makeText(
                this,
                Alarms.english(this)
                    ? "Please try again"
                    : "دوباره امتحان کن",
                Toast.LENGTH_SHORT
            ).show();
        }
    }

    // آیکون خطی؛ قطره برای آب و ساعت برای بقیه.
    private class AlarmLineIcon extends View {
        private final boolean water;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);

        AlarmLineIcon(boolean water) {
            super(RingActivity.this);
            this.water = water;

            paint.setColor(INK);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(2.3f);
            paint.setStrokeCap(Paint.Cap.ROUND);
            paint.setStrokeJoin(Paint.Join.ROUND);

            setImportantForAccessibility(
                View.IMPORTANT_FOR_ACCESSIBILITY_NO
            );
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);

            canvas.save();
            canvas.scale(getWidth() / 100f, getHeight() / 100f);

            if (water) {
                Path drop = new Path();

                drop.moveTo(50, 23);
                drop.cubicTo(43, 35, 32, 47, 32, 58);
                drop.cubicTo(32, 82, 68, 82, 68, 58);
                drop.cubicTo(68, 47, 57, 35, 50, 23);
                drop.close();

                canvas.drawPath(drop, paint);

                Path shine = new Path();
                shine.moveTo(41, 58);
                shine.quadTo(41, 66, 48, 68);
                canvas.drawPath(shine, paint);
            } else {
                canvas.drawCircle(50, 51, 22, paint);
                canvas.drawLine(50, 51, 50, 37, paint);
                canvas.drawLine(50, 51, 61, 57, paint);

                canvas.drawLine(29, 29, 36, 23, paint);
                canvas.drawLine(64, 23, 71, 29, paint);

                canvas.drawLine(36, 71, 32, 77, paint);
                canvas.drawLine(64, 71, 68, 77, paint);
            }

            canvas.restore();
        }
    }
}