package com.displaydeck.androidtv

import android.content.ComponentName
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.lifecycleScope
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.displaydeck.androidtv.data.cache.AppDatabase
import com.displaydeck.androidtv.data.cache.CacheRepository
import com.displaydeck.androidtv.network.WebSocketClient
import com.displaydeck.androidtv.services.HealthMonitoringService
import com.displaydeck.androidtv.ui.screens.DisplayScreen
import com.displaydeck.androidtv.ui.screens.PairingScreen
import com.displaydeck.androidtv.ui.theme.DisplayDeckAndroidTVTheme
import com.displaydeck.androidtv.ui.viewmodel.DisplayViewModel
import com.displaydeck.androidtv.ui.viewmodel.PairingViewModel
import com.displaydeck.androidtv.utils.PreferencesManager
import com.displaydeck.androidtv.workers.MenuSyncWorker
import com.displaydeck.androidtv.workers.AutoUpdateWorker
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    
    companion object {
        private const val TAG = "MainActivity"
    }
    
    @Inject
    lateinit var database: AppDatabase
    
    @Inject
    lateinit var cacheRepository: CacheRepository
    
    @Inject
    lateinit var preferencesManager: PreferencesManager
    
    @Inject
    lateinit var webSocketClient: WebSocketClient
    
    private var healthMonitoringService: HealthMonitoringService? = null
    private var isServiceBound = false
    
    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as HealthMonitoringService.HealthMonitoringBinder
            healthMonitoringService = binder.getService()
            isServiceBound = true
            Log.d(TAG, "Health monitoring service connected")
        }
        
        override fun onServiceDisconnected(name: ComponentName?) {
            healthMonitoringService = null
            isServiceBound = false
            Log.d(TAG, "Health monitoring service disconnected")
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "MainActivity created")
        
        // Initialize the app and services
        initializeApp()
        
        setContent {
            DisplayDeckAndroidTVTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    val navController = rememberNavController()
                    
                    // Determine starting destination based on pairing status
                    val startDestination = if (preferencesManager.isPaired()) "display" else "pairing"
                    
                    NavHost(
                        navController = navController,
                        startDestination = startDestination
                    ) {
                        composable("pairing") {
                            val viewModel = hiltViewModel<PairingViewModel>()
                            PairingScreen(
                                viewModel = viewModel,
                                onPaired = {
                                    // Initialize paired state services
                                    initializePairedServices()
                                    
                                    navController.navigate("display") {
                                        popUpTo("pairing") { inclusive = true }
                                    }
                                }
                            )
                        }
                        
                        composable("display") {
                            val viewModel = hiltViewModel<DisplayViewModel>()
                            DisplayScreen(
                                viewModel = viewModel,
                                onUnpair = {
                                    // Clean up paired state
                                    cleanupPairedServices()
                                    
                                    navController.navigate("pairing") {
                                        popUpTo("display") { inclusive = true }
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    override fun onStart() {
        super.onStart()
        
        // Bind to health monitoring service
        val intent = Intent(this, HealthMonitoringService::class.java)
        bindService(intent, serviceConnection, BIND_AUTO_CREATE)
    }
    
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "MainActivity resumed")
        
        // Check for updates on resume
        lifecycleScope.launch {
            try {
                AutoUpdateWorker.scheduleUpdateCheck(
                    context = this@MainActivity,
                    forceCheck = false,
                    autoInstall = false
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule update check", e)
            }
        }
        
        // Reconnect WebSocket if paired
        if (preferencesManager.isPaired()) {
            webSocketClient.connect()
        }
    }
    
    override fun onPause() {
        super.onPause()
        Log.d(TAG, "MainActivity paused")
        
        // Keep services running in background for Android TV
        // WebSocket and health monitoring should continue
    }
    
    override fun onStop() {
        super.onStop()
        
        // Unbind from service
        if (isServiceBound) {
            unbindService(serviceConnection)
            isServiceBound = false
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "MainActivity destroyed")
        
        // Cleanup resources
        cleanupApp()
    }
    
    private fun initializeApp() {
        lifecycleScope.launch {
            try {
                Log.d(TAG, "Initializing app...")
                
                // Check if this is first run
                if (preferencesManager.isFirstRun()) {
                    Log.d(TAG, "First run detected, initializing defaults")
                    initializeFirstRun()
                }
                
                // Schedule background workers
                scheduleBackgroundWork()
                
                // Start health monitoring service
                startHealthMonitoringService()
                
                // Initialize paired services if already paired
                if (preferencesManager.isPaired()) {
                    initializePairedServices()
                }
                
                Log.d(TAG, "App initialization completed")
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize app", e)
            }
        }
    }
    
    private suspend fun initializeFirstRun() {
        // Set up default preferences
        preferencesManager.setFirstRun(false)
        preferencesManager.setLastAppVersion(BuildConfig.VERSION_CODE)
        
        // Initialize database with default data if needed
        val healthStatus = cacheRepository.performHealthCheck()
        Log.d(TAG, "Database health check: ${if (healthStatus.isHealthy) "OK" else "ERROR"}")
    }
    
    private fun scheduleBackgroundWork() {
        try {
            // Schedule periodic menu sync
            MenuSyncWorker.schedulePeriodicSync(this)
            
            // Schedule periodic update checks
            AutoUpdateWorker.schedulePeriodicUpdateCheck(this)
            
            Log.d(TAG, "Background work scheduled")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule background work", e)
        }
    }
    
    private fun startHealthMonitoringService() {
        try {
            HealthMonitoringService.startService(this)
            Log.d(TAG, "Health monitoring service started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start health monitoring service", e)
        }
    }
    
    private fun initializePairedServices() {
        lifecycleScope.launch {
            try {
                Log.d(TAG, "Initializing paired services...")
                
                // Connect to WebSocket
                webSocketClient.connect()
                
                // Trigger initial menu sync
                MenuSyncWorker.scheduleOneTimeSync(
                    context = this@MainActivity,
                    forceSync = false
                )
                
                Log.d(TAG, "Paired services initialized")
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize paired services", e)
            }
        }
    }
    
    private fun cleanupPairedServices() {
        lifecycleScope.launch {
            try {
                Log.d(TAG, "Cleaning up paired services...")
                
                // Disconnect WebSocket
                webSocketClient.disconnect()
                
                // Cancel sync workers
                MenuSyncWorker.cancelAllSync(this@MainActivity)
                
                // Clear user data from preferences
                preferencesManager.clearUserData()
                
                // Clear cached data
                cacheRepository.clearAllData()
                
                Log.d(TAG, "Paired services cleanup completed")
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cleanup paired services", e)
            }
        }
    }
    
    private fun cleanupApp() {
        lifecycleScope.launch {
            try {
                // Disconnect WebSocket
                webSocketClient.disconnect()
                
                // Stop health monitoring service
                HealthMonitoringService.stopService(this@MainActivity)
                
                // Cancel all background work
                MenuSyncWorker.cancelAllSync(this@MainActivity)
                AutoUpdateWorker.cancelAllUpdates(this@MainActivity)
                
                // Cleanup WebSocket resources
                webSocketClient.cleanup()
                
                Log.d(TAG, "App cleanup completed")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error during app cleanup", e)
            }
        }
    }
}