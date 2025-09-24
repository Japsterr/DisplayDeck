package com.displaydeck.androidtv.data.repository

import com.displaydeck.androidtv.data.cache.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository for managing display settings
 */
@Singleton
class DisplaySettingsRepository @Inject constructor(
    private val displaySettingsDao: DisplaySettingsDao
) {
    
    /**
     * Get current display settings
     */
    suspend fun getDisplaySettings(): DisplaySettings? {
        return displaySettingsDao.getDisplaySettings()
    }
    
    /**
     * Get display settings as Flow for reactive UI
     */
    fun getDisplaySettingsFlow(): Flow<DisplaySettings?> {
        return displaySettingsDao.getDisplaySettingsFlow().distinctUntilChanged()
    }
    
    /**
     * Save display settings
     */
    suspend fun saveDisplaySettings(settings: DisplaySettings) {
        displaySettingsDao.insertDisplaySettings(settings)
    }
    
    /**
     * Update display settings
     */
    suspend fun updateDisplaySettings(settings: DisplaySettings) {
        displaySettingsDao.updateDisplaySettings(settings)
    }
    
    /**
     * Update pairing status
     */
    suspend fun updatePairingStatus(isPaired: Boolean) {
        displaySettingsDao.updatePairingStatus(isPaired)
    }
    
    /**
     * Update assigned menu
     */
    suspend fun updateAssignedMenu(menuId: Int?) {
        displaySettingsDao.updateAssignedMenu(menuId)
    }
    
    /**
     * Update last sync timestamp
     */
    suspend fun updateLastSync(timestamp: Long = System.currentTimeMillis()) {
        displaySettingsDao.updateLastSync(timestamp)
    }
    
    /**
     * Clear all display settings (used for reset/unpair)
     */
    suspend fun clearDisplaySettings() {
        displaySettingsDao.clearDisplaySettings()
    }
    
    /**
     * Check if display is paired
     */
    suspend fun isPaired(): Boolean {
        return getDisplaySettings()?.isPaired == true
    }
    
    /**
     * Get assigned menu ID
     */
    suspend fun getAssignedMenuId(): Int? {
        return getDisplaySettings()?.assignedMenuId
    }
    
    /**
     * Get display name
     */
    suspend fun getDisplayName(): String {
        return getDisplaySettings()?.displayName ?: "Android TV Display"
    }
    
    /**
     * Initialize default display settings
     */
    suspend fun initializeDefaultSettings() {
        val existing = getDisplaySettings()
        if (existing == null) {
            val defaultSettings = DisplaySettings(
                id = 1,
                displayName = "Android TV Display",
                isPaired = false,
                assignedMenuId = null,
                lastSync = 0L
            )
            saveDisplaySettings(defaultSettings)
        }
    }
}

/**
 * Repository for managing media cache
 */
@Singleton
class MediaCacheRepository @Inject constructor(
    private val mediaCacheDao: MediaCacheDao
) {
    
    /**
     * Get cached media by URL
     */
    suspend fun getCachedMedia(url: String): MediaCache? {
        return mediaCacheDao.getMediaCache(url)
    }
    
    /**
     * Get all cached media
     */
    suspend fun getAllCachedMedia(): List<MediaCache> {
        return mediaCacheDao.getAllCachedMedia()
    }
    
    /**
     * Get total cache size in bytes
     */
    suspend fun getTotalCacheSize(): Long {
        return mediaCacheDao.getTotalCacheSize() ?: 0L
    }
    
    /**
     * Cache media file
     */
    suspend fun cacheMedia(url: String, localPath: String, fileSize: Long, mimeType: String? = null) {
        val mediaCache = MediaCache(
            url = url,
            localPath = localPath,
            fileSize = fileSize,
            mimeType = mimeType,
            downloadedAt = System.currentTimeMillis(),
            lastAccessed = System.currentTimeMillis()
        )
        mediaCacheDao.insertMediaCache(mediaCache)
    }
    
    /**
     * Update last accessed time for media
     */
    suspend fun updateLastAccessed(url: String, timestamp: Long = System.currentTimeMillis()) {
        mediaCacheDao.updateLastAccessed(url, timestamp)
    }
    
    /**
     * Delete cached media
     */
    suspend fun deleteCachedMedia(url: String) {
        val media = getCachedMedia(url)
        media?.let { 
            // Delete physical file
            val file = File(it.localPath)
            if (file.exists()) {
                file.delete()
            }
        }
        mediaCacheDao.deleteMediaCache(url)
    }
    
    /**
     * Clean up expired media cache
     */
    suspend fun cleanupExpiredMedia() {
        val expireTime = DatabaseUtils.getMediaExpirationTime()
        val expiredMedia = mediaCacheDao.getAllCachedMedia().filter { 
            it.downloadedAt < expireTime 
        }
        
        // Delete physical files
        expiredMedia.forEach { media ->
            val file = File(media.localPath)
            if (file.exists()) {
                file.delete()
            }
        }
        
        mediaCacheDao.deleteExpiredMedia(expireTime)
    }
    
    /**
     * Clean up least recently used media to free space
     */
    suspend fun cleanupLRUMedia(targetSizeBytes: Long) {
        val currentSize = getTotalCacheSize()
        if (currentSize <= targetSizeBytes) return
        
        var sizeToFree = currentSize - targetSizeBytes
        val lruMedia = mediaCacheDao.getAllCachedMedia().sortedBy { it.lastAccessed }
        
        for (media in lruMedia) {
            if (sizeToFree <= 0) break
            
            // Delete physical file
            val file = File(media.localPath)
            if (file.exists()) {
                file.delete()
            }
            
            mediaCacheDao.deleteMediaCache(media.url)
            sizeToFree -= media.fileSize
        }
    }
    
    /**
     * Check if cache size is over threshold and cleanup if needed
     */
    suspend fun performCacheMaintenanceIfNeeded() {
        val currentSize = getTotalCacheSize()
        
        if (DatabaseUtils.isCacheOverThreshold(currentSize)) {
            // First try cleaning expired media
            cleanupExpiredMedia()
            
            val newSize = getTotalCacheSize()
            
            // If still over threshold, clean up LRU media
            if (DatabaseUtils.isCacheOverThreshold(newSize)) {
                val targetSize = DatabaseUtils.mbToBytes(DatabaseUtils.MEDIA_CLEANUP_THRESHOLD_MB)
                cleanupLRUMedia(targetSize)
            }
        }
    }
    
    /**
     * Check if media is cached locally
     */
    suspend fun isMediaCached(url: String): Boolean {
        val cached = getCachedMedia(url)
        if (cached == null) return false
        
        // Check if physical file exists
        val file = File(cached.localPath)
        if (!file.exists()) {
            // Remove stale cache entry
            mediaCacheDao.deleteMediaCache(url)
            return false
        }
        
        return true
    }
    
    /**
     * Get local path for cached media
     */
    suspend fun getLocalPath(url: String): String? {
        val cached = getCachedMedia(url)
        if (cached == null) return null
        
        val file = File(cached.localPath)
        if (!file.exists()) {
            // Remove stale cache entry
            mediaCacheDao.deleteMediaCache(url)
            return null
        }
        
        // Update last accessed
        updateLastAccessed(url)
        return cached.localPath
    }
}