package com.beautycita.sync

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.ContactsContract
import android.util.Log
import com.beautycita.MainActivity

/**
 * Transparent activity launched when user taps "Reservar en BeautyCita"
 * in the native Samsung Contacts app.
 *
 * Reads the salon ID from the contact Data row, then deep-links into
 * the Flutter app at the Cita Express booking flow for that salon.
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
            var salonType = "r"

            if (data != null) {
                contentResolver.query(
                    data,
                    arrayOf(
                        ContactsContract.Data.DATA1, // salon_id
                        ContactsContract.Data.DATA4, // type: "r" (registered) or "d" (discovered)
                    ),
                    null, null, null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        salonId = cursor.getString(0) ?: ""
                        salonType = cursor.getString(1) ?: "r"
                    }
                }
            }

            Log.i(TAG, "Launching booking for salon $salonId (type=$salonType)")

            // Use deep link URI — Flutter's GoRouter handles these
            val deepLink = if (salonType == "r" && salonId.isNotEmpty()) {
                // Registered salon → Cita Express (direct booking)
                Uri.parse("https://beautycita.com/cita-express/$salonId")
            } else if (salonId.isNotEmpty()) {
                // Discovered salon → invite flow
                Uri.parse("https://beautycita.com/invite")
            } else {
                Uri.parse("https://beautycita.com/home")
            }

            val launchIntent = Intent(Intent.ACTION_VIEW, deepLink).apply {
                setPackage("com.beautycita")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(launchIntent)

        } catch (e: Exception) {
            Log.e(TAG, "Failed: ${e.message}", e)
            // Fallback: just open the app
            val fallback = Intent(this, MainActivity::class.java)
            fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(fallback)
        }

        finish()
    }
}
