package com.beautycita.sync

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * Service that hosts the stub [AccountAuthenticator].
 * Required by the Android accounts framework.
 */
class AuthenticatorService : Service() {

    private lateinit var authenticator: AccountAuthenticator

    override fun onCreate() {
        super.onCreate()
        authenticator = AccountAuthenticator(this)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return authenticator.iBinder
    }
}
