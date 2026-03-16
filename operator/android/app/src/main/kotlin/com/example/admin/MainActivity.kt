package com.example.admin

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channel = "pasa_hero/google_api"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            if (call.method == "getGoogleApiKey") {
                val key = try {
                    val ai = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    ai.metaData?.getString("com.google.android.geo.API_KEY") ?: ""
                } catch (e: Exception) {
                    ""
                }
                result.success(key)
            } else {
                result.notImplemented()
            }
        }
    }
}
