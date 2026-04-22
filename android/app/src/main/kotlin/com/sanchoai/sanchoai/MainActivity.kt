package com.sanchoai.sanchoai

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

class MainActivity : FlutterActivity() {
    
    companion object {
        const val CHANNEL = "com.sanchoai/background_service"
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    startBackgroundService()
                    result.success(true)
                }
                "stopService" -> {
                    stopBackgroundService()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun startBackgroundService() {
        val intent = Intent(this, AppLifecycleService::class.java).apply {
            action = AppLifecycleService.ACTION_START
        }
        startForegroundService(intent)
    }
    
    private fun stopBackgroundService() {
        val intent = Intent(this, AppLifecycleService::class.java).apply {
            action = AppLifecycleService.ACTION_STOP
        }
        startService(intent)
    }
    
    override fun onDestroy() {
        stopBackgroundService()
        super.onDestroy()
    }
}