package com.beautycita.sync

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * Service that hosts the [SyncAdapter].
 * The sync framework binds to this service to trigger syncs.
 */
class SyncService : Service() {

    companion object {
        private val syncAdapterLock = Object()
        private var syncAdapter: SyncAdapter? = null
    }

    override fun onCreate() {
        super.onCreate()
        synchronized(syncAdapterLock) {
            if (syncAdapter == null) {
                syncAdapter = SyncAdapter(applicationContext, true)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return syncAdapter?.syncAdapterBinder
    }
}
