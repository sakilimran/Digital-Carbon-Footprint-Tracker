package com.sakilimran.carbon.footprint;

import android.app.AppOpsManager;
import android.app.usage.UsageStats;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "social_media_carbon_footprint/usage";

    // Map for CO₂ emissions (grams per minute)
    private static final Map<String, Double> SOCIAL_MEDIA_CO2_MAP = new HashMap<String, Double>() {{
        put("com.google.android.youtube", 0.46); // YouTube
        put("tv.twitch.android.app", 0.55); // Twitch
        put("com.twitter.android", 0.60); // Twitter
        put("com.linkedin.android", 0.71); // LinkedIn
        put("com.facebook.katana", 0.79); // Facebook
        put("com.snapchat.android", 0.87); // Snapchat
        put("com.instagram.android", 1.05); // Instagram
        put("com.pinterest", 1.30); // Pinterest
        put("com.reddit.frontpage", 2.48); // Reddit
        put("com.zhiliaoapp.musically", 2.63); // TikTok
    }};

    // Map for energy consumption (mAh per minute)
    private static final Map<String, Double> SOCIAL_MEDIA_ENERGY_MAP = new HashMap<String, Double>() {{
        put("com.google.android.youtube", 8.58); // YouTube
        put("tv.twitch.android.app", 9.05); // Twitch
        put("com.twitter.android", 10.28); // Twitter
        put("com.linkedin.android", 8.92); // LinkedIn
        put("com.facebook.katana", 12.36); // Facebook
        put("com.snapchat.android", 11.48); // Snapchat
        put("com.instagram.android", 8.90); // Instagram
        put("com.pinterest", 10.83); // Pinterest
        put("com.reddit.frontpage", 11.04); // Reddit
        put("com.zhiliaoapp.musically", 15.81); // TikTok
    }};

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "getDailyUsage": {
                            // Return usage stats for TODAY
                            String usageData = getDailyUsageStats();
                            result.success(usageData);
                            break;
                        }
                        case "getRangeUsage": {
                            // Return usage stats for custom range
                            long startTime = call.argument("startTime");
                            long endTime = call.argument("endTime");
                            String usageData = getRangeUsageStats(startTime, endTime);
                            result.success(usageData);
                            break;
                        }
                        case "hasUsagePermission": {
                            boolean hasPermission = hasUsageStatsPermission(this);
                            result.success(hasPermission);
                            break;
                        }
                        case "openUsageSettings": {
                            openUsageAccessSettings();
                            result.success(null);
                            break;
                        }
                        default:
                            result.notImplemented();
                            break;
                    }
                });
    }

    // ---------------------------
    //  Permission Check Methods
    // ---------------------------

    /**
     * Checks if this app has Usage Stats permission.
     */
    private static boolean hasUsageStatsPermission(Context context) {
        AppOpsManager appOps = (AppOpsManager) context.getSystemService(Context.APP_OPS_SERVICE);
        int mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.getPackageName());
        return mode == AppOpsManager.MODE_ALLOWED;
    }

    /**
     * Opens the Usage Access settings screen so the user can grant permission.
     */
    private void openUsageAccessSettings() {
        // Try deep-linking directly to this app's entry. Some OEM ROMs (e.g. Oxygen OS 16)
        // don't support the package URI here and throw ActivityNotFoundException.
        try {
            Intent intent = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS);
            intent.setData(Uri.parse("package:" + getPackageName()));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
        } catch (Exception e) {
            // Fallback: open the generic Usage Access list, which works on all OEM ROMs.
            Intent fallback = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS);
            fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(fallback);
        }
    }

    // ---------------------------
    //  Usage Stats Methods
    // ---------------------------

    /**
     * Get usage for the current day, from midnight until now.
     */
    private String getDailyUsageStats() {
        Calendar calendar = Calendar.getInstance();
        long endTime = calendar.getTimeInMillis();

        // Set to midnight
        calendar.set(Calendar.HOUR_OF_DAY, 0);
        calendar.set(Calendar.MINUTE, 0);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        long startTime = calendar.getTimeInMillis();

        return getUsageFormatted(startTime, endTime);
    }

    /**
     * Get usage for a custom date range.
     */
    private String getRangeUsageStats(long startTime, long endTime) {
        return getUsageFormatted(startTime, endTime);
    }

    /**
     * Core usage retrieval, filters only the social media apps of interest,
     * calculates total usage minutes, CO2 emissions, and energy consumption.
     *
     * Uses queryAndAggregateUsageStats instead of queryUsageStats because:
     *  - No interval type needed — avoids INTERVAL_DAILY empty-result bugs on
     *    OEM ROMs (OnePlus, Samsung, etc.) where partial-day stats aren't returned.
     *  - Returns one pre-aggregated UsageStats per package for the whole range,
     *    so no manual accumulation across multiple interval records is needed.
     */
    private String getUsageFormatted(long startTime, long endTime) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return "[]";
        }

        UsageStatsManager usageStatsManager =
                (UsageStatsManager) getSystemService(Context.USAGE_STATS_SERVICE);

        Map<String, UsageStats> aggregated =
                usageStatsManager.queryAndAggregateUsageStats(startTime, endTime);

        if (aggregated == null || aggregated.isEmpty()) {
            return "[]";
        }

        List<String> usageResults = new ArrayList<>();
        for (Map.Entry<String, UsageStats> entry : aggregated.entrySet()) {
            String packageName = entry.getKey();
            if (!SOCIAL_MEDIA_CO2_MAP.containsKey(packageName)) continue;

            long totalMs = entry.getValue().getTotalTimeInForeground();
            if (totalMs <= 0) continue; // skip apps with no recorded foreground time

            double totalMinutes = totalMs / 60000.0;
            double co2PerMinute  = SOCIAL_MEDIA_CO2_MAP.get(packageName);
            double totalCO2      = totalMinutes * co2PerMinute;
            double energyPerMinute = SOCIAL_MEDIA_ENERGY_MAP.get(packageName);
            double totalEnergy   = totalMinutes * energyPerMinute;

            // Locale.US ensures '.' as decimal separator regardless of device locale.
            // Without it, locales that use ',' produce invalid JSON (e.g. "12,34")
            // which throws a FormatException in Dart's json.decode.
            usageResults.add(String.format(Locale.US,
                    "{\"package\":\"%s\",\"minutes\":%.2f,\"co2\":%.2f,\"energy\":%.2f}",
                    packageName, totalMinutes, totalCO2, totalEnergy
            ));
        }

        return "[" + String.join(",", usageResults) + "]";
    }
}
