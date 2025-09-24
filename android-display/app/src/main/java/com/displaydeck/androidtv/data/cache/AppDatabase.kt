package com.displaydeck.androidtv.data.cache

import androidx.room.*
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import android.content.Context
import com.displaydeck.androidtv.data.cache.entities.*
import com.displaydeck.androidtv.data.cache.dao.*

@Database(
    entities = [
        CachedMenu::class,
        CachedMenuCategory::class,
        CachedMenuItem::class,
        CachedBusiness::class,
        DisplaySettings::class,
        SyncStatus::class,
        MediaCache::class
    ],
    version = 1,
    exportSchema = false
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    
    abstract fun cachedMenuDao(): CachedMenuDao
    abstract fun cachedBusinessDao(): CachedBusinessDao
    abstract fun displaySettingsDao(): DisplaySettingsDao
    abstract fun syncStatusDao(): SyncStatusDao
    abstract fun mediaCacheDao(): MediaCacheDao
    
    companion object {
        const val DATABASE_NAME = "displaydeck_cache.db"
        
        // Cache expiration times
        const val MENU_CACHE_EXPIRY_HOURS = 24L
        const val BUSINESS_CACHE_EXPIRY_HOURS = 72L
        const val MEDIA_CACHE_EXPIRY_DAYS = 7L
        
        // Media cache limits
        const val MAX_MEDIA_CACHE_SIZE_MB = 500L
        const val MEDIA_CLEANUP_THRESHOLD_MB = 400L
        
        // Singleton instance
        @Volatile
        private var INSTANCE: AppDatabase? = null
        
        /**
         * Get database instance using singleton pattern.
         * Thread-safe implementation with double-checked locking.
         */
        fun getDatabase(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    DATABASE_NAME
                )
                    .fallbackToDestructiveMigration() // For development - remove in production
                    .enableMultiInstanceInvalidation() // For multiple app instances
                    .addMigrations(MIGRATION_1_2, MIGRATION_2_3) // Add future migrations
                    .build()
                
                INSTANCE = instance
                instance
            }
        }
        
        /**
         * Create database instance for testing with in-memory database.
         */
        fun getInMemoryDatabase(context: Context): AppDatabase {
            return Room.inMemoryDatabaseBuilder(
                context.applicationContext,
                AppDatabase::class.java
            )
                .allowMainThreadQueries() // Only for testing
                .build()
        }
        
        /**
         * Close and destroy database instance.
         * Useful for testing cleanup.
         */
        fun destroyInstance() {
            INSTANCE?.close()
            INSTANCE = null
        }
        
        // Future migration examples
        private val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(database: SupportSQLiteDatabase) {
                // Example migration - add new column
                // database.execSQL("ALTER TABLE cached_menus ADD COLUMN newField TEXT")
            }
        }
        
        private val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(database: SupportSQLiteDatabase) {
                // Example migration - create new table
                // database.execSQL("CREATE TABLE new_table (id INTEGER PRIMARY KEY, name TEXT)")
            }
        }
    }
}

/**
 * Repository pattern implementation for centralized data access.
 * Provides a clean API for data operations across the app.
 */
class CacheRepository(private val database: AppDatabase) {
    
    // DAO instances
    val menuDao = database.cachedMenuDao()
    val businessDao = database.cachedBusinessDao()
    val settingsDao = database.displaySettingsDao()
    val syncDao = database.syncStatusDao()
    val mediaDao = database.mediaCacheDao()
    
    /**
     * Clear all cached data.
     * Useful for logout or data reset scenarios.
     */
    suspend fun clearAllData() {
        database.runInTransaction {
            menuDao.deleteItemsForMenu(-1) // Delete all items
            menuDao.deleteCategoriesForMenu(-1) // Delete all categories  
            menuDao.deleteMenusForBusiness(-1) // Delete all menus
            businessDao.deleteAllBusinesses()
            settingsDao.deleteAllDisplaySettings()
            syncDao.deleteAllSyncStatus()
            mediaDao.deleteAllMedia()
        }
    }
    
    /**
     * Clear cache for specific business.
     */
    suspend fun clearBusinessData(businessId: Long) {
        database.runInTransaction {
            menuDao.deleteMenusForBusiness(businessId)
            businessDao.deleteBusinessById(businessId)
        }
    }
    
    /**
     * Sync menu data from server response.
     */
    suspend fun syncMenuData(
        menu: CachedMenu,
        categories: List<CachedMenuCategory>,
        items: List<CachedMenuItem>
    ) {
        database.runInTransaction {
            menuDao.replaceMenu(menu, categories, items)
            syncDao.recordSyncAttempt("menu", menu.id.toString(), true)
        }
    }
    
    /**
     * Sync business data from server response.
     */
    suspend fun syncBusinessData(business: CachedBusiness) {
        database.runInTransaction {
            businessDao.syncBusiness(business)
            syncDao.recordSyncAttempt("business", business.id.toString(), true)
        }
    }
    
    /**
     * Get cache statistics for monitoring and debugging.
     */
    suspend fun getCacheStatistics(): CacheStatistics {
        return CacheStatistics(
            totalMenus = menuDao.getMenuCountForBusiness(-1), // Get count for all businesses
            totalBusinesses = businessDao.getBusinessCount(),
            totalMediaFiles = mediaDao.getCachedMediaCount(),
            totalCacheSize = mediaDao.getTotalCacheSize() ?: 0,
            unsyncedEntities = syncDao.getUnsyncedEntities().size,
            entitiesWithErrors = syncDao.getEntitiesWithSyncErrors().size
        )
    }
    
    /**
     * Perform cache cleanup to free space and remove old data.
     */
    suspend fun performCacheCleanup(
        maxCacheSizeBytes: Long = DatabaseUtils.getMaxCacheSizeBytes(),
        maxCacheAgeMillis: Long = DatabaseUtils.getMediaExpirationTime()
    ) {
        database.runInTransaction {
            val currentTime = System.currentTimeMillis()
            val cutoffTime = currentTime - maxCacheAgeMillis
            
            // Clean up media cache
            mediaDao.cleanupCache(maxCacheSizeBytes, maxCacheAgeMillis)
            
            // Clean up old sync status
            syncDao.deleteOldSyncStatus(cutoffTime)
            
            // Clean up old menu data
            menuDao.deleteOldMenus(cutoffTime)
            
            // Clean up old business data
            businessDao.deleteOldBusinesses(cutoffTime)
        }
    }
    
    /**
     * Check database health and integrity.
     */
    suspend fun performHealthCheck(): DatabaseHealthStatus {
        return try {
            val menuCount = menuDao.getMenuCountForBusiness(-1)
            val businessCount = businessDao.getBusinessCount()
            val syncErrors = syncDao.getEntitiesWithSyncErrors().size
            val cacheSize = mediaDao.getTotalCacheSize() ?: 0
            
            DatabaseHealthStatus(
                isHealthy = true,
                menuCount = menuCount,
                businessCount = businessCount,
                syncErrorCount = syncErrors,
                totalCacheSize = cacheSize,
                lastCheckTime = System.currentTimeMillis()
            )
        } catch (e: Exception) {
            DatabaseHealthStatus(
                isHealthy = false,
                error = e.message,
                lastCheckTime = System.currentTimeMillis()
            )
        }
    }
}

/**
 * Data class for cache statistics.
 */
data class CacheStatistics(
    val totalMenus: Int,
    val totalBusinesses: Int,
    val totalMediaFiles: Int,
    val totalCacheSize: Long,
    val unsyncedEntities: Int,
    val entitiesWithErrors: Int
)

/**
 * Data class for database health status.
 */
data class DatabaseHealthStatus(
    val isHealthy: Boolean,
    val menuCount: Int = 0,
    val businessCount: Int = 0,
    val syncErrorCount: Int = 0,
    val totalCacheSize: Long = 0,
    val error: String? = null,
    val lastCheckTime: Long
)

// Database initialization and utility functions
object DatabaseUtils {
    
    /**
     * Calculate cache expiration time for menus
     */
    fun getMenuExpirationTime(): Long {
        return System.currentTimeMillis() - (AppDatabase.MENU_CACHE_EXPIRY_HOURS * 60 * 60 * 1000)
    }
    
    /**
     * Calculate cache expiration time for businesses
     */
    fun getBusinessExpirationTime(): Long {
        return System.currentTimeMillis() - (AppDatabase.BUSINESS_CACHE_EXPIRY_HOURS * 60 * 60 * 1000)
    }
    
    /**
     * Calculate cache expiration time for media
     */
    fun getMediaExpirationTime(): Long {
        return System.currentTimeMillis() - (AppDatabase.MEDIA_CACHE_EXPIRY_DAYS * 24 * 60 * 60 * 1000)
    }
    
    /**
     * Convert MB to bytes
     */
    fun mbToBytes(mb: Long): Long {
        return mb * 1024 * 1024
    }
    
    /**
     * Check if cache size is over threshold
     */
    fun isCacheOverThreshold(currentSizeBytes: Long): Boolean {
        return currentSizeBytes > mbToBytes(AppDatabase.MEDIA_CLEANUP_THRESHOLD_MB)
    }
    
    /**
     * Get maximum cache size in bytes
     */
    fun getMaxCacheSizeBytes(): Long {
        return mbToBytes(AppDatabase.MAX_MEDIA_CACHE_SIZE_MB)
    }
}