package com.displaydeck.androidtv.data.cache.dao

import androidx.room.*
import com.displaydeck.androidtv.data.cache.entities.MediaCache
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object for media cache operations.
 * Manages cached images, videos, and other media files for offline use.
 */
@Dao
interface MediaCacheDao {
    
    // Basic CRUD operations
    @Query("SELECT * FROM media_cache WHERE url = :url")
    suspend fun getMediaByUrl(url: String): MediaCache?
    
    @Query("SELECT * FROM media_cache WHERE url = :url")
    fun getMediaByUrlFlow(url: String): Flow<MediaCache?>
    
    @Query("SELECT * FROM media_cache WHERE local_path = :localPath")
    suspend fun getMediaByLocalPath(localPath: String): MediaCache?
    
    @Query("SELECT * FROM media_cache ORDER BY created_at DESC")
    suspend fun getAllMedia(): List<MediaCache>
    
    @Query("SELECT * FROM media_cache ORDER BY created_at DESC")
    fun getAllMediaFlow(): Flow<List<MediaCache>>
    
    @Query("SELECT * FROM media_cache WHERE media_type = :mediaType ORDER BY created_at DESC")
    suspend fun getMediaByType(mediaType: String): List<MediaCache>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMedia(media: MediaCache)
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMedia(mediaList: List<MediaCache>)
    
    @Update
    suspend fun updateMedia(media: MediaCache)
    
    @Delete
    suspend fun deleteMedia(media: MediaCache)
    
    @Query("DELETE FROM media_cache WHERE url = :url")
    suspend fun deleteMediaByUrl(url: String)
    
    @Query("DELETE FROM media_cache WHERE local_path = :localPath")
    suspend fun deleteMediaByLocalPath(localPath: String)
    
    @Query("DELETE FROM media_cache")
    suspend fun deleteAllMedia()
    
    // Cache status queries
    @Query("SELECT * FROM media_cache WHERE is_cached = 1 ORDER BY last_accessed DESC")
    suspend fun getCachedMedia(): List<MediaCache>
    
    @Query("SELECT * FROM media_cache WHERE is_cached = 0 ORDER BY created_at ASC")
    suspend fun getUncachedMedia(): List<MediaCache>
    
    @Query("SELECT * FROM media_cache WHERE is_cached = 1 AND media_type = :mediaType ORDER BY last_accessed DESC")
    suspend fun getCachedMediaByType(mediaType: String): List<MediaCache>
    
    @Query("SELECT * FROM media_cache WHERE expires_at < :currentTime")
    suspend fun getExpiredMedia(currentTime: Long): List<MediaCache>
    
    @Query("SELECT * FROM media_cache WHERE last_accessed < :cutoffTime ORDER BY last_accessed ASC")
    suspend fun getStaleMedia(cutoffTime: Long): List<MediaCache>
    
    // Cache management operations
    @Query("UPDATE media_cache SET is_cached = :isCached, local_path = :localPath WHERE url = :url")
    suspend fun updateCacheStatus(url: String, isCached: Boolean, localPath: String?)
    
    @Query("UPDATE media_cache SET last_accessed = :accessTime WHERE url = :url")
    suspend fun updateLastAccessed(url: String, accessTime: Long)
    
    @Query("UPDATE media_cache SET file_size = :fileSize WHERE url = :url")
    suspend fun updateFileSize(url: String, fileSize: Long)
    
    @Query("UPDATE media_cache SET expires_at = :expiresAt WHERE url = :url")
    suspend fun updateExpirationTime(url: String, expiresAt: Long?)
    
    // Size and storage management
    @Query("SELECT SUM(file_size) FROM media_cache WHERE is_cached = 1")
    suspend fun getTotalCacheSize(): Long?
    
    @Query("SELECT SUM(file_size) FROM media_cache WHERE is_cached = 1 AND media_type = :mediaType")
    suspend fun getCacheSizeByType(mediaType: String): Long?
    
    @Query("SELECT COUNT(*) FROM media_cache WHERE is_cached = 1")
    suspend fun getCachedMediaCount(): Int
    
    @Query("SELECT COUNT(*) FROM media_cache WHERE media_type = :mediaType AND is_cached = 1")
    suspend fun getCachedMediaCountByType(mediaType: String): Int
    
    // Cleanup operations
    @Query("DELETE FROM media_cache WHERE expires_at < :currentTime")
    suspend fun deleteExpiredMedia(currentTime: Long): Int
    
    @Query("DELETE FROM media_cache WHERE last_accessed < :cutoffTime")
    suspend fun deleteStaleMedia(cutoffTime: Long): Int
    
    @Query("DELETE FROM media_cache WHERE is_cached = 0 AND created_at < :cutoffTime")
    suspend fun deleteUncachedOldEntries(cutoffTime: Long): Int
    
    // Least Recently Used (LRU) cleanup
    @Query("""
        DELETE FROM media_cache 
        WHERE url IN (
            SELECT url FROM media_cache 
            WHERE is_cached = 1 
            ORDER BY last_accessed ASC 
            LIMIT :count
        )
    """)
    suspend fun deleteLeastRecentlyUsed(count: Int): Int
    
    @Query("""
        SELECT * FROM media_cache 
        WHERE is_cached = 1 
        ORDER BY last_accessed ASC 
        LIMIT :count
    """)
    suspend fun getLeastRecentlyUsed(count: Int): List<MediaCache>
    
    // Search and filtering
    @Query("SELECT * FROM media_cache WHERE url LIKE '%' || :query || '%'")
    suspend fun searchMediaByUrl(query: String): List<MediaCache>
    
    @Query("SELECT * FROM media_cache WHERE local_path LIKE '%' || :query || '%'")
    suspend fun searchMediaByPath(query: String): List<MediaCache>
    
    @Query("""
        SELECT * FROM media_cache 
        WHERE media_type = :mediaType 
        AND file_size BETWEEN :minSize AND :maxSize 
        ORDER BY created_at DESC
    """)
    suspend fun getMediaByTypeAndSizeRange(mediaType: String, minSize: Long, maxSize: Long): List<MediaCache>
    
    // Statistics and monitoring
    @Query("SELECT media_type, COUNT(*) as count FROM media_cache WHERE is_cached = 1 GROUP BY media_type")
    suspend fun getCacheStatsByType(): List<MediaTypeCount>
    
    @Query("SELECT AVG(file_size) FROM media_cache WHERE media_type = :mediaType AND is_cached = 1")
    suspend fun getAverageFileSizeByType(mediaType: String): Float?
    
    @Query("SELECT MAX(last_accessed) FROM media_cache WHERE is_cached = 1")
    suspend fun getLatestAccessTime(): Long?
    
    @Query("SELECT MIN(created_at) FROM media_cache WHERE is_cached = 1")
    suspend fun getOldestCacheEntry(): Long?
    
    // Batch operations for sync
    @Transaction
    suspend fun cacheMedia(url: String, localPath: String, fileSize: Long, mediaType: String) {
        val currentTime = System.currentTimeMillis()
        val existingMedia = getMediaByUrl(url)
        
        if (existingMedia != null) {
            updateCacheStatus(url, true, localPath)
            updateFileSize(url, fileSize)
            updateLastAccessed(url, currentTime)
        } else {
            val newMedia = MediaCache(
                url = url,
                localPath = localPath,
                mediaType = mediaType,
                fileSize = fileSize,
                isCached = true,
                createdAt = currentTime,
                lastAccessed = currentTime
            )
            insertMedia(newMedia)
        }
    }
    
    @Transaction
    suspend fun uncacheMedia(url: String) {
        updateCacheStatus(url, false, null)
    }
    
    @Transaction
    suspend fun cleanupCache(maxSizeBytes: Long, maxAgeMillis: Long) {
        val currentTime = System.currentTimeMillis()
        val cutoffTime = currentTime - maxAgeMillis
        
        // Delete expired media
        deleteExpiredMedia(currentTime)
        
        // Delete stale media
        deleteStaleMedia(cutoffTime)
        
        // Check if we're still over the size limit
        val currentSize = getTotalCacheSize() ?: 0
        if (currentSize > maxSizeBytes) {
            val bytesToDelete = currentSize - maxSizeBytes
            // Calculate approximately how many items to delete based on average file size
            val avgSize = currentSize / getCachedMediaCount().coerceAtLeast(1)
            val itemsToDelete = (bytesToDelete / avgSize).toInt() + 1
            deleteLeastRecentlyUsed(itemsToDelete)
        }
    }
}

/**
 * Data class for media type statistics.
 */
data class MediaTypeCount(
    val mediaType: String,
    val count: Int
)