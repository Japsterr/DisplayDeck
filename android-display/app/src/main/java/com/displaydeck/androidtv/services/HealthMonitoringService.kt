package com.displaydeck.androidtv.services

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.displaydeck.androidtv.R
import com.displaydeck.androidtv.data.cache.CacheRepository
import com.displaydeck.androidtv.network.NetworkClient
import com.displaydeck.androidtv.network.WebSocketClient
import com.displaydeck.androidtv.network.HeartbeatRequest
import com.displaydeck.androidtv.network.SystemInfo
import com.displaydeck.androidtv.utils.PreferencesManager
import com.displaydeck.androidtv.utils.SystemMonitor
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import javax.inject.Inject

/**
 * Background service for health monitoring and heartbeat communication.
 * Monitors system health, maintains server connection, and handles display management.
 */
@AndroidEntryPoint
class HealthMonitoringService : Service() {
    
    companion object {
        private const val TAG = "HealthMonitoringService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "displaydeck_health_monitoring"
        private const val HEARTBEAT_INTERVAL_MS = 30_000L // 30 seconds
        private const val HEALTH_CHECK_INTERVAL_MS = 60_000L // 1 minute
        private const val RETRY_INTERVAL_MS = 10_000L // 10 seconds
        
        // Service actions
        const val ACTION_START_MONITORING = "start_monitoring"
        const val ACTION_STOP_MONITORING = "stop_monitoring"
        const val ACTION_FORCE_HEARTBEAT = "force_heartbeat"
        const val ACTION_CHECK_HEALTH = "check_health"
        
        /**
         * Start the health monitoring service.
         */
        fun startService(context: Context) {
            val intent = Intent(context, HealthMonitoringService::class.java).apply {
                action = ACTION_START_MONITORING
            }
            context.startForegroundService(intent)
        }
        
        /**
         * Stop the health monitoring service.
         */
        fun stopService(context: Context) {
            val intent = Intent(context, HealthMonitoringService::class.java).apply {
                action = ACTION_STOP_MONITORING
            }
            context.startService(intent)
        }
    }
    
    @Inject lateinit var cacheRepository: CacheRepository
    @Inject lateinit var networkClient: NetworkClient
    @Inject lateinit var webSocketClient: WebSocketClient
    @Inject lateinit var preferencesManager: PreferencesManager
    @Inject lateinit var systemMonitor: SystemMonitor
    
    private val binder = HealthMonitoringBinder()
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // Health status flows
    private val _healthStatus = MutableStateFlow(HealthStatus.UNKNOWN)
    val healthStatus: StateFlow<HealthStatus> = _healthStatus.asStateFlow()
    
    private val _connectionStatus = MutableStateFlow(ConnectionStatus.DISCONNECTED)
    val connectionStatus: StateFlow<ConnectionStatus> = _connectionStatus.asStateFlow()
    
    private val _systemMetrics = MutableStateFlow(SystemMetrics())
    val systemMetrics: StateFlow<SystemMetrics> = _systemMetrics.asStateFlow()
    
    private var heartbeatJob: Job? = null
    private var healthCheckJob: Job? = null
    private var monitoringJob: Job? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Health monitoring service created")
        
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        
        // Initialize monitoring
        startMonitoring()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service command received: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_START_MONITORING -> startMonitoring()
            ACTION_STOP_MONITORING -> stopMonitoring()
            ACTION_FORCE_HEARTBEAT -> forceHeartbeat()
            ACTION_CHECK_HEALTH -> checkSystemHealth()
        }
        
        return START_STICKY // Restart service if killed
    }
    
    override fun onBind(intent: Intent): IBinder = binder
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Health monitoring service destroyed")
        stopMonitoring()
        serviceScope.cancel()
    }
    
    private fun startMonitoring() {
        Log.d(TAG, "Starting health monitoring")
        _healthStatus.value = HealthStatus.STARTING
        
        // Start heartbeat job
        heartbeatJob?.cancel()
        heartbeatJob = serviceScope.launch {
            while (isActive) {
                try {
                    sendHeartbeat()
                    delay(HEARTBEAT_INTERVAL_MS)
                } catch (e: CancellationException) {
                    break
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending heartbeat", e)
                    delay(RETRY_INTERVAL_MS)
                }
            }
        }
        
        // Start health check job
        healthCheckJob?.cancel()
        healthCheckJob = serviceScope.launch {
            while (isActive) {
                try {
                    performHealthCheck()
                    delay(HEALTH_CHECK_INTERVAL_MS)
                } catch (e: CancellationException) {
                    break
                } catch (e: Exception) {
                    Log.e(TAG, "Error during health check", e)
                    delay(RETRY_INTERVAL_MS)
                }
            }
        }
        
        // Start system monitoring job
        monitoringJob?.cancel()
        monitoringJob = serviceScope.launch {
            while (isActive) {
                try {
                    updateSystemMetrics()
                    delay(5000) // Update every 5 seconds
                } catch (e: CancellationException) {
                    break
                } catch (e: Exception) {
                    Log.e(TAG, "Error updating system metrics", e)
                    delay(RETRY_INTERVAL_MS)
                }
            }
        }
        
        // Monitor WebSocket connection
        serviceScope.launch {
            webSocketClient.connectionState.collect { state ->
                _connectionStatus.value = when (state) {
                    com.displaydeck.androidtv.network.ConnectionState.CONNECTED -> ConnectionStatus.CONNECTED
                    com.displaydeck.androidtv.network.ConnectionState.CONNECTING -> ConnectionStatus.CONNECTING
                    com.displaydeck.androidtv.network.ConnectionState.DISCONNECTED -> ConnectionStatus.DISCONNECTED
                    com.displaydeck.androidtv.network.ConnectionState.ERROR -> ConnectionStatus.ERROR
                    else -> ConnectionStatus.DISCONNECTED
                }
                
                updateNotification()
            }
        }
        
        _healthStatus.value = HealthStatus.RUNNING
    }
    
    private fun stopMonitoring() {
        Log.d(TAG, "Stopping health monitoring")
        _healthStatus.value = HealthStatus.STOPPING
        
        heartbeatJob?.cancel()
        healthCheckJob?.cancel()
        monitoringJob?.cancel()
        
        _healthStatus.value = HealthStatus.STOPPED
    }
    
    private suspend fun sendHeartbeat() {
        try {
            val displayId = preferencesManager.getDisplayId()
            val accessToken = preferencesManager.getAccessToken()
            
            if (displayId == null || accessToken == null) {
                Log.w(TAG, "Cannot send heartbeat: missing credentials")
                return
            }
            
            val systemInfo = SystemInfo(
                batteryLevel = systemMonitor.getBatteryLevel(),
                memoryUsage = systemMonitor.getMemoryUsage(),
                storageUsage = systemMonitor.getStorageUsage(),
                temperature = systemMonitor.getTemperature(),
                uptime = systemMonitor.getUptime(),
                lastRestart = systemMonitor.getLastRestartTime()
            )
            
            val heartbeatRequest = HeartbeatRequest(
                timestamp = System.currentTimeMillis().toString(),
                status = getCurrentDisplayStatus(),
                systemInfo = systemInfo
            )
            
            val response = networkClient.apiService.sendHeartbeat(
                displayId,
                "Bearer $accessToken",
                heartbeatRequest
            )
            
            if (response.isSuccessful) {
                Log.d(TAG, "Heartbeat sent successfully")
                _connectionStatus.value = ConnectionStatus.CONNECTED
                
                // Process any commands received
                response.body()?.commands?.let { commands ->
                    processDisplayCommands(commands)
                }
            } else {
                Log.w(TAG, "Heartbeat failed: ${response.code()}")
                _connectionStatus.value = ConnectionStatus.ERROR
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Heartbeat error", e)
            _connectionStatus.value = ConnectionStatus.ERROR
        }
    }
    
    private suspend fun performHealthCheck() {
        try {
            val healthStatus = cacheRepository.performHealthCheck()
            val systemMetrics = collectSystemMetrics()
            
            // Update health status based on checks
            _healthStatus.value = when {
                !healthStatus.isHealthy -> HealthStatus.ERROR
                systemMetrics.criticalErrorCount > 0 -> HealthStatus.WARNING
                _connectionStatus.value == ConnectionStatus.ERROR -> HealthStatus.WARNING
                else -> HealthStatus.HEALTHY
            }
            
            // Log health summary
            Log.d(TAG, "Health check: ${_healthStatus.value}, " +
                    "DB: ${if (healthStatus.isHealthy) "OK" else "ERROR"}, " +
                    "Connection: ${_connectionStatus.value}")
            
            updateNotification()
            
        } catch (e: Exception) {
            Log.e(TAG, "Health check failed", e)
            _healthStatus.value = HealthStatus.ERROR
        }
    }
    
    private suspend fun updateSystemMetrics() {
        try {
            val metrics = collectSystemMetrics()
            _systemMetrics.value = metrics
            
            // Check for critical conditions
            if (metrics.criticalErrorCount > 0) {
                Log.w(TAG, "Critical system errors detected: ${metrics.errors}")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update system metrics", e)
        }
    }
    
    private suspend fun collectSystemMetrics(): SystemMetrics {
        return SystemMetrics(
            cpuUsage = systemMonitor.getCpuUsage(),
            memoryUsage = systemMonitor.getMemoryUsage(),
            diskUsage = systemMonitor.getStorageUsage(),
            batteryLevel = systemMonitor.getBatteryLevel(),
            temperature = systemMonitor.getTemperature(),
            uptime = systemMonitor.getUptime(),
            networkLatency = systemMonitor.getNetworkLatency(),
            errors = systemMonitor.getSystemErrors(),
            criticalErrorCount = systemMonitor.getCriticalErrorCount()
        )
    }
    
    private fun getCurrentDisplayStatus(): String {
        return when (_healthStatus.value) {
            HealthStatus.HEALTHY, HealthStatus.RUNNING -> "online"
            HealthStatus.WARNING -> "warning"
            HealthStatus.ERROR -> "error"
            else -> "unknown"
        }
    }
    
    private fun processDisplayCommands(commands: List<com.displaydeck.androidtv.network.DisplayCommand>) {
        serviceScope.launch {
            commands.forEach { command ->
                try {
                    Log.d(TAG, "Processing command: ${command.type}")
                    
                    when (command.type) {
                        "restart" -> handleRestartCommand(command)
                        "sync_menu" -> handleSyncMenuCommand(command)
                        "update_settings" -> handleUpdateSettingsCommand(command)
                        "health_check" -> handleHealthCheckCommand(command)
                        else -> Log.w(TAG, "Unknown command type: ${command.type}")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error processing command: ${command.type}", e)
                }
            }
        }
    }
    
    private suspend fun handleRestartCommand(command: com.displaydeck.androidtv.network.DisplayCommand) {
        Log.d(TAG, "Restart command received")
        
        // Graceful shutdown and restart
        // Note: In a real implementation, this might use the Android reboot permission
        // or trigger an app restart
        
        // For now, we'll just restart the service
        stopMonitoring()
        delay(2000)
        startMonitoring()
    }
    
    private suspend fun handleSyncMenuCommand(command: com.displaydeck.androidtv.network.DisplayCommand) {
        Log.d(TAG, "Sync menu command received")
        
        // Trigger menu synchronization
        com.displaydeck.androidtv.workers.MenuSyncWorker.scheduleOneTimeSync(
            this@HealthMonitoringService,
            forceSync = true
        )
    }
    
    private suspend fun handleUpdateSettingsCommand(command: com.displaydeck.androidtv.network.DisplayCommand) {
        Log.d(TAG, "Update settings command received")
        
        // Process settings update
        command.parameters?.let { params ->
            // Update local settings based on command parameters
            val displayId = preferencesManager.getDisplayId() ?: return
            
            // This would typically update display settings in the database
            // and apply them to the current display configuration
        }
    }
    
    private suspend fun handleHealthCheckCommand(command: com.displaydeck.androidtv.network.DisplayCommand) {
        Log.d(TAG, "Health check command received")
        
        // Force immediate health check
        performHealthCheck()
    }
    
    private fun forceHeartbeat() {
        serviceScope.launch {
            sendHeartbeat()
        }
    }
    
    private fun checkSystemHealth() {
        serviceScope.launch {
            performHealthCheck()
        }
    }
    
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "DisplayDeck Health Monitoring",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Monitors display health and maintains server connection"
            setShowBadge(false)
        }
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }
    
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DisplayDeck Monitor")
            .setContentText("Monitoring display health...")
            .setSmallIcon(R.drawable.ic_monitor) // You'll need to add this icon
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }
    
    private fun updateNotification() {
        val statusText = when (_healthStatus.value) {
            HealthStatus.HEALTHY -> "System healthy"
            HealthStatus.WARNING -> "System warnings detected"
            HealthStatus.ERROR -> "System errors detected"
            HealthStatus.RUNNING -> "Monitoring active"
            else -> "Monitoring..."
        }
        
        val connectionText = when (_connectionStatus.value) {
            ConnectionStatus.CONNECTED -> "Connected"
            ConnectionStatus.CONNECTING -> "Connecting..."
            ConnectionStatus.DISCONNECTED -> "Disconnected"
            ConnectionStatus.ERROR -> "Connection error"
        }
        
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("DisplayDeck Monitor")
            .setContentText("$statusText • $connectionText")
            .setSmallIcon(R.drawable.ic_monitor)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    /**
     * Binder for local service communication.
     */
    inner class HealthMonitoringBinder : Binder() {
        fun getService(): HealthMonitoringService = this@HealthMonitoringService
    }
}

/**
 * Health status enumeration.
 */
enum class HealthStatus {
    UNKNOWN,
    STARTING,
    RUNNING,
    HEALTHY,
    WARNING,
    ERROR,
    STOPPING,
    STOPPED
}

/**
 * Connection status enumeration.
 */
enum class ConnectionStatus {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    ERROR
}

/**
 * System metrics data class.
 */
data class SystemMetrics(
    val cpuUsage: Int = 0,
    val memoryUsage: Int = 0,
    val diskUsage: Int = 0,
    val batteryLevel: Int? = null,
    val temperature: Int? = null,
    val uptime: Long = 0,
    val networkLatency: Long = 0,
    val errors: List<String> = emptyList(),
    val criticalErrorCount: Int = 0
)