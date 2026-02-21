package com.beautycita

import android.graphics.Rect
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.beautycita/gesture_exclusion"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setGestureExclusionRects" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val rects = call.argument<List<Map<String, Int>>>("rects") ?: emptyList()
                            val exclusionRects = rects.map { map ->
                                Rect(
                                    map["left"] ?: 0,
                                    map["top"] ?: 0,
                                    map["right"] ?: 0,
                                    map["bottom"] ?: 0
                                )
                            }
                            val contentView = findViewById<android.view.View>(android.R.id.content)
                            contentView?.systemGestureExclusionRects = exclusionRects
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "clearGestureExclusionRects" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val contentView = findViewById<android.view.View>(android.R.id.content)
                            contentView?.systemGestureExclusionRects = emptyList()
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
