package com.adhkaar365.app

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val batteryChannel = "dhikr365/battery"

    // Known OEM "Autostart" / "Startup manager" screens. Standard Android's
    // battery-optimization whitelist does NOT reliably stop these vendors'
    // own custom app-killers — the user must separately allow autostart in
    // the manufacturer's own settings, which has no public API and must be
    // deep-linked by component name. Each brand has more than one candidate
    // because the exact activity has moved across OS versions; we try them
    // in order and silently fall through to the next one.
    private val autostartActivities = mapOf(
        "xiaomi" to listOf(
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
        ),
        "oppo" to listOf(
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
            ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")
        ),
        "vivo" to listOf(
            ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")
        ),
        "huawei" to listOf(
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")
        ),
        "honor" to listOf(
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
        ),
    )

    /// Normalizes Build.MANUFACTURER to one of our known keys, or null when
    /// the device is a brand with no known custom battery/autostart manager
    /// (Pixel, most Samsung/OnePlus — standard Android battery whitelist is
    /// sufficient there, no extra OEM step needed).
    private fun manufacturerKey(): String? {
        val m = Build.MANUFACTURER.lowercase()
        return when {
            m.contains("xiaomi") -> "xiaomi"
            m.contains("oppo") -> "oppo"
            m.contains("vivo") -> "vivo" // also matches iQOO devices, which report as vivo
            m.contains("huawei") -> "huawei"
            m.contains("honor") -> "honor"
            else -> null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, batteryChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName")
                                )
                                startActivity(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    // Returns "xiaomi"/"oppo"/"vivo"/"huawei"/"honor" if this
                    // device needs an extra manual Autostart step, else null.
                    "getAutostartBrand" -> {
                        result.success(manufacturerKey())
                    }
                    // Opens the OEM's own Autostart/Startup-manager screen.
                    // Falls back to this app's system App Info page (where
                    // the user can still find battery/permission settings
                    // manually) if no known activity resolves on this device.
                    "openAutostartSettings" -> {
                        val key = manufacturerKey()
                        var opened = false
                        if (key != null) {
                            for (component in autostartActivities[key].orEmpty()) {
                                try {
                                    val intent = Intent().apply {
                                        this.component = component
                                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                    }
                                    startActivity(intent)
                                    opened = true
                                    break
                                } catch (e: Exception) {
                                    // Try the next known candidate for this brand.
                                }
                            }
                        }
                        if (!opened) {
                            try {
                                val intent = Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$packageName")
                                )
                                startActivity(intent)
                            } catch (e: Exception) {
                                // Nothing we can do — result still reports failure below.
                            }
                        }
                        result.success(opened)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
