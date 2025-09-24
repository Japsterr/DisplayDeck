package com.displaydeck.androidtv.data.cache.dao

import androidx.room.*
import com.displaydeck.androidtv.data.cache.entities.CachedBusiness
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object for cached business operations.
 * Provides methods for CRUD operations on business data with offline support.
 */
@Dao
interface CachedBusinessDao {
    
    // Basic CRUD operations
    @Query("SELECT * FROM cached_businesses WHERE id = :businessId")
    suspend fun getBusinessById(businessId: Long): CachedBusiness?
    
    @Query("SELECT * FROM cached_businesses WHERE id = :businessId")
    fun getBusinessByIdFlow(businessId: Long): Flow<CachedBusiness?>
    
    @Query("SELECT * FROM cached_businesses ORDER BY name ASC")
    suspend fun getAllBusinesses(): List<CachedBusiness>
    
    @Query("SELECT * FROM cached_businesses ORDER BY name ASC")
    fun getAllBusinessesFlow(): Flow<List<CachedBusiness>>
    
    @Query("SELECT * FROM cached_businesses WHERE is_active = 1 ORDER BY name ASC")
    suspend fun getActiveBusinesses(): List<CachedBusiness>
    
    @Query("SELECT * FROM cached_businesses WHERE is_active = 1 ORDER BY name ASC")
    fun getActiveBusinessesFlow(): Flow<List<CachedBusiness>>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertBusiness(business: CachedBusiness): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertBusinesses(businesses: List<CachedBusiness>): List<Long>
    
    @Update
    suspend fun updateBusiness(business: CachedBusiness)
    
    @Delete
    suspend fun deleteBusiness(business: CachedBusiness)
    
    @Query("DELETE FROM cached_businesses WHERE id = :businessId")
    suspend fun deleteBusinessById(businessId: Long)
    
    @Query("DELETE FROM cached_businesses")
    suspend fun deleteAllBusinesses()
    
    // Search and filtering
    @Query("SELECT * FROM cached_businesses WHERE name LIKE '%' || :query || '%' OR description LIKE '%' || :query || '%'")
    suspend fun searchBusinesses(query: String): List<CachedBusiness>
    
    @Query("SELECT * FROM cached_businesses WHERE business_type = :businessType ORDER BY name ASC")
    suspend fun getBusinessesByType(businessType: String): List<CachedBusiness>
    
    @Query("SELECT * FROM cached_businesses WHERE address LIKE '%' || :location || '%' ORDER BY name ASC")
    suspend fun getBusinessesByLocation(location: String): List<CachedBusiness>
    
    // Business status operations
    @Query("UPDATE cached_businesses SET is_active = :isActive WHERE id = :businessId")
    suspend fun updateBusinessActiveStatus(businessId: Long, isActive: Boolean)
    
    @Query("UPDATE cached_businesses SET operating_hours = :operatingHours WHERE id = :businessId")
    suspend fun updateBusinessOperatingHours(businessId: Long, operatingHours: String)
    
    @Query("UPDATE cached_businesses SET contact_info = :contactInfo WHERE id = :businessId")
    suspend fun updateBusinessContactInfo(businessId: Long, contactInfo: String)
    
    // Logo and branding operations
    @Query("UPDATE cached_businesses SET logo_url = :logoUrl WHERE id = :businessId")
    suspend fun updateBusinessLogo(businessId: Long, logoUrl: String?)
    
    @Query("UPDATE cached_businesses SET theme_color = :themeColor WHERE id = :businessId")
    suspend fun updateBusinessThemeColor(businessId: Long, themeColor: String?)
    
    // Sync and cache management
    @Query("SELECT COUNT(*) FROM cached_businesses")
    suspend fun getBusinessCount(): Int
    
    @Query("SELECT MAX(updated_at) FROM cached_businesses")
    suspend fun getLatestUpdateTime(): Long?
    
    @Query("DELETE FROM cached_businesses WHERE updated_at < :cutoffTime")
    suspend fun deleteOldBusinesses(cutoffTime: Long): Int
    
    @Query("SELECT * FROM cached_businesses WHERE last_sync < :cutoffTime OR last_sync IS NULL")
    suspend fun getBusinessesNeedingSync(cutoffTime: Long): List<CachedBusiness>
    
    @Query("UPDATE cached_businesses SET last_sync = :syncTime WHERE id = :businessId")
    suspend fun updateBusinessSyncTime(businessId: Long, syncTime: Long)
    
    // Business validation and health checks
    @Query("SELECT EXISTS(SELECT 1 FROM cached_businesses WHERE id = :businessId)")
    suspend fun businessExists(businessId: Long): Boolean
    
    @Query("SELECT id FROM cached_businesses WHERE is_active = 1")
    suspend fun getActiveBusinessIds(): List<Long>
    
    @Query("SELECT * FROM cached_businesses WHERE updated_at > :lastUpdate ORDER BY updated_at DESC")
    suspend fun getRecentlyUpdatedBusinesses(lastUpdate: Long): List<CachedBusiness>
    
    // Configuration and settings
    @Query("SELECT theme_color FROM cached_businesses WHERE id = :businessId")
    suspend fun getBusinessThemeColor(businessId: Long): String?
    
    @Query("SELECT logo_url FROM cached_businesses WHERE id = :businessId")
    suspend fun getBusinessLogoUrl(businessId: Long): String?
    
    @Query("SELECT operating_hours FROM cached_businesses WHERE id = :businessId")
    suspend fun getBusinessOperatingHours(businessId: Long): String?
    
    @Query("SELECT contact_info FROM cached_businesses WHERE id = :businessId")
    suspend fun getBusinessContactInfo(businessId: Long): String?
    
    // Batch operations for sync
    @Transaction
    suspend fun replaceAllBusinesses(businesses: List<CachedBusiness>) {
        deleteAllBusinesses()
        insertBusinesses(businesses)
    }
    
    @Transaction
    suspend fun syncBusiness(business: CachedBusiness) {
        val existingBusiness = getBusinessById(business.id)
        if (existingBusiness != null) {
            updateBusiness(business.copy(
                createdAt = existingBusiness.createdAt,
                lastSync = System.currentTimeMillis()
            ))
        } else {
            insertBusiness(business.copy(
                lastSync = System.currentTimeMillis()
            ))
        }
    }
    
    @Transaction
    suspend fun syncBusinesses(businesses: List<CachedBusiness>) {
        businesses.forEach { business ->
            syncBusiness(business)
        }
    }
}