package com.displaydeck.androidtv.data.cache.dao

import androidx.room.*
import com.displaydeck.androidtv.data.cache.entities.SyncStatus
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object for sync status operations.
 * Manages synchronization status and tracking across different data types.
 */
@Dao
interface SyncStatusDao {
    
    // Basic CRUD operations
    @Query("SELECT * FROM sync_status WHERE entity_type = :entityType AND entity_id = :entityId")
    suspend fun getSyncStatus(entityType: String, entityId: String): SyncStatus?
    
    @Query("SELECT * FROM sync_status WHERE entity_type = :entityType AND entity_id = :entityId")
    fun getSyncStatusFlow(entityType: String, entityId: String): Flow<SyncStatus?>
    
    @Query("SELECT * FROM sync_status WHERE entity_type = :entityType ORDER BY last_sync_attempt DESC")
    suspend fun getSyncStatusByType(entityType: String): List<SyncStatus>
    
    @Query("SELECT * FROM sync_status ORDER BY last_sync_attempt DESC")
    suspend fun getAllSyncStatus(): List<SyncStatus>
    
    @Query("SELECT * FROM sync_status ORDER BY last_sync_attempt DESC")
    fun getAllSyncStatusFlow(): Flow<List<SyncStatus>>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSyncStatus(syncStatus: SyncStatus)
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSyncStatus(syncStatusList: List<SyncStatus>)
    
    @Update
    suspend fun updateSyncStatus(syncStatus: SyncStatus)
    
    @Delete
    suspend fun deleteSyncStatus(syncStatus: SyncStatus)
    
    @Query("DELETE FROM sync_status WHERE entity_type = :entityType AND entity_id = :entityId")
    suspend fun deleteSyncStatus(entityType: String, entityId: String)
    
    @Query("DELETE FROM sync_status WHERE entity_type = :entityType")
    suspend fun deleteSyncStatusByType(entityType: String)
    
    @Query("DELETE FROM sync_status")
    suspend fun deleteAllSyncStatus()
    
    // Sync status queries
    @Query("SELECT * FROM sync_status WHERE is_synced = 0 ORDER BY last_sync_attempt ASC")
    suspend fun getUnsyncedEntities(): List<SyncStatus>
    
    @Query("SELECT * FROM sync_status WHERE is_synced = 1 ORDER BY last_successful_sync DESC")
    suspend fun getSyncedEntities(): List<SyncStatus>
    
    @Query("SELECT * FROM sync_status WHERE sync_error IS NOT NULL AND sync_error != '' ORDER BY last_sync_attempt DESC")
    suspend fun getEntitiesWithSyncErrors(): List<SyncStatus>
    
    @Query("SELECT * FROM sync_status WHERE last_sync_attempt < :cutoffTime OR last_sync_attempt IS NULL ORDER BY last_sync_attempt ASC")
    suspend fun getEntitiesNeedingSync(cutoffTime: Long): List<SyncStatus>
    
    @Query("SELECT * FROM sync_status WHERE entity_type = :entityType AND is_synced = 0")
    suspend fun getUnsyncedEntitiesByType(entityType: String): List<SyncStatus>
    
    @Query("SELECT * FROM sync_status WHERE entity_type = :entityType AND sync_error IS NOT NULL AND sync_error != ''")
    suspend fun getEntitiesWithSyncErrorsByType(entityType: String): List<SyncStatus>
    
    // Sync status updates
    @Query("UPDATE sync_status SET is_synced = :isSynced, last_successful_sync = :timestamp WHERE entity_type = :entityType AND entity_id = :entityId")
    suspend fun updateSyncSuccess(entityType: String, entityId: String, isSynced: Boolean, timestamp: Long)
    
    @Query("UPDATE sync_status SET is_synced = 0, sync_error = :error, last_sync_attempt = :timestamp WHERE entity_type = :entityType AND entity_id = :entityId")
    suspend fun updateSyncError(entityType: String, entityId: String, error: String, timestamp: Long)
    
    @Query("UPDATE sync_status SET sync_error = NULL, last_sync_attempt = :timestamp WHERE entity_type = :entityType AND entity_id = :entityId")
    suspend fun clearSyncError(entityType: String, entityId: String, timestamp: Long)
    
    @Query("UPDATE sync_status SET retry_count = retry_count + 1, last_sync_attempt = :timestamp WHERE entity_type = :entityType AND entity_id = :entityId")
    suspend fun incrementRetryCount(entityType: String, entityId: String, timestamp: Long)
    
    @Query("UPDATE sync_status SET retry_count = 0 WHERE entity_type = :entityType AND entity_id = :entityId")
    suspend fun resetRetryCount(entityType: String, entityId: String)
    
    // Batch sync operations
    @Query("UPDATE sync_status SET is_synced = 1, last_successful_sync = :timestamp WHERE entity_type = :entityType")
    suspend fun markAllSyncedByType(entityType: String, timestamp: Long)
    
    @Query("UPDATE sync_status SET is_synced = 0 WHERE entity_type = :entityType")
    suspend fun markAllUnsyncedByType(entityType: String)
    
    // Statistics and monitoring
    @Query("SELECT COUNT(*) FROM sync_status WHERE entity_type = :entityType")
    suspend fun getSyncStatusCount(entityType: String): Int
    
    @Query("SELECT COUNT(*) FROM sync_status WHERE entity_type = :entityType AND is_synced = 1")
    suspend fun getSyncedCount(entityType: String): Int
    
    @Query("SELECT COUNT(*) FROM sync_status WHERE entity_type = :entityType AND is_synced = 0")
    suspend fun getUnsyncedCount(entityType: String): Int
    
    @Query("SELECT COUNT(*) FROM sync_status WHERE entity_type = :entityType AND sync_error IS NOT NULL AND sync_error != ''")
    suspend fun getErrorCount(entityType: String): Int
    
    @Query("SELECT MAX(last_successful_sync) FROM sync_status WHERE entity_type = :entityType")
    suspend fun getLatestSyncTime(entityType: String): Long?
    
    @Query("SELECT AVG(retry_count) FROM sync_status WHERE entity_type = :entityType")
    suspend fun getAverageRetryCount(entityType: String): Float
    
    // Cleanup operations
    @Query("DELETE FROM sync_status WHERE last_sync_attempt < :cutoffTime")
    suspend fun deleteOldSyncStatus(cutoffTime: Long): Int
    
    @Query("DELETE FROM sync_status WHERE retry_count > :maxRetries")
    suspend fun deleteFailedSyncStatus(maxRetries: Int): Int
    
    // Utility methods for common sync patterns
    @Transaction
    suspend fun recordSyncAttempt(
        entityType: String,
        entityId: String,
        success: Boolean,
        error: String? = null
    ) {
        val timestamp = System.currentTimeMillis()
        val existingStatus = getSyncStatus(entityType, entityId)
        
        if (existingStatus != null) {
            if (success) {
                updateSyncSuccess(entityType, entityId, true, timestamp)
                resetRetryCount(entityType, entityId)
            } else {
                updateSyncError(entityType, entityId, error ?: "Unknown error", timestamp)
                incrementRetryCount(entityType, entityId, timestamp)
            }
        } else {
            val newStatus = SyncStatus(
                entityType = entityType,
                entityId = entityId,
                isSynced = success,
                lastSyncAttempt = timestamp,
                lastSuccessfulSync = if (success) timestamp else null,
                syncError = if (!success) error else null,
                retryCount = if (!success) 1 else 0
            )
            insertSyncStatus(newStatus)
        }
    }
    
    @Transaction
    suspend fun batchUpdateSyncStatus(updates: List<Triple<String, String, Boolean>>) {
        updates.forEach { (entityType, entityId, success) ->
            recordSyncAttempt(entityType, entityId, success)
        }
    }
}