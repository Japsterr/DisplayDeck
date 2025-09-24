package com.displaydeck.androidtv.workers

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.*
import com.displaydeck.androidtv.network.NetworkClient
import com.displaydeck.androidtv.utils.PreferencesManager
import com.displaydeck.androidtv.BuildConfig
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okio.buffer
import okio.sink
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Background worker for automatic application updates.
 * Checks for updates, downloads APKs, and manages update installation.
 */
@HiltWorker
class AutoUpdateWorker @AssistedInject constructor(
    @Assisted private val context: Context,
    @Assisted private val workerParams: WorkerParameters,
    private val networkClient: NetworkClient,
    private val preferencesManager: PreferencesManager
) : CoroutineWorker(context, workerParams) {
    
    companion object {
        const val TAG = "AutoUpdateWorker"
        const val WORK_NAME = "auto_update_work"
        
        // Input parameters
        const val PARAM_FORCE_CHECK = "force_check"
        const val PARAM_AUTO_INSTALL = "auto_install"
        
        // Output data keys
        const val OUTPUT_UPDATE_RESULT = "update_result"
        const val OUTPUT_CURRENT_VERSION = "current_version"
        const val OUTPUT_AVAILABLE_VERSION = "available_version"
        const val OUTPUT_DOWNLOAD_URL = "download_url"
        const val OUTPUT_ERROR_MESSAGE = "error_message"
        
        /**
         * Schedule periodic update checks.
         */
        fun schedulePeriodicUpdateCheck(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .setRequiresBatteryNotLow(true)
                .setRequiresCharging(false) // Allow updates on battery for TV devices
                .build()
            
            val periodicWorkRequest = PeriodicWorkRequestBuilder<AutoUpdateWorker>(
                24, TimeUnit.HOURS, // Check daily
                2, TimeUnit.HOURS   // Flex interval
            )
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    WorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .addTag(TAG)
                .build()
            
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    periodicWorkRequest
                )
        }
        
        /**
         * Schedule one-time update check.
         */
        fun scheduleUpdateCheck(
            context: Context,
            forceCheck: Boolean = false,
            autoInstall: Boolean = false
        ) {
            val inputData = Data.Builder()
                .putBoolean(PARAM_FORCE_CHECK, forceCheck)
                .putBoolean(PARAM_AUTO_INSTALL, autoInstall)
                .build()
            
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            
            val oneTimeWorkRequest = OneTimeWorkRequestBuilder<AutoUpdateWorker>()
                .setConstraints(constraints)
                .setInputData(inputData)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    WorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .addTag(TAG)
                .build()
            
            WorkManager.getInstance(context)
                .enqueueUniqueWork(
                    "update_check_${System.currentTimeMillis()}",
                    ExistingWorkPolicy.REPLACE,
                    oneTimeWorkRequest
                )
        }
        
        /**
         * Cancel all update work.
         */
        fun cancelAllUpdates(context: Context) {
            WorkManager.getInstance(context).cancelAllWorkByTag(TAG)
        }
    }
    
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        Log.d(TAG, "Starting update check")
        
        try {
            val forceCheck = inputData.getBoolean(PARAM_FORCE_CHECK, false)
            val autoInstall = inputData.getBoolean(PARAM_AUTO_INSTALL, false)
            
            // Check if auto-updates are enabled
            if (!forceCheck && !preferencesManager.isAutoUpdateEnabled()) {
                Log.d(TAG, "Auto-updates disabled, skipping check")
                return@withContext Result.success(
                    Data.Builder()
                        .putString(OUTPUT_UPDATE_RESULT, "disabled")
                        .build()
                )
            }
            
            val currentVersion = getCurrentVersionCode()
            val updateInfo = checkForUpdates(currentVersion)
            
            when (updateInfo) {
                is UpdateInfo.NoUpdate -> {
                    Log.d(TAG, "No update available")
                    Result.success(
                        Data.Builder()
                            .putString(OUTPUT_UPDATE_RESULT, "no_update")
                            .putInt(OUTPUT_CURRENT_VERSION, currentVersion)
                            .build()
                    )
                }
                
                is UpdateInfo.UpdateAvailable -> {
                    Log.d(TAG, "Update available: ${updateInfo.version}")
                    
                    val result = if (autoInstall || preferencesManager.isAutoInstallEnabled()) {
                        handleAutomaticUpdate(updateInfo)
                    } else {
                        // Just notify about available update
                        notifyUpdateAvailable(updateInfo)
                        UpdateResult.NotificationSent
                    }
                    
                    when (result) {
                        is UpdateResult.Success -> {
                            Result.success(
                                Data.Builder()
                                    .putString(OUTPUT_UPDATE_RESULT, "updated")
                                    .putInt(OUTPUT_CURRENT_VERSION, currentVersion)
                                    .putInt(OUTPUT_AVAILABLE_VERSION, updateInfo.versionCode)
                                    .build()
                            )
                        }
                        is UpdateResult.Downloaded -> {
                            Result.success(
                                Data.Builder()
                                    .putString(OUTPUT_UPDATE_RESULT, "downloaded")
                                    .putInt(OUTPUT_CURRENT_VERSION, currentVersion)
                                    .putInt(OUTPUT_AVAILABLE_VERSION, updateInfo.versionCode)
                                    .putString(OUTPUT_DOWNLOAD_URL, updateInfo.downloadUrl)
                                    .build()
                            )
                        }
                        is UpdateResult.NotificationSent -> {
                            Result.success(
                                Data.Builder()
                                    .putString(OUTPUT_UPDATE_RESULT, "notification_sent")
                                    .putInt(OUTPUT_CURRENT_VERSION, currentVersion)
                                    .putInt(OUTPUT_AVAILABLE_VERSION, updateInfo.versionCode)
                                    .putString(OUTPUT_DOWNLOAD_URL, updateInfo.downloadUrl)
                                    .build()
                            )
                        }
                        is UpdateResult.Failed -> {
                            Result.failure(
                                Data.Builder()
                                    .putString(OUTPUT_ERROR_MESSAGE, result.error)
                                    .build()
                            )
                        }
                    }
                }
                
                is UpdateInfo.Error -> {
                    Log.e(TAG, "Update check failed: ${updateInfo.error}")
                    Result.failure(
                        Data.Builder()
                            .putString(OUTPUT_ERROR_MESSAGE, updateInfo.error)
                            .build()
                    )
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error during update check", e)
            Result.failure(
                Data.Builder()
                    .putString(OUTPUT_ERROR_MESSAGE, e.message ?: "Unknown error")
                    .build()
            )
        }
    }
    
    private fun getCurrentVersionCode(): Int {
        return try {
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            packageInfo.versionCode
        } catch (e: PackageManager.NameNotFoundException) {
            Log.e(TAG, "Failed to get current version code", e)
            BuildConfig.VERSION_CODE
        }
    }
    
    private suspend fun checkForUpdates(currentVersion: Int): UpdateInfo {
        return try {
            // In a real implementation, this would call your update API
            // For now, we'll simulate the update check
            
            val displayId = preferencesManager.getDisplayId()
            val accessToken = preferencesManager.getAccessToken()
            
            if (displayId == null || accessToken == null) {
                return UpdateInfo.Error("Authentication required")
            }
            
            // Simulate API call to check for updates
            // This would be replaced with actual API endpoint
            val updateCheckUrl = "${preferencesManager.getServerUrl()}/updates/check"
            
            val client = OkHttpClient.Builder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .build()
            
            val request = Request.Builder()
                .url("$updateCheckUrl?currentVersion=$currentVersion&displayId=$displayId")
                .header("Authorization", "Bearer $accessToken")
                .build()
            
            val response = client.newCall(request).execute()
            
            if (response.isSuccessful) {
                val responseBody = response.body?.string()
                // Parse response and return appropriate UpdateInfo
                // For now, simulate no update available
                UpdateInfo.NoUpdate
            } else {
                UpdateInfo.Error("Update check failed: ${response.code}")
            }
            
        } catch (e: Exception) {
            UpdateInfo.Error("Network error: ${e.message}")
        }
    }
    
    private suspend fun handleAutomaticUpdate(updateInfo: UpdateInfo.UpdateAvailable): UpdateResult {
        return try {
            Log.d(TAG, "Starting automatic update download")
            
            // Download the update
            val downloadResult = downloadUpdate(updateInfo)
            
            when (downloadResult) {
                is DownloadResult.Success -> {
                    Log.d(TAG, "Update downloaded successfully: ${downloadResult.filePath}")
                    
                    // Install if enabled
                    if (preferencesManager.isAutoInstallEnabled()) {
                        installUpdate(downloadResult.filePath)
                        UpdateResult.Success
                    } else {
                        UpdateResult.Downloaded
                    }
                }
                is DownloadResult.Failed -> {
                    UpdateResult.Failed(downloadResult.error)
                }
            }
            
        } catch (e: Exception) {
            UpdateResult.Failed("Update failed: ${e.message}")
        }
    }
    
    private suspend fun downloadUpdate(updateInfo: UpdateInfo.UpdateAvailable): DownloadResult {
        return try {
            val client = OkHttpClient.Builder()
                .connectTimeout(60, TimeUnit.SECONDS)
                .readTimeout(60, TimeUnit.SECONDS)
                .build()
            
            val request = Request.Builder()
                .url(updateInfo.downloadUrl)
                .build()
            
            val response = client.newCall(request).execute()
            
            if (!response.isSuccessful) {
                return DownloadResult.Failed("Download failed: ${response.code}")
            }
            
            val body = response.body ?: return DownloadResult.Failed("Empty response body")
            
            // Save to downloads directory
            val downloadsDir = File(context.getExternalFilesDir(null), "downloads")
            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }
            
            val apkFile = File(downloadsDir, "displaydeck-${updateInfo.versionName}.apk")
            
            val sink = apkFile.sink().buffer()
            sink.writeAll(body.source())
            sink.close()
            
            Log.d(TAG, "Update downloaded to: ${apkFile.absolutePath}")
            DownloadResult.Success(apkFile.absolutePath)
            
        } catch (e: Exception) {
            DownloadResult.Failed("Download error: ${e.message}")
        }
    }
    
    private suspend fun installUpdate(apkFilePath: String): Boolean {
        return try {
            val apkFile = File(apkFilePath)
            
            if (!apkFile.exists()) {
                Log.e(TAG, "APK file not found: $apkFilePath")
                return false
            }
            
            // Create install intent
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.fromFile(apkFile), "application/vnd.android.package-archive")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            
            context.startActivity(intent)
            
            Log.d(TAG, "Update installation started")
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to install update", e)
            false
        }
    }
    
    private suspend fun notifyUpdateAvailable(updateInfo: UpdateInfo.UpdateAvailable) {
        // Create notification about available update
        // This would show a notification that allows user to manually update
        Log.d(TAG, "Notifying user about available update: ${updateInfo.versionName}")
        
        // Store update info for later use
        preferencesManager.setAvailableUpdateInfo(
            updateInfo.versionCode,
            updateInfo.versionName,
            updateInfo.downloadUrl,
            updateInfo.releaseNotes
        )
    }
}

/**
 * Sealed class for update information.
 */
sealed class UpdateInfo {
    object NoUpdate : UpdateInfo()
    data class UpdateAvailable(
        val versionCode: Int,
        val versionName: String,
        val downloadUrl: String,
        val releaseNotes: String,
        val isForced: Boolean = false,
        val minVersionSupported: Int? = null
    ) : UpdateInfo()
    data class Error(val error: String) : UpdateInfo()
}

/**
 * Sealed class for update results.
 */
sealed class UpdateResult {
    object Success : UpdateResult()
    object Downloaded : UpdateResult()
    object NotificationSent : UpdateResult()
    data class Failed(val error: String) : UpdateResult()
}

/**
 * Sealed class for download results.
 */
sealed class DownloadResult {
    data class Success(val filePath: String) : DownloadResult()
    data class Failed(val error: String) : DownloadResult()
}