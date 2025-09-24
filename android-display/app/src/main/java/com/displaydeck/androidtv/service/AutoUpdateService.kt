package com.displaydeck.androidtv.service

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import com.displaydeck.androidtv.data.network.*
import com.displaydeck.androidtv.data.repository.DisplaySettingsRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Service for handling automatic updates and version management
 */
@Singleton
class AutoUpdateService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val apiService: ApiService,
    private val displaySettingsRepository: DisplaySettingsRepository
) {
    
    companion object {
        private const val TAG = "AutoUpdateService"
        private const val UPDATE_CHECK_INTERVAL_HOURS = 6L
        private const val FORCED_UPDATE_GRACE_PERIOD_HOURS = 24L
    }
    
    // Update status flows
    private val _updateStatus = MutableStateFlow(UpdateStatus.UNKNOWN)
    val updateStatus: StateFlow<UpdateStatus> = _updateStatus.asStateFlow()
    
    private val _availableUpdate = MutableStateFlow<UpdateInfo?>(null)
    val availableUpdate: StateFlow<UpdateInfo?> = _availableUpdate.asStateFlow()
    
    private val _updateProgress = MutableStateFlow(UpdateProgress())
    val updateProgress: StateFlow<UpdateProgress> = _updateProgress.asStateFlow()
    
    private var lastUpdateCheck: Long = 0L
    private var updateNotificationShown: Boolean = false
    
    /**
     * Check for available updates
     */
    suspend fun checkForUpdates(forceCheck: Boolean = false): UpdateCheckResult {
        return try {
            Log.i(TAG, "Checking for updates (force: $forceCheck)")
            
            // Check if enough time has passed since last check
            if (!forceCheck && shouldSkipUpdateCheck()) {
                Log.d(TAG, "Skipping update check (too soon)")
                return UpdateCheckResult.SKIPPED
            }
            
            _updateStatus.value = UpdateStatus.CHECKING
            
            // Get current app version
            val currentVersion = getCurrentAppVersion()
            Log.d(TAG, "Current app version: $currentVersion")
            
            // Check server for latest version
            val result = safeApiCall { apiService.getVersion() }
            
            when (result) {
                is ApiResult.Success -> {
                    val versionData = result.data
                    val latestVersion = versionData["android_tv_version"] ?: currentVersion
                    val downloadUrl = versionData["android_tv_download_url"]
                    val releaseNotes = versionData["android_tv_release_notes"]
                    val isForced = versionData["android_tv_force_update"]?.toBoolean() ?: false
                    val minimumVersion = versionData["android_tv_minimum_version"]
                    
                    lastUpdateCheck = System.currentTimeMillis()
                    
                    if (isNewerVersion(currentVersion, latestVersion)) {
                        val updateInfo = UpdateInfo(
                            currentVersion = currentVersion,
                            availableVersion = latestVersion,
                            downloadUrl = downloadUrl,
                            releaseNotes = releaseNotes,
                            isForced = isForced || isVersionBelowMinimum(currentVersion, minimumVersion),
                            size = versionData["android_tv_size"]?.toLongOrNull(),
                            releaseDate = versionData["android_tv_release_date"]
                        )
                        
                        _availableUpdate.value = updateInfo
                        _updateStatus.value = if (updateInfo.isForced) UpdateStatus.FORCED_AVAILABLE else UpdateStatus.AVAILABLE
                        
                        Log.i(TAG, "Update available: $latestVersion (forced: ${updateInfo.isForced})")
                        return UpdateCheckResult.UPDATE_AVAILABLE
                        
                    } else {
                        _updateStatus.value = UpdateStatus.UP_TO_DATE
                        _availableUpdate.value = null
                        
                        Log.i(TAG, "App is up to date")
                        return UpdateCheckResult.UP_TO_DATE
                    }
                }
                
                is ApiResult.Error -> {
                    Log.e(TAG, "Failed to check for updates: ${result.message}")
                    _updateStatus.value = UpdateStatus.ERROR
                    return UpdateCheckResult.ERROR
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Update check failed", e)
            _updateStatus.value = UpdateStatus.ERROR
            return UpdateCheckResult.ERROR
        }
    }
    
    /**
     * Start downloading available update
     */
    suspend fun downloadUpdate(): UpdateDownloadResult {
        val updateInfo = _availableUpdate.value
        if (updateInfo?.downloadUrl == null) {
            Log.w(TAG, "No update available for download")
            return UpdateDownloadResult.NO_UPDATE_AVAILABLE
        }
        
        return try {
            Log.i(TAG, "Starting update download: ${updateInfo.availableVersion}")
            
            _updateStatus.value = UpdateStatus.DOWNLOADING
            _updateProgress.value = UpdateProgress(
                phase = UpdatePhase.DOWNLOADING,
                progressPercent = 0,
                message = "Downloading update..."
            )
            
            // In a real implementation, you would download the APK
            // For Android TV, this typically involves using a system update API
            // or directing users to the Play Store
            
            // Simulate download progress
            simulateDownloadProgress()
            
            _updateStatus.value = UpdateStatus.READY_TO_INSTALL
            _updateProgress.value = UpdateProgress(
                phase = UpdatePhase.READY,
                progressPercent = 100,
                message = "Update ready to install"
            )
            
            Log.i(TAG, "Update download completed")
            return UpdateDownloadResult.SUCCESS
            
        } catch (e: Exception) {
            Log.e(TAG, "Update download failed", e)
            _updateStatus.value = UpdateStatus.ERROR
            _updateProgress.value = UpdateProgress(
                phase = UpdatePhase.ERROR,
                progressPercent = 0,
                message = "Download failed: ${e.message}"
            )
            return UpdateDownloadResult.FAILED
        }
    }
    
    /**
     * Install downloaded update
     */
    suspend fun installUpdate(): UpdateInstallResult {
        if (_updateStatus.value != UpdateStatus.READY_TO_INSTALL) {
            Log.w(TAG, "No update ready to install")
            return UpdateInstallResult.NO_UPDATE_READY
        }
        
        return try {
            Log.i(TAG, "Starting update installation")
            
            _updateStatus.value = UpdateStatus.INSTALLING
            _updateProgress.value = UpdateProgress(
                phase = UpdatePhase.INSTALLING,
                progressPercent = 0,
                message = "Installing update..."
            )
            
            // In a real implementation, this would:
            // 1. Verify the downloaded APK
            // 2. Request system permissions for installation
            // 3. Install using system APIs or direct users to manual installation
            
            // For Android TV, typically this involves:
            // - Using PackageInstaller APIs
            // - Or directing users to system update mechanism
            // - Or using enterprise device management APIs
            
            // Simulate installation progress
            simulateInstallationProgress()
            
            _updateStatus.value = UpdateStatus.COMPLETED
            _updateProgress.value = UpdateProgress(
                phase = UpdatePhase.COMPLETED,
                progressPercent = 100,
                message = "Update installed successfully"
            )
            
            Log.i(TAG, "Update installation completed")
            return UpdateInstallResult.SUCCESS
            
        } catch (e: Exception) {
            Log.e(TAG, "Update installation failed", e)
            _updateStatus.value = UpdateStatus.ERROR
            _updateProgress.value = UpdateProgress(
                phase = UpdatePhase.ERROR,
                progressPercent = 0,
                message = "Installation failed: ${e.message}"
            )
            return UpdateInstallResult.FAILED
        }
    }
    
    /**
     * Postpone forced update (if allowed)
     */
    suspend fun postponeForcedUpdate(): Boolean {
        val updateInfo = _availableUpdate.value
        if (updateInfo?.isForced != true) {
            return false
        }
        
        // Check if grace period allows postponement
        val gracePeriodEnd = lastUpdateCheck + (FORCED_UPDATE_GRACE_PERIOD_HOURS * 60 * 60 * 1000)
        if (System.currentTimeMillis() > gracePeriodEnd) {
            Log.w(TAG, "Grace period expired, cannot postpone forced update")
            return false
        }
        
        Log.i(TAG, "Forced update postponed")
        return true
    }
    
    /**
     * Get current app version
     */
    private fun getCurrentAppVersion(): String {
        return try {
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            packageInfo.versionName ?: "unknown"
        } catch (e: PackageManager.NameNotFoundException) {
            Log.e(TAG, "Failed to get app version", e)
            "unknown"
        }
    }
    
    /**
     * Compare version strings
     */
    private fun isNewerVersion(current: String, available: String): Boolean {
        return try {
            val currentParts = current.split(".").map { it.toIntOrNull() ?: 0 }
            val availableParts = available.split(".").map { it.toIntOrNull() ?: 0 }
            
            val maxParts = maxOf(currentParts.size, availableParts.size)
            
            for (i in 0 until maxParts) {
                val currentPart = currentParts.getOrElse(i) { 0 }
                val availablePart = availableParts.getOrElse(i) { 0 }
                
                when {
                    availablePart > currentPart -> return true
                    availablePart < currentPart -> return false
                }
            }
            
            false // Versions are equal
        } catch (e: Exception) {
            Log.e(TAG, "Failed to compare versions: $current vs $available", e)
            false
        }
    }
    
    /**
     * Check if current version is below minimum required
     */
    private fun isVersionBelowMinimum(current: String, minimum: String?): Boolean {
        if (minimum == null) return false
        return isNewerVersion(current, minimum)
    }
    
    /**
     * Check if update check should be skipped
     */
    private fun shouldSkipUpdateCheck(): Boolean {
        val timeSinceLastCheck = System.currentTimeMillis() - lastUpdateCheck
        val intervalMs = UPDATE_CHECK_INTERVAL_HOURS * 60 * 60 * 1000
        return timeSinceLastCheck < intervalMs
    }
    
    /**
     * Simulate download progress for demonstration
     */
    private suspend fun simulateDownloadProgress() {
        for (progress in 0..100 step 10) {
            kotlinx.coroutines.delay(500) // Simulate download time
            _updateProgress.value = UpdateProgress(
                phase = UpdatePhase.DOWNLOADING,
                progressPercent = progress,
                message = "Downloading update... $progress%"
            )
        }
    }
    
    /**
     * Simulate installation progress for demonstration
     */
    private suspend fun simulateInstallationProgress() {
        for (progress in 0..100 step 20) {
            kotlinx.coroutines.delay(300) // Simulate installation time
            _updateProgress.value = UpdateProgress(
                phase = UpdatePhase.INSTALLING,
                progressPercent = progress,
                message = "Installing update... $progress%"
            )
        }
    }
}

// Data classes for update management

@Serializable
data class UpdateInfo(
    val currentVersion: String,
    val availableVersion: String,
    val downloadUrl: String?,
    val releaseNotes: String?,
    val isForced: Boolean,
    val size: Long?,
    val releaseDate: String?
)

data class UpdateProgress(
    val phase: UpdatePhase = UpdatePhase.IDLE,
    val progressPercent: Int = 0,
    val message: String = ""
)

enum class UpdateStatus {
    UNKNOWN,
    CHECKING,
    UP_TO_DATE,
    AVAILABLE,
    FORCED_AVAILABLE,
    DOWNLOADING,
    READY_TO_INSTALL,
    INSTALLING,
    COMPLETED,
    ERROR
}

enum class UpdatePhase {
    IDLE,
    DOWNLOADING,
    READY,
    INSTALLING,
    COMPLETED,
    ERROR
}

enum class UpdateCheckResult {
    UPDATE_AVAILABLE,
    UP_TO_DATE,
    ERROR,
    SKIPPED
}

enum class UpdateDownloadResult {
    SUCCESS,
    FAILED,
    NO_UPDATE_AVAILABLE
}

enum class UpdateInstallResult {
    SUCCESS,
    FAILED,
    NO_UPDATE_READY,
    PERMISSION_DENIED
}