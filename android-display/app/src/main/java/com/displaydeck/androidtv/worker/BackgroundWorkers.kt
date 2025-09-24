package com.displaydeck.androidtv.worker

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.*
import com.displaydeck.androidtv.data.network.*
import com.displaydeck.androidtv.data.repository.*
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import android.util.Log
import java.util.concurrent.TimeUnit

/**
 * Background worker for sending periodic heartbeat to server
 */
@HiltWorker
class HeartbeatWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted workerParams: WorkerParameters,
    private val apiService: ApiService,
    private val displaySettingsRepository: DisplaySettingsRepository,
    private val webSocketService: WebSocketService
) : CoroutineWorker(context, workerParams) {

    companion object {
        private const val TAG = "HeartbeatWorker"
        const val WORK_NAME = "heartbeat_work"
        private const val RETRY_DELAY_SECONDS = 30L
    }

    override suspend fun doWork(): Result {
        return try {
            Log.d(TAG, "Sending heartbeat")
            
            val displaySettings = displaySettingsRepository.getDisplaySettings()
            if (displaySettings?.isPaired != true) {
                Log.w(TAG, "Display not paired, skipping heartbeat")
                return Result.success()
            }

            // Send HTTP heartbeat to API
            sendHttpHeartbeat(displaySettings.id)
            
            // Send WebSocket heartbeat if connected
            if (webSocketService.isConnected()) {
                webSocketService.sendHeartbeat()
                Log.d(TAG, "WebSocket heartbeat sent")
            } else {
                Log.w(TAG, "WebSocket not connected, skipping WS heartbeat")
            }
            
            Log.d(TAG, "Heartbeat completed successfully")
            Result.success()
            
        } catch (e: Exception) {
            Log.e(TAG, "Heartbeat failed", e)
            
            if (runAttemptCount < 2) {
                Log.i(TAG, "Retrying heartbeat (attempt ${runAttemptCount + 1}/2)")
                Result.retry()
            } else {
                // Don't fail the worker completely for heartbeat issues
                Log.w(TAG, "Heartbeat failed after 2 attempts, continuing")
                Result.success()
            }
        }
    }

    private suspend fun sendHttpHeartbeat(displayId: Int) {
        try {
            val result = safeApiCall { apiService.sendHeartbeat(displayId) }
            
            when (result) {
                is ApiResult.Success -> {
                    Log.d(TAG, "HTTP heartbeat sent successfully")
                }
                
                is ApiResult.Error -> {
                    Log.e(TAG, "HTTP heartbeat failed: ${result.message}")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error sending HTTP heartbeat", e)
            throw e
        }
    }
}

/**
 * Background worker for cache cleanup tasks
 */
@HiltWorker
class CacheCleanupWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted workerParams: WorkerParameters,
    private val menuCacheRepository: MenuCacheRepository,
    private val businessCacheRepository: BusinessCacheRepository,
    private val mediaCacheRepository: MediaCacheRepository
) : CoroutineWorker(context, workerParams) {

    companion object {
        private const val TAG = "CacheCleanupWorker"
        const val WORK_NAME = "cache_cleanup_work"
    }

    override suspend fun doWork(): Result {
        return try {
            Log.i(TAG, "Starting cache cleanup")
            
            // Clean up expired menu cache
            menuCacheRepository.cleanupExpiredMenus()
            Log.d(TAG, "Menu cache cleanup completed")
            
            // Clean up expired business cache
            businessCacheRepository.cleanupExpiredBusinesses()
            Log.d(TAG, "Business cache cleanup completed")
            
            // Clean up expired media cache and perform maintenance
            mediaCacheRepository.cleanupExpiredMedia()
            mediaCacheRepository.performCacheMaintenanceIfNeeded()
            Log.d(TAG, "Media cache cleanup completed")
            
            Log.i(TAG, "Cache cleanup completed successfully")
            Result.success()
            
        } catch (e: Exception) {
            Log.e(TAG, "Cache cleanup failed", e)
            Result.failure()
        }
    }
}

/**
 * Utility class for scheduling background work
 */
object WorkScheduler {
    
    /**
     * Schedule periodic heartbeat work
     */
    fun scheduleHeartbeat(context: Context, intervalMinutes: Long = 5) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val workRequest = PeriodicWorkRequestBuilder<HeartbeatWorker>(
            intervalMinutes, TimeUnit.MINUTES,
            1, TimeUnit.MINUTES // Flex interval
        )
            .setConstraints(constraints)
            .setBackoffCriteria(
                BackoffPolicy.LINEAR,
                HeartbeatWorker.RETRY_DELAY_SECONDS,
                TimeUnit.SECONDS
            )
            .build()

        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(
                HeartbeatWorker.WORK_NAME,
                ExistingPeriodicWorkPolicy.REPLACE,
                workRequest
            )
    }
    
    /**
     * Schedule periodic cache cleanup work
     */
    fun scheduleCacheCleanup(context: Context, intervalHours: Long = 24) {
        val constraints = Constraints.Builder()
            .setRequiresBatteryNotLow(true)
            .setRequiresDeviceIdle(true)
            .build()

        val workRequest = PeriodicWorkRequestBuilder<CacheCleanupWorker>(
            intervalHours, TimeUnit.HOURS,
            2, TimeUnit.HOURS // Flex interval
        )
            .setConstraints(constraints)
            .build()

        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(
                CacheCleanupWorker.WORK_NAME,
                ExistingPeriodicWorkPolicy.REPLACE,
                workRequest
            )
    }
    
    /**
     * Cancel heartbeat work
     */
    fun cancelHeartbeat(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(HeartbeatWorker.WORK_NAME)
    }
    
    /**
     * Cancel cache cleanup work
     */
    fun cancelCacheCleanup(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(CacheCleanupWorker.WORK_NAME)
    }
    
    /**
     * Cancel all background work
     */
    fun cancelAllWork(context: Context) {
        WorkManager.getInstance(context).cancelAllWork()
    }
    
    /**
     * Schedule all periodic work
     */
    fun scheduleAllPeriodicWork(context: Context) {
        scheduleHeartbeat(context)
        scheduleCacheCleanup(context)
        MenuSyncScheduler.schedulePeriodicSync(context)
    }
}