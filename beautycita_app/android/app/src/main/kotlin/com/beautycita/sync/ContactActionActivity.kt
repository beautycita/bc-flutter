package com.beautycita.sync

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.ContactsContract
import android.util.Log
import com.beautycita.MainActivity

/**
 * Transparent activity launched when user taps "Reservar en BeautyCita" inside
 * the native Contacts app.  Reads the salon ID and type from the Data row,
 * then deep-links into the Flutter app with the appropriate route.
 */
class ContactActionActivity : Activity() {

    companion object {
        private const val TAG = "BeautyCita.ContactAction"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        try {
            val data = intent.data
            var salonId = ""
            var salonType = "d"

            if (data != null) {
                contentResolver.query(
                    data,
                    arrayOf(
                        ContactsContract.Data.DATA1, // salon_id
                        ContactsContract.Data.DATA4, // type: "d" (discovered) or "r" (registered)
                    ),
                    null, null, null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        salonId = cursor.getString(0) ?: ""
                        salonType = cursor.getString(1) ?: "d"
                    }
                }
            }

            Log.d(TAG, "Launching route for salon $salonId (type=$salonType)")

            val route = if (salonType == "r") {
                "/provider/$salonId"
            } else {
                "/discovered-salon/$salonId"
            }

            val launchIntent = Intent(this, MainActivity::class.java).apply {
                putExtra("route", route)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(launchIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read contact action data: ${e.message}", e)
            val fallback = Intent(this, MainActivity::class.java)
            fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(fallback)
        }

        finish()
    }
}
