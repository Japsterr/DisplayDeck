package com.displaydeck.androidtv.data.cache.entities

import androidx.room.*
import androidx.room.TypeConverters
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json

/**
 * Room entity for cached menu data.
 * Represents a complete menu with metadata for offline use.
 */
@Entity(
    tableName = "cached_menus",
    foreignKeys = [
        ForeignKey(
            entity = CachedBusiness::class,
            parentColumns = ["id"],
            childColumns = ["business_id"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [
        Index(value = ["business_id"]),
        Index(value = ["display_id"]),
        Index(value = ["is_active"])
    ]
)
data class CachedMenu(
    @PrimaryKey
    val id: Long,
    @ColumnInfo(name = "business_id")
    val businessId: Long,
    @ColumnInfo(name = "display_id")
    val displayId: Long? = null,
    val name: String,
    val description: String? = null,
    @ColumnInfo(name = "is_active")
    val isActive: Boolean = true,
    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "last_sync")
    val lastSync: Long? = null,
    @ColumnInfo(name = "version")
    val version: Int = 1
)

/**
 * Room entity for cached menu categories.
 */
@Entity(
    tableName = "cached_menu_categories",
    foreignKeys = [
        ForeignKey(
            entity = CachedMenu::class,
            parentColumns = ["id"],
            childColumns = ["menu_id"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [
        Index(value = ["menu_id"]),
        Index(value = ["display_order"])
    ]
)
data class CachedMenuCategory(
    @PrimaryKey
    val id: Long,
    @ColumnInfo(name = "menu_id")
    val menuId: Long,
    val name: String,
    val description: String? = null,
    @ColumnInfo(name = "display_order")
    val displayOrder: Int = 0,
    @ColumnInfo(name = "is_active")
    val isActive: Boolean = true,
    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis()
)

/**
 * Room entity for cached menu items.
 */
@Entity(
    tableName = "cached_menu_items",
    foreignKeys = [
        ForeignKey(
            entity = CachedMenu::class,
            parentColumns = ["id"],
            childColumns = ["menu_id"],
            onDelete = ForeignKey.CASCADE
        ),
        ForeignKey(
            entity = CachedMenuCategory::class,
            parentColumns = ["id"],
            childColumns = ["category_id"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [
        Index(value = ["menu_id"]),
        Index(value = ["category_id"]),
        Index(value = ["is_available"]),
        Index(value = ["display_order"])
    ]
)
@TypeConverters(Converters::class)
data class CachedMenuItem(
    @PrimaryKey
    val id: Long,
    @ColumnInfo(name = "menu_id")
    val menuId: Long,
    @ColumnInfo(name = "category_id")
    val categoryId: Long,
    val name: String,
    val description: String? = null,
    val price: Double,
    @ColumnInfo(name = "image_url")
    val imageUrl: String? = null,
    @ColumnInfo(name = "is_available")
    val isAvailable: Boolean = true,
    @ColumnInfo(name = "display_order")
    val displayOrder: Int = 0,
    val allergens: List<String> = emptyList(),
    @ColumnInfo(name = "nutrition_info")
    val nutritionInfo: NutritionInfo? = null,
    val tags: List<String> = emptyList(),
    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis()
)

/**
 * Room entity for cached business data.
 */
@Entity(
    tableName = "cached_businesses",
    indices = [
        Index(value = ["is_active"]),
        Index(value = ["business_type"])
    ]
)
@TypeConverters(Converters::class)
data class CachedBusiness(
    @PrimaryKey
    val id: Long,
    val name: String,
    val description: String? = null,
    val address: String? = null,
    @ColumnInfo(name = "business_type")
    val businessType: String? = null,
    @ColumnInfo(name = "logo_url")
    val logoUrl: String? = null,
    @ColumnInfo(name = "theme_color")
    val themeColor: String? = null,
    @ColumnInfo(name = "operating_hours")
    val operatingHours: String? = null,
    @ColumnInfo(name = "contact_info")
    val contactInfo: String? = null,
    @ColumnInfo(name = "is_active")
    val isActive: Boolean = true,
    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "last_sync")
    val lastSync: Long? = null
)

/**
 * Room entity for display settings and configuration.
 */
@Entity(
    tableName = "display_settings",
    indices = [Index(value = ["display_id"], unique = true)]
)
@TypeConverters(Converters::class)
data class DisplaySettings(
    @PrimaryKey
    @ColumnInfo(name = "display_id")
    val displayId: String,
    @ColumnInfo(name = "device_name")
    val deviceName: String? = null,
    val location: String? = null,
    @ColumnInfo(name = "business_id")
    val businessId: Long? = null,
    @ColumnInfo(name = "assigned_menu_id")
    val assignedMenuId: Long? = null,
    @ColumnInfo(name = "is_paired")
    val isPaired: Boolean = false,
    @ColumnInfo(name = "api_token")
    val apiToken: String? = null,
    val brightness: Int = 100,
    val volume: Int = 50,
    val orientation: String = "landscape",
    val theme: String = "default",
    @ColumnInfo(name = "animation_enabled")
    val animationEnabled: Boolean = true,
    @ColumnInfo(name = "auto_update_enabled")
    val autoUpdateEnabled: Boolean = true,
    @ColumnInfo(name = "sleep_timeout")
    val sleepTimeout: Int = 3600, // seconds
    val configuration: Map<String, String> = emptyMap(),
    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "last_sync")
    val lastSync: Long? = null
)

/**
 * Room entity for tracking synchronization status of various entities.
 */
@Entity(
    tableName = "sync_status",
    primaryKeys = ["entity_type", "entity_id"],
    indices = [
        Index(value = ["entity_type"]),
        Index(value = ["is_synced"]),
        Index(value = ["last_sync_attempt"])
    ]
)
data class SyncStatus(
    @ColumnInfo(name = "entity_type")
    val entityType: String, // "menu", "business", "display_settings", etc.
    @ColumnInfo(name = "entity_id")
    val entityId: String,
    @ColumnInfo(name = "is_synced")
    val isSynced: Boolean = false,
    @ColumnInfo(name = "last_sync_attempt")
    val lastSyncAttempt: Long? = null,
    @ColumnInfo(name = "last_successful_sync")
    val lastSuccessfulSync: Long? = null,
    @ColumnInfo(name = "sync_error")
    val syncError: String? = null,
    @ColumnInfo(name = "retry_count")
    val retryCount: Int = 0,
    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis()
)

/**
 * Room entity for media file caching.
 */
@Entity(
    tableName = "media_cache",
    indices = [
        Index(value = ["is_cached"]),
        Index(value = ["media_type"]),
        Index(value = ["last_accessed"]),
        Index(value = ["expires_at"])
    ]
)
data class MediaCache(
    @PrimaryKey
    val url: String,
    @ColumnInfo(name = "local_path")
    val localPath: String? = null,
    @ColumnInfo(name = "media_type")
    val mediaType: String, // "image", "video", "audio"
    @ColumnInfo(name = "file_size")
    val fileSize: Long = 0,
    @ColumnInfo(name = "is_cached")
    val isCached: Boolean = false,
    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "last_accessed")
    val lastAccessed: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "expires_at")
    val expiresAt: Long? = null
)

/**
 * Data classes for complex data types.
 */
@Serializable
data class NutritionInfo(
    val calories: Int? = null,
    val protein: Double? = null,
    val carbs: Double? = null,
    val fat: Double? = null,
    val fiber: Double? = null,
    val sodium: Double? = null
)

/**
 * Type converters for Room database.
 */
class Converters {
    
    private val json = Json { 
        ignoreUnknownKeys = true
        coerceInputValues = true
    }
    
    // List<String> converters
    @TypeConverter
    fun fromStringList(value: List<String>): String {
        return json.encodeToString(value)
    }
    
    @TypeConverter
    fun toStringList(value: String): List<String> {
        return try {
            json.decodeFromString(value)
        } catch (e: Exception) {
            emptyList()
        }
    }
    
    // Map<String, String> converters
    @TypeConverter
    fun fromStringMap(value: Map<String, String>): String {
        return json.encodeToString(value)
    }
    
    @TypeConverter
    fun toStringMap(value: String): Map<String, String> {
        return try {
            json.decodeFromString(value)
        } catch (e: Exception) {
            emptyMap()
        }
    }
    
    // NutritionInfo converters
    @TypeConverter
    fun fromNutritionInfo(value: NutritionInfo?): String? {
        return value?.let { json.encodeToString(it) }
    }
    
    @TypeConverter
    fun toNutritionInfo(value: String?): NutritionInfo? {
        return value?.let {
            try {
                json.decodeFromString<NutritionInfo>(it)
            } catch (e: Exception) {
                null
            }
        }
    }
}