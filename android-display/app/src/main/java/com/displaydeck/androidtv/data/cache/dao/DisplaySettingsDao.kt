package com.displaydeck.androidtv.data.cache.dao

import androidx.room.*
import com.displaydeck.androidtv.data.cache.entities.DisplaySettings
import com.displaydeck.androidtv.data.cache.entities.SyncStatus
import com.displaydeck.androidtv.data.cache.entities.MediaCache
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object for display settings operations.
 * Manages display configuration, sync status, and media cache.
 */
@Dao
interface DisplaySettingsDao {
    
    // Display Settings operations
    @Query("SELECT * FROM display_settings WHERE display_id = :displayId")
    suspend fun getDisplaySettings(displayId: String): DisplaySettings?
    
    @Query("SELECT * FROM display_settings WHERE display_id = :displayId")
    fun getDisplaySettingsFlow(displayId: String): Flow<DisplaySettings?>
    
    @Query("SELECT * FROM display_settings ORDER BY updated_at DESC")
    suspend fun getAllDisplaySettings(): List<DisplaySettings>
    
    @Query("SELECT * FROM display_settings ORDER BY updated_at DESC")
    fun getAllDisplaySettingsFlow(): Flow<List<DisplaySettings>>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDisplaySettings(settings: DisplaySettings)
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDisplaySettings(settings: List<DisplaySettings>)
    
    @Update
    suspend fun updateDisplaySettings(settings: DisplaySettings)
    
    @Delete
    suspend fun deleteDisplaySettings(settings: DisplaySettings)
    
    @Query("DELETE FROM display_settings WHERE display_id = :displayId")
    suspend fun deleteDisplaySettingsByDisplayId(displayId: String)
    
    @Query("DELETE FROM display_settings")
    suspend fun deleteAllDisplaySettings()
    
    // Settings specific updates
    @Query("UPDATE display_settings SET brightness = :brightness WHERE display_id = :displayId")
    suspend fun updateBrightness(displayId: String, brightness: Int)
    
    @Query("UPDATE display_settings SET volume = :volume WHERE display_id = :displayId")
    suspend fun updateVolume(displayId: String, volume: Int)
    
    @Query("UPDATE display_settings SET orientation = :orientation WHERE display_id = :displayId")
    suspend fun updateOrientation(displayId: String, orientation: String)
    
    @Query("UPDATE display_settings SET theme = :theme WHERE display_id = :displayId")
    suspend fun updateTheme(displayId: String, theme: String)
    
    @Query("UPDATE display_settings SET animation_enabled = :enabled WHERE display_id = :displayId")
    suspend fun updateAnimationEnabled(displayId: String, enabled: Boolean)
    
    @Query("UPDATE display_settings SET auto_update_enabled = :enabled WHERE display_id = :displayId")
    suspend fun updateAutoUpdateEnabled(displayId: String, enabled: Boolean)
    
    @Query("UPDATE display_settings SET sleep_timeout = :timeout WHERE display_id = :displayId")
    suspend fun updateSleepTimeout(displayId: String, timeout: Int)
    
    // Configuration retrieval
    @Query("SELECT brightness FROM display_settings WHERE display_id = :displayId")
    suspend fun getBrightness(displayId: String): Int?
    
    @Query("SELECT volume FROM display_settings WHERE display_id = :displayId")
    suspend fun getVolume(displayId: String): Int?
    
    @Query("SELECT orientation FROM display_settings WHERE display_id = :displayId")
    suspend fun getOrientation(displayId: String): String?
    
    @Query("SELECT theme FROM display_settings WHERE display_id = :displayId")
    suspend fun getTheme(displayId: String): String?
    
    @Query("SELECT animation_enabled FROM display_settings WHERE display_id = :displayId")
    suspend fun isAnimationEnabled(displayId: String): Boolean?
    
    @Query("SELECT auto_update_enabled FROM display_settings WHERE display_id = :displayId")
    suspend fun isAutoUpdateEnabled(displayId: String): Boolean?
}