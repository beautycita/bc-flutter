package com.beautycita.sync

import android.accounts.Account
import android.content.AbstractThreadedSyncAdapter
import android.content.ContentProviderClient
import android.content.ContentProviderOperation
import android.content.Context
import android.content.SyncResult
import android.net.Uri
import android.os.Bundle
import android.provider.ContactsContract
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * SyncAdapter that adds "Book in BeautyCita" action rows to matched contacts
 * in the native Android Contacts app.
 *
 * Match data is written to SharedPreferences by the Flutter side (via MethodChannel)
 * as a JSON array under key "contact_sync_matches".
 *
 * Each match object: { "phone": "+521234567890", "salon_name": "Salon Example", "salon_id": "uuid" }
 */
class SyncAdapter(
    context: Context,
    autoInitialize: Boolean
) : AbstractThreadedSyncAdapter(context, autoInitialize) {

    companion object {
        private const val TAG = "BeautyCita.Sync"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val MATCHES_KEY = "flutter.contact_sync_matches"
        private const val MIME_TYPE = "vnd.android.cursor.item/com.beautycita.book"
        private const val ACCOUNT_TYPE = "com.beautycita.sync"
    }

    override fun onPerformSync(
        account: Account?,
        extras: Bundle?,
        authority: String?,
        provider: ContentProviderClient?,
        syncResult: SyncResult?
    ) {
        try {
            Log.d(TAG, "onPerformSync started")
            val matches = readMatches()
            if (matches.isEmpty()) {
                Log.d(TAG, "No matches to sync")
                return
            }
            Log.d(TAG, "Syncing ${matches.size} matches")

            for (match in matches) {
                try {
                    syncMatch(account, match)
                } catch (e: Exception) {
                    Log.e(TAG, "Error syncing match ${match.phone}: ${e.message}", e)
                    syncResult?.stats?.numIoExceptions =
                        (syncResult?.stats?.numIoExceptions ?: 0) + 1
                }
            }
            Log.d(TAG, "onPerformSync completed")
        } catch (e: Exception) {
            Log.e(TAG, "onPerformSync failed: ${e.message}", e)
        }
    }

    private fun syncMatch(account: Account?, match: MatchData) {
        // Find the contact ID by phone number
        val contactId = findContactByPhone(match.phone) ?: run {
            Log.d(TAG, "No contact found for phone ${match.phone}")
            return
        }

        // Check if we already have a BeautyCita raw contact for this contact
        if (hasExistingRow(contactId)) {
            Log.d(TAG, "Already synced contact $contactId, skipping")
            return
        }

        // Batch insert: create a RawContact + Data row
        val ops = ArrayList<ContentProviderOperation>()

        // Op 0: Insert RawContact linked to our sync account
        ops.add(
            ContentProviderOperation.newInsert(ContactsContract.RawContacts.CONTENT_URI)
                .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, ACCOUNT_TYPE)
                .withValue(ContactsContract.RawContacts.ACCOUNT_NAME, account?.name ?: "BeautyCita")
                .withValue(
                    ContactsContract.RawContacts.AGGREGATION_MODE,
                    ContactsContract.RawContacts.AGGREGATION_MODE_DEFAULT
                )
                .build()
        )

        // Op 1: Insert a structured name so aggregation can match
        ops.add(
            ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                .withValue(
                    ContactsContract.Data.MIMETYPE,
                    ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE
                )
                .withValue(ContactsContract.CommonDataKinds.Phone.NUMBER, match.phone)
                .withValue(
                    ContactsContract.CommonDataKinds.Phone.TYPE,
                    ContactsContract.CommonDataKinds.Phone.TYPE_OTHER
                )
                .build()
        )

        // Op 2: Insert BeautyCita action data row
        ops.add(
            ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                .withValue(ContactsContract.Data.MIMETYPE, MIME_TYPE)
                .withValue(ContactsContract.Data.DATA1, match.salonId)
                .withValue(ContactsContract.Data.DATA2, "Reservar en BeautyCita")
                .withValue(ContactsContract.Data.DATA3, match.salonName)
                .build()
        )

        val results = context.contentResolver.applyBatch(ContactsContract.AUTHORITY, ops)
        Log.d(TAG, "Inserted BeautyCita row for contact $contactId (${results.size} ops)")
    }

    private fun findContactByPhone(phone: String): Long? {
        val uri = Uri.withAppendedPath(
            ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
            Uri.encode(phone)
        )
        try {
            context.contentResolver.query(
                uri,
                arrayOf(ContactsContract.PhoneLookup._ID),
                null, null, null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    return cursor.getLong(0)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "findContactByPhone error: ${e.message}", e)
        }
        return null
    }

    private fun hasExistingRow(contactId: Long): Boolean {
        try {
            context.contentResolver.query(
                ContactsContract.Data.CONTENT_URI,
                arrayOf(ContactsContract.Data._ID),
                "${ContactsContract.Data.CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ?",
                arrayOf(contactId.toString(), MIME_TYPE),
                null
            )?.use { cursor ->
                return cursor.count > 0
            }
        } catch (e: Exception) {
            Log.e(TAG, "hasExistingRow error: ${e.message}", e)
        }
        return false
    }

    private fun readMatches(): List<MatchData> {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val json = prefs.getString(MATCHES_KEY, null) ?: return emptyList()
            val array = JSONArray(json)
            val result = mutableListOf<MatchData>()
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                result.add(
                    MatchData(
                        phone = obj.getString("phone"),
                        salonName = obj.optString("salon_name", ""),
                        salonId = obj.optString("salon_id", "")
                    )
                )
            }
            return result
        } catch (e: Exception) {
            Log.e(TAG, "readMatches error: ${e.message}", e)
            return emptyList()
        }
    }

    private data class MatchData(
        val phone: String,
        val salonName: String,
        val salonId: String
    )
}
