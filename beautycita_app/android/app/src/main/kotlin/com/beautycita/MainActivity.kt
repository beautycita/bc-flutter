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
import android.accounts.Account
import android.accounts.AccountManager
import android.content.ContentResolver
import android.os.Bundle
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
        private const val CONTACT_SYNC_CHANNEL = "com.beautycita/contact_sync"
        private const val SAVE_CONTACT_CHANNEL = "com.beautycita.app/contacts"
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

        // ── Contact sync channel — writes RawContacts directly (no SyncAdapter delay) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTACT_SYNC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncContacts" -> {
                        Thread {
                            try {
                                // Ensure account exists (don't remove — that deletes all RawContacts!)
                                val accountManager = AccountManager.get(this@MainActivity)
                                val account = Account("BeautyCita", "com.beautycita.sync")
                                accountManager.addAccountExplicitly(account, null, null) // no-op if exists

                                // Read matches from SharedPreferences
                                val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                                val json = prefs.getString("flutter.contact_sync_matches", null)
                                if (json == null) {
                                    Log.d(TAG, "[ContactSync] No matches in SharedPrefs")
                                    runOnUiThread { result.success(0) }
                                    return@Thread
                                }

                                val matches = org.json.JSONArray(json)
                                var synced = 0
                                Log.d(TAG, "[ContactSync] Processing ${matches.length()} matches directly")

                                for (i in 0 until matches.length()) {
                                    val match = matches.getJSONObject(i)
                                    val phone = match.getString("phone")
                                    val salonName = match.optString("salon_name", "")
                                    val salonId = match.optString("salon_id", "")
                                    val salonType = match.optString("salon_type", "r")

                                    // Find contact by phone
                                    val contactUri = android.net.Uri.withAppendedPath(
                                        android.provider.ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                                        android.net.Uri.encode(phone)
                                    )
                                    var contactId: Long? = null
                                    contentResolver.query(contactUri, arrayOf(android.provider.ContactsContract.PhoneLookup._ID), null, null, null)?.use { c ->
                                        if (c.moveToFirst()) contactId = c.getLong(0)
                                    }

                                    if (contactId == null) {
                                        Log.d(TAG, "[ContactSync] No contact found for $phone")
                                        continue
                                    }

                                    // Check if already synced
                                    val mime = "vnd.android.cursor.item/com.beautycita.book"
                                    var exists = false
                                    contentResolver.query(
                                        android.provider.ContactsContract.Data.CONTENT_URI,
                                        arrayOf(android.provider.ContactsContract.Data._ID),
                                        "${android.provider.ContactsContract.Data.CONTACT_ID} = ? AND ${android.provider.ContactsContract.Data.MIMETYPE} = ?",
                                        arrayOf(contactId.toString(), mime),
                                        null
                                    )?.use { c -> exists = c.count > 0 }

                                    if (exists) {
                                        Log.d(TAG, "[ContactSync] Already synced contact $contactId")
                                        continue
                                    }

                                    // Find existing RawContact to link to
                                    var existingRawId: Long? = null
                                    contentResolver.query(
                                        android.provider.ContactsContract.RawContacts.CONTENT_URI,
                                        arrayOf(android.provider.ContactsContract.RawContacts._ID),
                                        "${android.provider.ContactsContract.RawContacts.CONTACT_ID} = ? AND ${android.provider.ContactsContract.RawContacts.ACCOUNT_TYPE} != ?",
                                        arrayOf(contactId.toString(), "com.beautycita.sync"),
                                        null
                                    )?.use { c -> if (c.moveToFirst()) existingRawId = c.getLong(0) }

                                    // Batch: RawContact + Phone + Book action + Video action
                                    val ops = ArrayList<android.content.ContentProviderOperation>()

                                    ops.add(android.content.ContentProviderOperation.newInsert(android.provider.ContactsContract.RawContacts.CONTENT_URI)
                                        .withValue(android.provider.ContactsContract.RawContacts.ACCOUNT_TYPE, "com.beautycita.sync")
                                        .withValue(android.provider.ContactsContract.RawContacts.ACCOUNT_NAME, "BeautyCita")
                                        .withValue(android.provider.ContactsContract.RawContacts.AGGREGATION_MODE, android.provider.ContactsContract.RawContacts.AGGREGATION_MODE_DEFAULT)
                                        .build())

                                    // Phone for aggregation
                                    ops.add(android.content.ContentProviderOperation.newInsert(android.provider.ContactsContract.Data.CONTENT_URI)
                                        .withValueBackReference(android.provider.ContactsContract.Data.RAW_CONTACT_ID, 0)
                                        .withValue(android.provider.ContactsContract.Data.MIMETYPE, android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
                                        .withValue(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER, phone)
                                        .withValue(android.provider.ContactsContract.CommonDataKinds.Phone.TYPE, android.provider.ContactsContract.CommonDataKinds.Phone.TYPE_OTHER)
                                        .build())

                                    // Book action
                                    ops.add(android.content.ContentProviderOperation.newInsert(android.provider.ContactsContract.Data.CONTENT_URI)
                                        .withValueBackReference(android.provider.ContactsContract.Data.RAW_CONTACT_ID, 0)
                                        .withValue(android.provider.ContactsContract.Data.MIMETYPE, mime)
                                        .withValue(android.provider.ContactsContract.Data.DATA1, salonId)
                                        .withValue(android.provider.ContactsContract.Data.DATA2, "Reservar en BeautyCita")
                                        .withValue(android.provider.ContactsContract.Data.DATA3, salonName)
                                        .withValue(android.provider.ContactsContract.Data.DATA4, salonType)
                                        .build())

                                    // Video call action
                                    ops.add(android.content.ContentProviderOperation.newInsert(android.provider.ContactsContract.Data.CONTENT_URI)
                                        .withValueBackReference(android.provider.ContactsContract.Data.RAW_CONTACT_ID, 0)
                                        .withValue(android.provider.ContactsContract.Data.MIMETYPE, "vnd.android.cursor.item/com.beautycita.videocall")
                                        .withValue(android.provider.ContactsContract.Data.DATA1, salonId)
                                        .withValue(android.provider.ContactsContract.Data.DATA2, "Videollamada BeautyCita")
                                        .withValue(android.provider.ContactsContract.Data.DATA3, salonName)
                                        .build())

                                    val results = contentResolver.applyBatch(android.provider.ContactsContract.AUTHORITY, ops)
                                    Log.i(TAG, "[ContactSync] Wrote BeautyCita actions for contact $contactId ($salonName)")

                                    // Force aggregation
                                    val newRawId = android.content.ContentUris.parseId(results[0].uri!!)
                                    if (existingRawId != null) {
                                        try {
                                            val aggOps = ArrayList<android.content.ContentProviderOperation>()
                                            aggOps.add(android.content.ContentProviderOperation.newUpdate(android.provider.ContactsContract.AggregationExceptions.CONTENT_URI)
                                                .withValue(android.provider.ContactsContract.AggregationExceptions.TYPE, android.provider.ContactsContract.AggregationExceptions.TYPE_KEEP_TOGETHER)
                                                .withValue(android.provider.ContactsContract.AggregationExceptions.RAW_CONTACT_ID1, existingRawId)
                                                .withValue(android.provider.ContactsContract.AggregationExceptions.RAW_CONTACT_ID2, newRawId)
                                                .build())
                                            contentResolver.applyBatch(android.provider.ContactsContract.AUTHORITY, aggOps)
                                            Log.i(TAG, "[ContactSync] Aggregated raw $newRawId with $existingRawId")
                                        } catch (e: Exception) {
                                            Log.w(TAG, "[ContactSync] Aggregation failed: ${e.message}")
                                        }
                                    }
                                    synced++
                                }

                                Log.i(TAG, "[ContactSync] Done: $synced contacts synced")
                                runOnUiThread { result.success(synced) }
                            } catch (e: Exception) {
                                Log.e(TAG, "[ContactSync] Failed: ${e.message}", e)
                                runOnUiThread { result.error("SYNC_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Save BeautyCita contact via system intent (no permission needed) ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SAVE_CONTACT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveContact" -> {
                        try {
                            val name = call.argument<String>("name") ?: "BeautyCita"
                            val phone = call.argument<String>("phone") ?: "+523223208884"
                            val org = call.argument<String>("organization") ?: ""

                            val intent = android.content.Intent(android.content.Intent.ACTION_INSERT_OR_EDIT).apply {
                                type = android.provider.ContactsContract.Contacts.CONTENT_ITEM_TYPE
                                putExtra(android.provider.ContactsContract.Intents.Insert.NAME, name)
                                putExtra(android.provider.ContactsContract.Intents.Insert.PHONE, phone)
                                putExtra(android.provider.ContactsContract.Intents.Insert.PHONE_TYPE, android.provider.ContactsContract.CommonDataKinds.Phone.TYPE_WORK)
                                putExtra(android.provider.ContactsContract.Intents.Insert.COMPANY, org)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "[SaveContact] Failed: ${e.message}")
                            result.error("SAVE_CONTACT_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
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
                // Android 10-12: need READ_EXTERNAL_STORAGE
                val hasReadStorage = ContextCompat.checkSelfPermission(
                    this, Manifest.permission.READ_EXTERNAL_STORAGE
                ) == PackageManager.PERMISSION_GRANTED

                if (hasReadStorage) {
                    Log.d(TAG, "[Screenshot] READ_EXTERNAL_STORAGE granted")
                    startScreenshotDetection()
                } else {
                    Log.d(TAG, "[Screenshot] Requesting READ_EXTERNAL_STORAGE")
                    Handler(Looper.getMainLooper()).postDelayed({
                        try {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE),
                                PERMISSION_REQUEST_CODE
                            )
                        } catch (e: Exception) {
                            Log.e(TAG, "[Screenshot] Permission request failed: ${e.message}")
                        }
                    }, 1000)
                }
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
