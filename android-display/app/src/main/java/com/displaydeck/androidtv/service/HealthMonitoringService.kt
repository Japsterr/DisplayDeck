package com.displaydeck.androidtv.service

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.BatteryManager
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.roundToInt

/**
 * Service for monitoring system health and connectivity
 */
@Singleton
class HealthMonitoringService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    
    companion object {
        private const val TAG = "HealthMonitoringService"
    }
    
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
    
    // Health status flows
    private val _connectionStatus = MutableStateFlow(ConnectionStatus.UNKNOWN)
    val connectionStatus: StateFlow<ConnectionStatus> = _connectionStatus.asStateFlow()
    
    private val _signalStrength = MutableStateFlow(SignalStrength.UNKNOWN)
    val signalStrength: StateFlow<SignalStrength> = _signalStrength.asStateFlow()
    
    private val _batteryStatus = MutableStateFlow(BatteryStatus())
    val batteryStatus: StateFlow<BatteryStatus> = _batteryStatus.asStateFlow()
    
    private val _systemHealth = MutableStateFlow(SystemHealth())
    val systemHealth: StateFlow<SystemHealth> = _systemHealth.asStateFlow()
    
    private val _isMonitoring = MutableStateFlow(false)
    val isMonitoring: StateFlow<Boolean> = _isMonitoring.asStateFlow()
    
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    
    /**
     * Start health monitoring
     */
    fun startMonitoring() {
        if (_isMonitoring.value) return
        
        Log.i(TAG, "Starting health monitoring")
        
        _isMonitoring.value = true
        
        // Start network monitoring
        startNetworkMonitoring()
        
        // Initial health check
        updateSystemHealth()
        updateBatteryStatus()
        
        Log.i(TAG, "Health monitoring started")
    }
    
    /**
     * Stop health monitoring
     */
    fun stopMonitoring() {
        if (!_isMonitoring.value) return
        
        Log.i(TAG, "Stopping health monitoring")
        
        _isMonitoring.value = false
        
        // Stop network monitoring
        stopNetworkMonitoring()
        
        Log.i(TAG, "Health monitoring stopped")
    }
    
    /**
     * Get current system health snapshot
     */
    fun getCurrentHealthSnapshot(): HealthSnapshot {
        updateSystemHealth()
        updateBatteryStatus()
        
        return HealthSnapshot(
            connectionStatus = _connectionStatus.value,
            signalStrength = _signalStrength.value,
            batteryStatus = _batteryStatus.value,
            systemHealth = _systemHealth.value,
            timestamp = System.currentTimeMillis()
        )
    }
    
    /**
     * Start network connectivity monitoring
     */
    private fun startNetworkMonitoring() {
        try {
            val networkRequest = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .addCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
                .build()
            
            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    Log.d(TAG, "Network available: $network")
                    updateConnectionStatus()
                }
                
                override fun onLost(network: Network) {
                    Log.d(TAG, "Network lost: $network")
                    updateConnectionStatus()
                }
                
                override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
                    Log.d(TAG, "Network capabilities changed: $network")
                    updateConnectionStatus()
                    updateSignalStrength(networkCapabilities)
                }
                
                override fun onUnavailable() {
                    Log.d(TAG, "Network unavailable")
                    _connectionStatus.value = ConnectionStatus.DISCONNECTED
                    _signalStrength.value = SignalStrength.NONE
                }
            }
            
            connectivityManager.registerNetworkCallback(networkRequest, networkCallback!!)
            
            // Initial connection status
            updateConnectionStatus()
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start network monitoring", e)
        }
    }
    
    /**
     * Stop network connectivity monitoring
     */
    private fun stopNetworkMonitoring() {
        try {
            networkCallback?.let { callback ->
                connectivityManager.unregisterNetworkCallback(callback)
                networkCallback = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop network monitoring", e)
        }
    }
    
    /**
     * Update connection status
     */
    private fun updateConnectionStatus() {
        try {
            val activeNetwork = connectivityManager.activeNetwork
            val networkCapabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
            
            val status = when {
                networkCapabilities == null -> ConnectionStatus.DISCONNECTED
                networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) -> {
                    when {
                        networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> ConnectionStatus.WIFI
                        networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> ConnectionStatus.ETHERNET
                        networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> ConnectionStatus.CELLULAR
                        else -> ConnectionStatus.CONNECTED
                    }
                }
                else -> ConnectionStatus.LIMITED
            }
            
            _connectionStatus.value = status
            Log.d(TAG, "Connection status updated: $status")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update connection status", e)
            _connectionStatus.value = ConnectionStatus.UNKNOWN
        }
    }
    
    /**
     * Update signal strength
     */
    private fun updateSignalStrength(networkCapabilities: NetworkCapabilities) {
        try {
            val signalStrength = networkCapabilities.signalStrength
            
            val strength = when {
                signalStrength == Int.MIN_VALUE -> SignalStrength.UNKNOWN
                signalStrength >= -50 -> SignalStrength.EXCELLENT
                signalStrength >= -60 -> SignalStrength.GOOD
                signalStrength >= -70 -> SignalStrength.FAIR
                signalStrength >= -80 -> SignalStrength.POOR
                else -> SignalStrength.WEAK
            }
            
            _signalStrength.value = strength
            Log.d(TAG, "Signal strength updated: $strength (dBm: $signalStrength)")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update signal strength", e)
            _signalStrength.value = SignalStrength.UNKNOWN
        }
    }
    
    /**
     * Update battery status
     */
    private fun updateBatteryStatus() {
        try {
            val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            val isCharging = batteryManager.isCharging
            val temperature = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_AVERAGE)
            
            val status = BatteryStatus(
                level = level,
                isCharging = isCharging,
                temperature = temperature,
                status = when {
                    level >= 75 -> BatteryHealthStatus.GOOD
                    level >= 50 -> BatteryHealthStatus.MODERATE
                    level >= 25 -> BatteryHealthStatus.LOW
                    else -> BatteryHealthStatus.CRITICAL
                }
            )
            
            _batteryStatus.value = status
            Log.d(TAG, "Battery status updated: ${status.level}% (charging: ${status.isCharging})")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update battery status", e)
        }
    }
    
    /**
     * Update system health metrics
     */
    private fun updateSystemHealth() {
        try {
            val runtime = Runtime.getRuntime()
            val maxMemory = runtime.maxMemory()
            val totalMemory = runtime.totalMemory()
            val freeMemory = runtime.freeMemory()
            val usedMemory = totalMemory - freeMemory
            
            val memoryUsagePercent = ((usedMemory.toDouble() / maxMemory.toDouble()) * 100).roundToInt()
            val availableMemoryMB = (maxMemory - usedMemory) / (1024 * 1024)
            val uptime = android.os.SystemClock.elapsedRealtime()
            
            val health = SystemHealth(
                memoryUsagePercent = memoryUsagePercent,
                availableMemoryMB = availableMemoryMB,
                uptimeMillis = uptime,
                cpuTemperature = getCpuTemperature(),
                status = when {
                    memoryUsagePercent >= 90 -> SystemHealthStatus.CRITICAL
                    memoryUsagePercent >= 75 -> SystemHealthStatus.WARNING
                    memoryUsagePercent >= 60 -> SystemHealthStatus.MODERATE
                    else -> SystemHealthStatus.GOOD
                }
            )
            
            _systemHealth.value = health
            Log.d(TAG, "System health updated: Memory ${health.memoryUsagePercent}%, Available ${health.availableMemoryMB}MB")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update system health", e)
        }
    }
    
    /**
     * Get CPU temperature (best effort)
     */
    private fun getCpuTemperature(): Float {
        return try {
            // This is device-specific and may not work on all Android TV devices
            val process = Runtime.getRuntime().exec("cat /sys/class/thermal/thermal_zone0/temp")
            val temperature = process.inputStream.bufferedReader().readLine().toFloat() / 1000
            temperature
        } catch (e: Exception) {
            -1f // Unknown temperature
        }
    }
}

// Data classes for health monitoring

enum class ConnectionStatus {
    UNKNOWN,
    DISCONNECTED,
    LIMITED,
    CONNECTED,
    WIFI,
    ETHERNET,
    CELLULAR
}

enum class SignalStrength {
    UNKNOWN,
    NONE,
    WEAK,
    POOR,
    FAIR,
    GOOD,
    EXCELLENT
}

data class BatteryStatus(
    val level: Int = 0,
    val isCharging: Boolean = false,
    val temperature: Int = 0,
    val status: BatteryHealthStatus = BatteryHealthStatus.UNKNOWN
)

enum class BatteryHealthStatus {
    UNKNOWN,
    CRITICAL,
    LOW,
    MODERATE,
    GOOD
}

data class SystemHealth(
    val memoryUsagePercent: Int = 0,
    val availableMemoryMB: Long = 0,
    val uptimeMillis: Long = 0,
    val cpuTemperature: Float = -1f,
    val status: SystemHealthStatus = SystemHealthStatus.UNKNOWN
)

enum class SystemHealthStatus {
    UNKNOWN,
    CRITICAL,
    WARNING,
    MODERATE,
    GOOD
}

data class HealthSnapshot(
    val connectionStatus: ConnectionStatus,
    val signalStrength: SignalStrength,
    val batteryStatus: BatteryStatus,
    val systemHealth: SystemHealth,
    val timestamp: Long
)