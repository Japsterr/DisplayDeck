package com.displaydeck.androidtv.utils

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Secure preferences manager for DisplayDeck Android TV app.
 * Handles encrypted storage of sensitive data like tokens and settings.
 */
@Singleton
class PreferencesManager @Inject constructor(
    private val context: Context
) {
    
    companion object {
        private const val PREFS_NAME = "displaydeck_preferences"
        private const val ENCRYPTED_PREFS_NAME = "displaydeck_secure_preferences"
        
        // Authentication keys
        private const val KEY_DISPLAY_ID = "display_id"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_IS_PAIRED = "is_paired"
        private const val KEY_BUSINESS_ID = "business_id"
        
        // Server configuration
        private const val KEY_SERVER_URL = "server_url"
        private const val KEY_API_VERSION = "api_version"
        private const val KEY_WEBSOCKET_URL = "websocket_url"
        
        // Display settings
        private const val KEY_DEVICE_NAME = "device_name"
        private const val KEY_LOCATION = "location"
        private const val KEY_BRIGHTNESS = "brightness"
        private const val KEY_VOLUME = "volume"
        private const val KEY_ORIENTATION = "orientation"
        private const val KEY_THEME = "theme"
        private const val KEY_ANIMATION_ENABLED = "animation_enabled"
        
        // Update settings
        private const val KEY_AUTO_UPDATE_ENABLED = "auto_update_enabled"
        private const val KEY_AUTO_INSTALL_ENABLED = "auto_install_enabled"
        private const val KEY_UPDATE_CHANNEL = "update_channel" // stable, beta, dev
        
        // Available update info
        private const val KEY_AVAILABLE_UPDATE_VERSION_CODE = "available_update_version_code"
        private const val KEY_AVAILABLE_UPDATE_VERSION_NAME = "available_update_version_name"
        private const val KEY_AVAILABLE_UPDATE_DOWNLOAD_URL = "available_update_download_url"
        private const val KEY_AVAILABLE_UPDATE_RELEASE_NOTES = "available_update_release_notes"
        
        // Network and sync settings
        private const val KEY_LAST_CONNECTED_TIME = "last_connected_time"
        private const val KEY_NETWORK_RETRY_COUNT = "network_retry_count"
        private const val KEY_LAST_SYNC_TIME = "last_sync_time"
        private const val KEY_SYNC_FREQUENCY = "sync_frequency"
        
        // App state
        private const val KEY_FIRST_RUN = "first_run"
        private const val KEY_ONBOARDING_COMPLETED = "onboarding_completed"
        private const val KEY_LAST_APP_VERSION = "last_app_version"
        
        // Default values
        private const val DEFAULT_BRIGHTNESS = 100
        private const val DEFAULT_VOLUME = 50
        private const val DEFAULT_ORIENTATION = "landscape"
        private const val DEFAULT_THEME = "default"
        private const val DEFAULT_SYNC_FREQUENCY = 15 * 60 * 1000L // 15 minutes
    }
    
    // Regular SharedPreferences for non-sensitive data
    private val regularPrefs: SharedPreferences by lazy {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }
    
    // Encrypted SharedPreferences for sensitive data
    private val encryptedPrefs: SharedPreferences by lazy {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        
        EncryptedSharedPreferences.create(
            context,
            ENCRYPTED_PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }
    
    // Authentication methods
    fun getDisplayId(): String? = encryptedPrefs.getString(KEY_DISPLAY_ID, null)
    fun setDisplayId(displayId: String) = encryptedPrefs.edit().putString(KEY_DISPLAY_ID, displayId).apply()
    
    fun getAccessToken(): String? = encryptedPrefs.getString(KEY_ACCESS_TOKEN, null)
    fun getRefreshToken(): String? = encryptedPrefs.getString(KEY_REFRESH_TOKEN, null)
    
    fun setTokens(accessToken: String, refreshToken: String) {
        encryptedPrefs.edit()
            .putString(KEY_ACCESS_TOKEN, accessToken)
            .putString(KEY_REFRESH_TOKEN, refreshToken)
            .apply()
    }
    
    fun clearTokens() {
        encryptedPrefs.edit()
            .remove(KEY_ACCESS_TOKEN)
            .remove(KEY_REFRESH_TOKEN)
            .apply()
    }
    
    fun isPaired(): Boolean = encryptedPrefs.getBoolean(KEY_IS_PAIRED, false)
    fun setPaired(paired: Boolean) = encryptedPrefs.edit().putBoolean(KEY_IS_PAIRED, paired).apply()
    
    fun getBusinessId(): Long? {
        val businessId = encryptedPrefs.getLong(KEY_BUSINESS_ID, -1L)
        return if (businessId == -1L) null else businessId
    }
    fun setBusinessId(businessId: Long?) {
        if (businessId != null) {
            encryptedPrefs.edit().putLong(KEY_BUSINESS_ID, businessId).apply()
        } else {
            encryptedPrefs.edit().remove(KEY_BUSINESS_ID).apply()
        }
    }
    
    // Server configuration
    fun getServerUrl(): String? = regularPrefs.getString(KEY_SERVER_URL, null)
    fun setServerUrl(serverUrl: String) = regularPrefs.edit().putString(KEY_SERVER_URL, serverUrl).apply()
    
    fun getApiVersion(): String = regularPrefs.getString(KEY_API_VERSION, "v1") ?: "v1"
    fun setApiVersion(version: String) = regularPrefs.edit().putString(KEY_API_VERSION, version).apply()
    
    fun getWebSocketUrl(): String? = regularPrefs.getString(KEY_WEBSOCKET_URL, null)
    fun setWebSocketUrl(wsUrl: String) = regularPrefs.edit().putString(KEY_WEBSOCKET_URL, wsUrl).apply()
    
    // Display settings
    fun getDeviceName(): String? = regularPrefs.getString(KEY_DEVICE_NAME, null)
    fun setDeviceName(deviceName: String) = regularPrefs.edit().putString(KEY_DEVICE_NAME, deviceName).apply()
    
    fun getLocation(): String? = regularPrefs.getString(KEY_LOCATION, null)
    fun setLocation(location: String?) = regularPrefs.edit().putString(KEY_LOCATION, location).apply()
    
    fun getBrightness(): Int = regularPrefs.getInt(KEY_BRIGHTNESS, DEFAULT_BRIGHTNESS)
    fun setBrightness(brightness: Int) = regularPrefs.edit().putInt(KEY_BRIGHTNESS, brightness).apply()
    
    fun getVolume(): Int = regularPrefs.getInt(KEY_VOLUME, DEFAULT_VOLUME)
    fun setVolume(volume: Int) = regularPrefs.edit().putInt(KEY_VOLUME, volume).apply()
    
    fun getOrientation(): String = regularPrefs.getString(KEY_ORIENTATION, DEFAULT_ORIENTATION) ?: DEFAULT_ORIENTATION
    fun setOrientation(orientation: String) = regularPrefs.edit().putString(KEY_ORIENTATION, orientation).apply()
    
    fun getTheme(): String = regularPrefs.getString(KEY_THEME, DEFAULT_THEME) ?: DEFAULT_THEME
    fun setTheme(theme: String) = regularPrefs.edit().putString(KEY_THEME, theme).apply()
    
    fun isAnimationEnabled(): Boolean = regularPrefs.getBoolean(KEY_ANIMATION_ENABLED, true)
    fun setAnimationEnabled(enabled: Boolean) = regularPrefs.edit().putBoolean(KEY_ANIMATION_ENABLED, enabled).apply()
    
    // Update settings
    fun isAutoUpdateEnabled(): Boolean = regularPrefs.getBoolean(KEY_AUTO_UPDATE_ENABLED, true)
    fun setAutoUpdateEnabled(enabled: Boolean) = regularPrefs.edit().putBoolean(KEY_AUTO_UPDATE_ENABLED, enabled).apply()
    
    fun isAutoInstallEnabled(): Boolean = regularPrefs.getBoolean(KEY_AUTO_INSTALL_ENABLED, false)
    fun setAutoInstallEnabled(enabled: Boolean) = regularPrefs.edit().putBoolean(KEY_AUTO_INSTALL_ENABLED, enabled).apply()
    
    fun getUpdateChannel(): String = regularPrefs.getString(KEY_UPDATE_CHANNEL, "stable") ?: "stable"
    fun setUpdateChannel(channel: String) = regularPrefs.edit().putString(KEY_UPDATE_CHANNEL, channel).apply()
    
    // Available update info
    fun getAvailableUpdateVersionCode(): Int = regularPrefs.getInt(KEY_AVAILABLE_UPDATE_VERSION_CODE, -1)
    fun getAvailableUpdateVersionName(): String? = regularPrefs.getString(KEY_AVAILABLE_UPDATE_VERSION_NAME, null)
    fun getAvailableUpdateDownloadUrl(): String? = regularPrefs.getString(KEY_AVAILABLE_UPDATE_DOWNLOAD_URL, null)
    fun getAvailableUpdateReleaseNotes(): String? = regularPrefs.getString(KEY_AVAILABLE_UPDATE_RELEASE_NOTES, null)
    
    fun setAvailableUpdateInfo(versionCode: Int, versionName: String, downloadUrl: String, releaseNotes: String) {
        regularPrefs.edit()
            .putInt(KEY_AVAILABLE_UPDATE_VERSION_CODE, versionCode)
            .putString(KEY_AVAILABLE_UPDATE_VERSION_NAME, versionName)
            .putString(KEY_AVAILABLE_UPDATE_DOWNLOAD_URL, downloadUrl)
            .putString(KEY_AVAILABLE_UPDATE_RELEASE_NOTES, releaseNotes)
            .apply()
    }
    
    fun clearAvailableUpdateInfo() {
        regularPrefs.edit()
            .remove(KEY_AVAILABLE_UPDATE_VERSION_CODE)
            .remove(KEY_AVAILABLE_UPDATE_VERSION_NAME)
            .remove(KEY_AVAILABLE_UPDATE_DOWNLOAD_URL)
            .remove(KEY_AVAILABLE_UPDATE_RELEASE_NOTES)
            .apply()
    }
    
    // Network and sync settings
    fun getLastConnectedTime(): Long? {
        val time = regularPrefs.getLong(KEY_LAST_CONNECTED_TIME, -1L)
        return if (time == -1L) null else time
    }
    fun setLastConnectedTime(time: Long) = regularPrefs.edit().putLong(KEY_LAST_CONNECTED_TIME, time).apply()
    
    fun getNetworkRetryCount(): Int = regularPrefs.getInt(KEY_NETWORK_RETRY_COUNT, 0)
    fun setNetworkRetryCount(count: Int) = regularPrefs.edit().putInt(KEY_NETWORK_RETRY_COUNT, count).apply()
    
    fun getLastSyncTime(): Long? {
        val time = regularPrefs.getLong(KEY_LAST_SYNC_TIME, -1L)
        return if (time == -1L) null else time
    }
    fun setLastSyncTime(time: Long) = regularPrefs.edit().putLong(KEY_LAST_SYNC_TIME, time).apply()
    
    fun getSyncFrequency(): Long = regularPrefs.getLong(KEY_SYNC_FREQUENCY, DEFAULT_SYNC_FREQUENCY)
    fun setSyncFrequency(frequency: Long) = regularPrefs.edit().putLong(KEY_SYNC_FREQUENCY, frequency).apply()
    
    // App state
    fun isFirstRun(): Boolean = regularPrefs.getBoolean(KEY_FIRST_RUN, true)
    fun setFirstRun(isFirstRun: Boolean) = regularPrefs.edit().putBoolean(KEY_FIRST_RUN, isFirstRun).apply()
    
    fun isOnboardingCompleted(): Boolean = regularPrefs.getBoolean(KEY_ONBOARDING_COMPLETED, false)
    fun setOnboardingCompleted(completed: Boolean) = regularPrefs.edit().putBoolean(KEY_ONBOARDING_COMPLETED, completed).apply()
    
    fun getLastAppVersion(): Int = regularPrefs.getInt(KEY_LAST_APP_VERSION, 0)
    fun setLastAppVersion(version: Int) = regularPrefs.edit().putInt(KEY_LAST_APP_VERSION, version).apply()
    
    // Utility methods
    fun clearAllData() {
        regularPrefs.edit().clear().apply()
        encryptedPrefs.edit().clear().apply()
    }
    
    fun clearUserData() {
        // Clear user-specific data but keep device settings
        encryptedPrefs.edit()
            .remove(KEY_DISPLAY_ID)
            .remove(KEY_ACCESS_TOKEN)
            .remove(KEY_REFRESH_TOKEN)
            .remove(KEY_IS_PAIRED)
            .remove(KEY_BUSINESS_ID)
            .apply()
        
        regularPrefs.edit()
            .remove(KEY_LAST_CONNECTED_TIME)
            .remove(KEY_LAST_SYNC_TIME)
            .putBoolean(KEY_ONBOARDING_COMPLETED, false)
            .apply()
    }
    
    /**
     * Export non-sensitive settings for backup/restore.
     */
    fun exportSettings(): Map<String, Any> {
        val settings = mutableMapOf<String, Any>()
        
        // Export non-sensitive settings only
        regularPrefs.all.forEach { (key, value) ->
            when (key) {
                // Skip sensitive or device-specific data
                KEY_LAST_CONNECTED_TIME, KEY_NETWORK_RETRY_COUNT, KEY_LAST_SYNC_TIME -> {
                    // Skip these
                }
                else -> {
                    value?.let { settings[key] = it }
                }
            }
        }
        
        return settings
    }
    
    /**
     * Import settings from backup.
     */
    fun importSettings(settings: Map<String, Any>) {
        val editor = regularPrefs.edit()
        
        settings.forEach { (key, value) ->
            when (value) {
                is String -> editor.putString(key, value)
                is Int -> editor.putInt(key, value)
                is Long -> editor.putLong(key, value)
                is Float -> editor.putFloat(key, value)
                is Boolean -> editor.putBoolean(key, value)
            }
        }
        
        editor.apply()
    }
}