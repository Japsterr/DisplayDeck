package com.displaydeck.androidtv

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class DisplayDeckApplication : Application(), Configuration.Provider {
    
    @Inject
    lateinit var workerFactory: HiltWorkerFactory
    
    override fun getWorkManagerConfiguration(): Configuration {
        return Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()
    }
    
    override fun onCreate() {
        super.onCreate()
        
        // Initialize any application-wide services here if needed
        android.util.Log.i("DisplayDeckApp", "Application initialized")
    }
}