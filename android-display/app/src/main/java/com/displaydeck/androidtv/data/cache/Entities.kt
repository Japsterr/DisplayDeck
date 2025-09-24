package com.displaydeck.androidtv.data.cache

import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.TypeConverters
import kotlinx.serialization.Serializable

@Entity(tableName = "cached_menus")
@TypeConverters(Converters::class)
data class CachedMenu(
    @PrimaryKey
    val id: Int,
    val businessId: Int,
    val name: String,
    val description: String,
    val isActive: Boolean,
    val categories: List<CachedMenuCategory>,
    val lastUpdated: String,
    val cachedAt: Long = System.currentTimeMillis()
)

@Serializable
data class CachedMenuCategory(
    val id: Int,
    val name: String,
    val description: String,
    val displayOrder: Int,
    val items: List<CachedMenuItem>
)

@Serializable
data class CachedMenuItem(
    val id: Int,
    val name: String,
    val description: String,
    val price: Double,
    val imageUrl: String?,
    val isAvailable: Boolean,
    val category: String,
    val allergens: List<String>,
    val nutritionInfo: CachedNutritionInfo?
)

@Serializable
data class CachedNutritionInfo(
    val calories: Int?,
    val protein: Double?,
    val carbs: Double?,
    val fat: Double?,
    val fiber: Double?,
    val sodium: Double?
)

@Entity(tableName = "cached_businesses")
data class CachedBusiness(
    @PrimaryKey
    val id: Int,
    val name: String,
    val address: String,
    val logo: String?,
    val primaryColor: String?,
    val secondaryColor: String?,
    val cachedAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "display_settings")
data class DisplaySettings(
    @PrimaryKey
    val id: Int = 1, // Single row table
    val deviceId: String,
    val displayName: String?,
    val location: String?,
    val assignedMenuId: Int?,
    val businessId: Int?,
    val isPaired: Boolean = false,
    val apiToken: String?,
    val lastSync: Long = 0L
)

@Entity(tableName = "sync_status")
data class SyncStatus(
    @PrimaryKey
    val entityType: String, // "menu", "business", etc.
    val entityId: Int,
    val lastSyncTime: Long,
    val syncVersion: Int = 1,
    val needsSync: Boolean = false
)

@Entity(tableName = "media_cache")
data class MediaCache(
    @PrimaryKey
    val url: String,
    val localPath: String,
    val mimeType: String,
    val fileSize: Long,
    val downloadedAt: Long = System.currentTimeMillis(),
    val lastAccessed: Long = System.currentTimeMillis()
)