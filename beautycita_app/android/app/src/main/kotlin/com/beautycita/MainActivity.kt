package com.beautycita

import android.Manifest
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.graphics.Rect
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val TAG = "BeautyCita"
        private const val GESTURE_CHANNEL = "com.beautycita/gesture_exclusion"
        private const val SCREENSHOT_METHOD_CHANNEL = "com.beautycita/screenshot_detector"
        private const val SCREENSHOT_EVENT_CHANNEL = "com.beautycita/screenshot_events"
        private const val PERMISSION_REQUEST_CODE = 1001
    }

    private var screenshotObserver: ContentObserver? = null
    private var eventSink: EventChannel.EventSink? = null
    private var lastScreenshotTime: Long = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Gesture exclusion channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GESTURE_CHANNEL)
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

        // ── Screenshot detection method channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREENSHOT_METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startListening" -> {
                        requestMediaPermissionAndStart()
                        result.success(true)
                    }
                    "stopListening" -> {
                        stopScreenshotDetection()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Screenshot event channel (streams screenshot bytes to Dart) ──
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCREENSHOT_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    Log.d(TAG, "[Screenshot] EventChannel: onListen, sink=${events != null}")
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    Log.d(TAG, "[Screenshot] EventChannel: onCancel")
                }
            })
    }

    private fun requestMediaPermissionAndStart() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val hasFullAccess = ContextCompat.checkSelfPermission(
                    this, Manifest.permission.READ_MEDIA_IMAGES
                ) == PackageManager.PERMISSION_GRANTED

                if (hasFullAccess) {
                    Log.d(TAG, "[Screenshot] READ_MEDIA_IMAGES granted")
                    startScreenshotDetection()
                } else {
                    // Defer permission request until activity window is ready
                    Log.d(TAG, "[Screenshot] Deferring permission request")
                    Handler(Looper.getMainLooper()).postDelayed({
                        try {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.READ_MEDIA_IMAGES),
                                PERMISSION_REQUEST_CODE
                            )
                        } catch (e: Exception) {
                            Log.e(TAG, "[Screenshot] Permission request failed: ${e.message}")
                        }
                    }, 1000)
                }
            } else {
                // Pre-Android 13: no permission needed
                Log.d(TAG, "[Screenshot] Pre-Android 13, starting detection")
                startScreenshotDetection()
            }
        } catch (e: Exception) {
            Log.e(TAG, "[Screenshot] requestMediaPermissionAndStart failed: ${e.message}")
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val anyGranted = grantResults.any { it == PackageManager.PERMISSION_GRANTED }
            if (anyGranted) {
                Log.d(TAG, "[Screenshot] Permission granted, starting detection")
                startScreenshotDetection()
            } else {
                Log.w(TAG, "[Screenshot] Permission denied — screenshot detection disabled")
            }
        }
    }

    private fun startScreenshotDetection() {
        if (screenshotObserver != null) {
            Log.d(TAG, "[Screenshot] Observer already registered")
            return
        }

        val handler = Handler(Looper.getMainLooper())
        screenshotObserver = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                super.onChange(selfChange, uri)
                if (uri == null) {
                    Log.d(TAG, "[Screenshot] onChange: uri is null")
                    return
                }

                Log.d(TAG, "[Screenshot] onChange: uri=$uri")

                // Debounce: ignore events within 2 seconds
                val now = System.currentTimeMillis()
                if (now - lastScreenshotTime < 2000) {
                    Log.d(TAG, "[Screenshot] Debounced (within 2s)")
                    return
                }

                // Check path first (fast, no pending-state issue)
                try {
                    val projection = arrayOf(
                        MediaStore.Images.Media.RELATIVE_PATH,
                        MediaStore.Images.Media.DISPLAY_NAME
                    )
                    var isScreenshot = false
                    contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val pathIndex = cursor.getColumnIndex(MediaStore.Images.Media.RELATIVE_PATH)
                            val nameIndex = cursor.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME)
                            val path = if (pathIndex >= 0) cursor.getString(pathIndex) ?: "" else ""
                            val name = if (nameIndex >= 0) cursor.getString(nameIndex) ?: "" else ""
                            Log.d(TAG, "[Screenshot] Image: path=$path name=$name")
                            isScreenshot = path.contains("Screenshots", ignoreCase = true) ||
                                path.contains("screenshot", ignoreCase = true)
                        }
                    }

                    if (isScreenshot) {
                        lastScreenshotTime = now
                        Log.d(TAG, "[Screenshot] Screenshot detected! Waiting for file to finalize...")

                        // Delay read — file is "pending" immediately after creation
                        handler.postDelayed({
                            try {
                                contentResolver.openInputStream(uri)?.use { stream ->
                                    val bytes = stream.readBytes()
                                    Log.d(TAG, "[Screenshot] Read ${bytes.size} bytes, sending to Dart")
                                    if (eventSink != null) {
                                        eventSink?.success(bytes)
                                        Log.d(TAG, "[Screenshot] Sent to EventChannel")
                                    } else {
                                        Log.w(TAG, "[Screenshot] eventSink is null!")
                                    }
                                } ?: Log.w(TAG, "[Screenshot] openInputStream returned null")
                            } catch (e: Exception) {
                                Log.e(TAG, "[Screenshot] Delayed read error: ${e.message}")
                            }
                        }, 1200)
                    }
                } catch (e: SecurityException) {
                    Log.e(TAG, "[Screenshot] SecurityException: ${e.message}")
                } catch (e: Exception) {
                    Log.e(TAG, "[Screenshot] Error: ${e.message}", e)
                }
            }
        }

        contentResolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            true,
            screenshotObserver!!
        )
        Log.d(TAG, "[Screenshot] ContentObserver registered on EXTERNAL_CONTENT_URI")
    }

    private fun stopScreenshotDetection() {
        screenshotObserver?.let {
            contentResolver.unregisterContentObserver(it)
            Log.d(TAG, "[Screenshot] ContentObserver unregistered")
        }
        screenshotObserver = null
    }

    override fun onDestroy() {
        stopScreenshotDetection()
        super.onDestroy()
    }
}
