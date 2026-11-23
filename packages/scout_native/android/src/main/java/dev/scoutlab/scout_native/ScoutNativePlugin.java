package dev.scoutlab.scout_native;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class ScoutNativePlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private static final String CHANNEL_ID = "affari";
    private MethodChannel channel;
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "scout_native");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if ("show".equals(call.method)) {
            try {
                Integer id = call.argument("id");
                String title = call.argument("title");
                String body = call.argument("body");
                String url = call.argument("url");
                show(id == null ? 0 : id, title == null ? "" : title, body == null ? "" : body, url);
            } catch (Exception e) {
                // Avviso non mostrato: non blocca la ricerca.
            }
            result.success(null);
        } else {
            result.notImplemented();
        }
    }

    private void show(int id, String title, String body, String url) {
        if (Build.VERSION.SDK_INT >= 33 &&
                context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                        != PackageManager.PERMISSION_GRANTED) {
            return;
        }
        NotificationManager nm =
                (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(new NotificationChannel(
                    CHANNEL_ID, "Affari", NotificationManager.IMPORTANCE_HIGH));
        }
        Intent intent;
        if (url != null && !url.isEmpty()) {
            intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
        } else {
            intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
            if (intent == null) intent = new Intent();
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
        PendingIntent pending = PendingIntent.getActivity(context, id, intent, flags);

        int icon = context.getResources().getIdentifier("ic_stat_scout", "drawable", context.getPackageName());
        if (icon == 0) icon = context.getApplicationInfo().icon;

        Notification.Builder b;
        if (Build.VERSION.SDK_INT >= 26) {
            b = new Notification.Builder(context, CHANNEL_ID);
        } else {
            b = new Notification.Builder(context);
            b.setPriority(Notification.PRIORITY_HIGH);
        }
        b.setSmallIcon(icon)
                .setColor(0xFF1D3A8A)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(new Notification.BigTextStyle().bigText(body))
                .setContentIntent(pending)
                .setAutoCancel(true);
        nm.notify(id, b.build());
    }
}
