package com.displaydeck.androidtv.data.cache

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface MenuCacheDao {
    
    @Query("SELECT * FROM cached_menus WHERE id = :menuId")
    suspend fun getMenu(menuId: Int): CachedMenu?
    
    @Query("SELECT * FROM cached_menus WHERE businessId = :businessId AND isActive = 1")
    suspend fun getActiveMenusForBusiness(businessId: Int): List<CachedMenu>
    
    @Query("SELECT * FROM cached_menus WHERE businessId = :businessId AND isActive = 1")
    fun getActiveMenusForBusinessFlow(businessId: Int): Flow<List<CachedMenu>>
    
    @Query("SELECT * FROM cached_menus ORDER BY lastUpdated DESC")
    suspend fun getAllMenus(): List<CachedMenu>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMenu(menu: CachedMenu)
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMenus(menus: List<CachedMenu>)
    
    @Update
    suspend fun updateMenu(menu: CachedMenu)
    
    @Delete
    suspend fun deleteMenu(menu: CachedMenu)
    
    @Query("DELETE FROM cached_menus WHERE id = :menuId")
    suspend fun deleteMenuById(menuId: Int)
    
    @Query("DELETE FROM cached_menus WHERE businessId = :businessId")
    suspend fun deleteMenusByBusiness(businessId: Int)
    
    @Query("DELETE FROM cached_menus WHERE cachedAt < :expireTime")
    suspend fun deleteExpiredMenus(expireTime: Long)
    
    @Query("SELECT COUNT(*) FROM cached_menus WHERE businessId = :businessId")
    suspend fun getMenuCountForBusiness(businessId: Int): Int
}

@Dao
interface BusinessCacheDao {
    
    @Query("SELECT * FROM cached_businesses WHERE id = :businessId")
    suspend fun getBusiness(businessId: Int): CachedBusiness?
    
    @Query("SELECT * FROM cached_businesses ORDER BY name ASC")
    suspend fun getAllBusinesses(): List<CachedBusiness>
    
    @Query("SELECT * FROM cached_businesses ORDER BY name ASC")
    fun getAllBusinessesFlow(): Flow<List<CachedBusiness>>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertBusiness(business: CachedBusiness)
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertBusinesses(businesses: List<CachedBusiness>)
    
    @Update
    suspend fun updateBusiness(business: CachedBusiness)
    
    @Delete
    suspend fun deleteBusiness(business: CachedBusiness)
    
    @Query("DELETE FROM cached_businesses WHERE id = :businessId")
    suspend fun deleteBusinessById(businessId: Int)
    
    @Query("DELETE FROM cached_businesses WHERE cachedAt < :expireTime")
    suspend fun deleteExpiredBusinesses(expireTime: Long)
}

@Dao
interface DisplaySettingsDao {
    
    @Query("SELECT * FROM display_settings WHERE id = 1")
    suspend fun getDisplaySettings(): DisplaySettings?
    
    @Query("SELECT * FROM display_settings WHERE id = 1")
    fun getDisplaySettingsFlow(): Flow<DisplaySettings?>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDisplaySettings(settings: DisplaySettings)
    
    @Update
    suspend fun updateDisplaySettings(settings: DisplaySettings)
    
    @Query("UPDATE display_settings SET isPaired = :isPaired WHERE id = 1")
    suspend fun updatePairingStatus(isPaired: Boolean)
    
    @Query("UPDATE display_settings SET assignedMenuId = :menuId WHERE id = 1")
    suspend fun updateAssignedMenu(menuId: Int?)
    
    @Query("UPDATE display_settings SET lastSync = :timestamp WHERE id = 1")
    suspend fun updateLastSync(timestamp: Long)
    
    @Query("DELETE FROM display_settings")
    suspend fun clearDisplaySettings()
}

@Dao
interface SyncStatusDao {
    
    @Query("SELECT * FROM sync_status WHERE entityType = :type AND entityId = :id")
    suspend fun getSyncStatus(type: String, id: Int): SyncStatus?
    
    @Query("SELECT * FROM sync_status WHERE needsSync = 1")
    suspend fun getPendingSync(): List<SyncStatus>
    
    @Query("SELECT * FROM sync_status WHERE entityType = :type")
    suspend fun getSyncStatusForType(type: String): List<SyncStatus>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSyncStatus(status: SyncStatus)
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSyncStatuses(statuses: List<SyncStatus>)
    
    @Update
    suspend fun updateSyncStatus(status: SyncStatus)
    
    @Query("UPDATE sync_status SET lastSyncTime = :timestamp, needsSync = 0 WHERE entityType = :type AND entityId = :id")
    suspend fun markSynced(type: String, id: Int, timestamp: Long)
    
    @Query("UPDATE sync_status SET needsSync = 1 WHERE entityType = :type AND entityId = :id")
    suspend fun markNeedsSync(type: String, id: Int)
    
    @Query("DELETE FROM sync_status WHERE entityType = :type AND entityId = :id")
    suspend fun deleteSyncStatus(type: String, id: Int)
}

@Dao
interface MediaCacheDao {
    
    @Query("SELECT * FROM media_cache WHERE url = :url")
    suspend fun getMediaCache(url: String): MediaCache?
    
    @Query("SELECT * FROM media_cache ORDER BY lastAccessed DESC")
    suspend fun getAllCachedMedia(): List<MediaCache>
    
    @Query("SELECT SUM(fileSize) FROM media_cache")
    suspend fun getTotalCacheSize(): Long?
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMediaCache(media: MediaCache)
    
    @Update
    suspend fun updateMediaCache(media: MediaCache)
    
    @Query("UPDATE media_cache SET lastAccessed = :timestamp WHERE url = :url")
    suspend fun updateLastAccessed(url: String, timestamp: Long)
    
    @Query("DELETE FROM media_cache WHERE url = :url")
    suspend fun deleteMediaCache(url: String)
    
    @Query("DELETE FROM media_cache WHERE downloadedAt < :expireTime")
    suspend fun deleteExpiredMedia(expireTime: Long)
    
    @Query("DELETE FROM media_cache WHERE url IN (SELECT url FROM media_cache ORDER BY lastAccessed ASC LIMIT :count)")
    suspend fun deleteLeastRecentlyUsed(count: Int)
    
    @Query("SELECT * FROM media_cache ORDER BY lastAccessed ASC LIMIT :count")
    suspend fun getLeastRecentlyUsedMedia(count: Int): List<MediaCache>
}