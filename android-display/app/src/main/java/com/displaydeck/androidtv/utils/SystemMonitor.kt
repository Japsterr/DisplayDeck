package com.displaydeck.androidtv.utils

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.StatFs
import android.os.SystemClock
import android.util.Log
import androidx.annotation.RequiresApi
import java.io.File
import java.io.RandomAccessFile
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.roundToInt

/**
 * System monitoring utility for collecting device health metrics.
 * Provides CPU, memory, storage, battery, and temperature monitoring.
 */
@Singleton
class SystemMonitor @Inject constructor(
    private val context: Context
) {
    
    companion object {
        private const val TAG = "SystemMonitor"
        private const val TEMP_FILE_PATH = "/sys/class/thermal/thermal_zone0/temp"
        private const val CPU_STAT_FILE = "/proc/stat"
        private const val MEMINFO_FILE = "/proc/meminfo"
    }
    
    private val activityManager: ActivityManager by lazy {
        context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    }
    
    private val batteryManager: BatteryManager? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        } else {
            null
        }
    }
    
    private var lastCpuTotal = 0L
    private var lastCpuIdle = 0L
    private var lastMeasureTime = 0L
    private val systemErrors = mutableListOf<String>()
    
    /**
     * Get current CPU usage percentage.
     */
    fun getCpuUsage(): Int {
        return try {
            val currentTime = System.currentTimeMillis()
            
            // Don't calculate if less than 1 second since last measurement
            if (currentTime - lastMeasureTime < 1000) {
                return 0
            }
            
            val cpuInfo = readCpuInfo()
            
            if (lastCpuTotal == 0L) {
                // First measurement, just store values
                lastCpuTotal = cpuInfo.total
                lastCpuIdle = cpuInfo.idle
                lastMeasureTime = currentTime
                return 0
            }
            
            val totalDiff = cpuInfo.total - lastCpuTotal
            val idleDiff = cpuInfo.idle - lastCpuIdle
            
            val usage = if (totalDiff > 0) {
                ((totalDiff - idleDiff) * 100.0 / totalDiff).roundToInt()
            } else {
                0
            }
            
            lastCpuTotal = cpuInfo.total
            lastCpuIdle = cpuInfo.idle
            lastMeasureTime = currentTime
            
            usage.coerceIn(0, 100)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get CPU usage", e)
            addSystemError("CPU usage monitoring failed: ${e.message}")
            0
        }
    }
    
    /**
     * Get current memory usage percentage.
     */
    fun getMemoryUsage(): Int {
        return try {
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)
            
            val usedMemory = memoryInfo.totalMem - memoryInfo.availMem
            val usagePercentage = (usedMemory * 100.0 / memoryInfo.totalMem).roundToInt()
            
            usagePercentage.coerceIn(0, 100)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get memory usage", e)
            addSystemError("Memory usage monitoring failed: ${e.message}")
            0
        }
    }
    
    /**
     * Get current storage usage percentage.
     */
    fun getStorageUsage(): Int {
        return try {
            val statFs = StatFs(context.filesDir.absolutePath)
            
            val totalBytes = statFs.totalBytes
            val availableBytes = statFs.availableBytes
            val usedBytes = totalBytes - availableBytes
            
            val usagePercentage = (usedBytes * 100.0 / totalBytes).roundToInt()
            
            usagePercentage.coerceIn(0, 100)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get storage usage", e)
            addSystemError("Storage usage monitoring failed: ${e.message}")
            0
        }
    }
    
    /**
     * Get current battery level percentage.
     * Returns null if battery information is not available (e.g., on TVs without battery).
     */
    fun getBatteryLevel(): Int? {
        return try {
            val batteryIntentFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            val batteryStatus = context.registerReceiver(null, batteryIntentFilter)
            
            batteryStatus?.let {
                val level = it.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = it.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                
                if (level != -1 && scale != -1) {
                    ((level * 100.0) / scale).roundToInt().coerceIn(0, 100)
                } else {
                    null
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get battery level", e)
            null
        }
    }
    
    /**
     * Get device temperature in Celsius.
     * Returns null if temperature is not available.
     */
    fun getTemperature(): Int? {
        return try {
            // Try reading from thermal zone
            val tempFile = File(TEMP_FILE_PATH)
            if (tempFile.exists() && tempFile.canRead()) {
                val tempString = tempFile.readText().trim()
                val tempMilliC = tempString.toLongOrNull()
                
                if (tempMilliC != null) {
                    // Convert from millidegrees to degrees Celsius
                    (tempMilliC / 1000).toInt()
                } else {
                    null
                }
            } else {
                // Try alternative method using battery manager (if available)
                getBatteryTemperature()
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get temperature", e)
            null
        }
    }
    
    /**
     * Get system uptime in milliseconds.
     */
    fun getUptime(): Long {
        return SystemClock.elapsedRealtime()
    }
    
    /**
     * Get network latency by measuring response time to local server.
     * Returns latency in milliseconds, or -1 if measurement failed.
     */
    fun getNetworkLatency(): Long {
        return try {
            val startTime = System.currentTimeMillis()
            
            // This is a simplified implementation
            // In a real app, you might ping the server or use other network tests
            val runtime = Runtime.getRuntime()
            val process = runtime.exec("ping -c 1 8.8.8.8")
            process.waitFor()
            
            val endTime = System.currentTimeMillis()
            
            if (process.exitValue() == 0) {
                endTime - startTime
            } else {
                -1L
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to measure network latency", e)
            -1L
        }
    }
    
    /**
     * Get list of system errors collected during monitoring.
     */
    fun getSystemErrors(): List<String> {
        return systemErrors.toList()
    }
    
    /**
     * Get count of critical system errors.
     */
    fun getCriticalErrorCount(): Int {
        return systemErrors.count { error ->
            error.contains("critical", ignoreCase = true) ||
            error.contains("failed", ignoreCase = true) ||
            error.contains("error", ignoreCase = true)
        }
    }
    
    /**
     * Get last system restart time as ISO string.
     */
    fun getLastRestartTime(): String? {
        return try {
            val bootTime = System.currentTimeMillis() - SystemClock.elapsedRealtime()
            java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US).apply {
                timeZone = java.util.TimeZone.getTimeZone("UTC")
            }.format(java.util.Date(bootTime))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get last restart time", e)
            null
        }
    }
    
    /**
     * Clear accumulated system errors.
     */
    fun clearSystemErrors() {
        systemErrors.clear()
    }
    
    /**
     * Get comprehensive system health report.
     */
    fun getSystemHealthReport(): SystemHealthReport {
        return SystemHealthReport(
            cpuUsage = getCpuUsage(),
            memoryUsage = getMemoryUsage(),
            storageUsage = getStorageUsage(),
            batteryLevel = getBatteryLevel(),
            temperature = getTemperature(),
            uptime = getUptime(),
            networkLatency = getNetworkLatency(),
            errorCount = systemErrors.size,
            criticalErrorCount = getCriticalErrorCount(),
            timestamp = System.currentTimeMillis()
        )
    }
    
    private fun readCpuInfo(): CpuInfo {
        return try {
            val statFile = File(CPU_STAT_FILE)
            if (!statFile.exists() || !statFile.canRead()) {
                return CpuInfo(0, 0)
            }
            
            val firstLine = statFile.readLines().firstOrNull() ?: return CpuInfo(0, 0)
            val values = firstLine.split("\\s+".toRegex()).drop(1).mapNotNull { it.toLongOrNull() }
            
            if (values.size < 4) {
                return CpuInfo(0, 0)
            }
            
            val idle = values[3]
            val total = values.sum()
            
            CpuInfo(total, idle)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read CPU info", e)
            CpuInfo(0, 0)
        }
    }
    
    private fun getBatteryTemperature(): Int? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && batteryManager != null) {
                val temperature = batteryManager!!.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
                if (temperature != Integer.MIN_VALUE) {
                    // Battery temperature is in tenths of degree Celsius
                    temperature / 10
                } else {
                    null
                }
            } else {
                // Fallback for older devices
                val batteryIntentFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                val batteryStatus = context.registerReceiver(null, batteryIntentFilter)
                
                batteryStatus?.let {
                    val temp = it.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1)
                    if (temp != -1) {
                        // Temperature is in tenths of degree Celsius
                        temp / 10
                    } else {
                        null
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get battery temperature", e)
            null
        }
    }
    
    private fun addSystemError(error: String) {
        synchronized(systemErrors) {
            systemErrors.add("${System.currentTimeMillis()}: $error")
            
            // Keep only last 50 errors to prevent memory issues
            if (systemErrors.size > 50) {
                systemErrors.removeAt(0)
            }
        }
    }
    
    /**
     * Data class for CPU information.
     */
    private data class CpuInfo(
        val total: Long,
        val idle: Long
    )
}

/**
 * Data class for system health report.
 */
data class SystemHealthReport(
    val cpuUsage: Int,
    val memoryUsage: Int,
    val storageUsage: Int,
    val batteryLevel: Int?,
    val temperature: Int?,
    val uptime: Long,
    val networkLatency: Long,
    val errorCount: Int,
    val criticalErrorCount: Int,
    val timestamp: Long
) {
    
    /**
     * Overall health score (0-100).
     */
    val healthScore: Int
        get() {
            var score = 100
            
            // Deduct points for high resource usage
            if (cpuUsage > 80) score -= 20
            else if (cpuUsage > 60) score -= 10
            
            if (memoryUsage > 90) score -= 20
            else if (memoryUsage > 70) score -= 10
            
            if (storageUsage > 95) score -= 20
            else if (storageUsage > 80) score -= 10
            
            // Deduct points for temperature issues
            temperature?.let { temp ->
                if (temp > 70) score -= 15
                else if (temp > 60) score -= 5
            }
            
            // Deduct points for network issues
            if (networkLatency == -1L) score -= 10
            else if (networkLatency > 1000) score -= 5
            
            // Deduct points for errors
            score -= (criticalErrorCount * 5)
            score -= (errorCount * 2)
            
            return score.coerceIn(0, 100)
    }
    
    /**
     * Health status based on score.
     */
    val healthStatus: String
        get() = when {
            healthScore >= 80 -> "Healthy"
            healthScore >= 60 -> "Good"
            healthScore >= 40 -> "Warning"
            healthScore >= 20 -> "Critical"
            else -> "Severe"
        }
}