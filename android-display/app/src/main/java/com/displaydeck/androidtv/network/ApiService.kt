package com.displaydeck.androidtv.network

import retrofit2.Response
import retrofit2.http.*

/**
 * Retrofit API interface for DisplayDeck backend communication.
 * Defines all API endpoints used by the Android TV display client.
 */
interface DisplayDeckApiService {
    
    // Authentication endpoints
    @POST("auth/display/register")
    suspend fun registerDisplay(
        @Body request: DisplayRegistrationRequest
    ): Response<DisplayRegistrationResponse>
    
    @POST("auth/display/pair")
    suspend fun pairDisplay(
        @Body request: DisplayPairingRequest
    ): Response<DisplayPairingResponse>
    
    @POST("auth/display/refresh")
    suspend fun refreshDisplayToken(
        @Header("Authorization") token: String,
        @Body request: TokenRefreshRequest
    ): Response<TokenRefreshResponse>
    
    // Menu endpoints
    @GET("displays/{displayId}/menu")
    suspend fun getDisplayMenu(
        @Path("displayId") displayId: String,
        @Header("Authorization") token: String
    ): Response<MenuResponse>
    
    @GET("displays/{displayId}/menu/check")
    suspend fun checkMenuUpdates(
        @Path("displayId") displayId: String,
        @Header("Authorization") token: String,
        @Query("version") currentVersion: Int
    ): Response<MenuUpdateCheckResponse>
    
    @GET("businesses/{businessId}")
    suspend fun getBusinessInfo(
        @Path("businessId") businessId: Long,
        @Header("Authorization") token: String
    ): Response<BusinessResponse>
    
    // Display management endpoints
    @GET("displays/{displayId}")
    suspend fun getDisplayInfo(
        @Path("displayId") displayId: String,
        @Header("Authorization") token: String
    ): Response<DisplayInfoResponse>
    
    @PUT("displays/{displayId}")
    suspend fun updateDisplayInfo(
        @Path("displayId") displayId: String,
        @Header("Authorization") token: String,
        @Body request: UpdateDisplayRequest
    ): Response<DisplayInfoResponse>
    
    @POST("displays/{displayId}/heartbeat")
    suspend fun sendHeartbeat(
        @Path("displayId") displayId: String,
        @Header("Authorization") token: String,
        @Body request: HeartbeatRequest
    ): Response<HeartbeatResponse>
    
    @GET("displays/{displayId}/settings")
    suspend fun getDisplaySettings(
        @Path("displayId") displayId: String,
        @Header("Authorization") token: String
    ): Response<DisplaySettingsResponse>
    
    @PUT("displays/{displayId}/settings")
    suspend fun updateDisplaySettings(
        @Path("displayId") displayId: String,
        @Header("Authorization") token: String,
        @Body request: UpdateDisplaySettingsRequest
    ): Response<DisplaySettingsResponse>
    
    // Health check and status endpoints
    @GET("health")
    suspend fun healthCheck(): Response<HealthCheckResponse>
    
    @POST("displays/{displayId}/status")
    suspend fun reportDisplayStatus(
        @Path("displayId") displayId: String,
        @Header("Authorization") token: String,
        @Body request: DisplayStatusRequest
    ): Response<DisplayStatusResponse>
    
    // Media endpoints
    @GET("media/{mediaId}")
    suspend fun getMediaInfo(
        @Path("mediaId") mediaId: String,
        @Header("Authorization") token: String
    ): Response<MediaInfoResponse>
}

// Request/Response data classes

/**
 * Display registration request
 */
data class DisplayRegistrationRequest(
    val deviceId: String,
    val deviceName: String,
    val deviceModel: String,
    val osVersion: String,
    val appVersion: String,
    val capabilities: DisplayCapabilities
)

data class DisplayCapabilities(
    val screenResolution: String,
    val supportedMediaTypes: List<String>,
    val hasInternet: Boolean,
    val hasBluetooth: Boolean,
    val hasCamera: Boolean
)

data class DisplayRegistrationResponse(
    val displayId: String,
    val registrationCode: String,
    val expiresAt: String,
    val qrCodeData: String
)

/**
 * Display pairing request
 */
data class DisplayPairingRequest(
    val displayId: String,
    val pairingCode: String,
    val businessId: Long? = null
)

data class DisplayPairingResponse(
    val success: Boolean,
    val accessToken: String?,
    val refreshToken: String?,
    val businessId: Long?,
    val displayName: String?,
    val assignedMenuId: Long?,
    val message: String?
)

/**
 * Token refresh request
 */
data class TokenRefreshRequest(
    val refreshToken: String,
    val displayId: String
)

data class TokenRefreshResponse(
    val accessToken: String,
    val refreshToken: String,
    val expiresIn: Long
)

/**
 * Menu response
 */
data class MenuResponse(
    val menu: MenuData,
    val business: BusinessData,
    val version: Int,
    val lastUpdated: String
)

data class MenuData(
    val id: Long,
    val name: String,
    val description: String?,
    val categories: List<MenuCategoryData>,
    val isActive: Boolean,
    val createdAt: String,
    val updatedAt: String
)

data class MenuCategoryData(
    val id: Long,
    val name: String,
    val description: String?,
    val displayOrder: Int,
    val items: List<MenuItemData>,
    val isActive: Boolean
)

data class MenuItemData(
    val id: Long,
    val name: String,
    val description: String?,
    val price: Double,
    val imageUrl: String?,
    val isAvailable: Boolean,
    val displayOrder: Int,
    val allergens: List<String>,
    val nutritionInfo: NutritionInfoData?,
    val tags: List<String>
)

data class NutritionInfoData(
    val calories: Int?,
    val protein: Double?,
    val carbs: Double?,
    val fat: Double?,
    val fiber: Double?,
    val sodium: Double?
)

data class BusinessData(
    val id: Long,
    val name: String,
    val description: String?,
    val address: String?,
    val businessType: String?,
    val logoUrl: String?,
    val themeColor: String?,
    val operatingHours: String?,
    val contactInfo: String?
)

/**
 * Menu update check response
 */
data class MenuUpdateCheckResponse(
    val hasUpdates: Boolean,
    val currentVersion: Int,
    val latestVersion: Int?,
    val updateAvailable: Boolean
)

/**
 * Business response
 */
data class BusinessResponse(
    val business: BusinessData,
    val activeMenus: List<MenuData>
)

/**
 * Display info response
 */
data class DisplayInfoResponse(
    val displayId: String,
    val deviceName: String?,
    val location: String?,
    val businessId: Long?,
    val assignedMenuId: Long?,
    val isPaired: Boolean,
    val isOnline: Boolean,
    val lastSeen: String?,
    val configuration: Map<String, Any>
)

/**
 * Update display request
 */
data class UpdateDisplayRequest(
    val deviceName: String?,
    val location: String?
)

/**
 * Heartbeat request and response
 */
data class HeartbeatRequest(
    val timestamp: String,
    val status: String, // "online", "idle", "error"
    val systemInfo: SystemInfo
)

data class SystemInfo(
    val batteryLevel: Int?,
    val memoryUsage: Int,
    val storageUsage: Int,
    val temperature: Int?,
    val uptime: Long,
    val lastRestart: String?
)

data class HeartbeatResponse(
    val acknowledged: Boolean,
    val serverTime: String,
    val commands: List<DisplayCommand>?
)

data class DisplayCommand(
    val id: String,
    val type: String, // "restart", "update_settings", "sync_menu", etc.
    val parameters: Map<String, Any>?,
    val executeAt: String?
)

/**
 * Display settings
 */
data class DisplaySettingsResponse(
    val settings: DisplaySettingsData
)

data class DisplaySettingsData(
    val brightness: Int,
    val volume: Int,
    val orientation: String,
    val theme: String,
    val animationEnabled: Boolean,
    val autoUpdateEnabled: Boolean,
    val sleepTimeout: Int,
    val configuration: Map<String, String>
)

data class UpdateDisplaySettingsRequest(
    val brightness: Int? = null,
    val volume: Int? = null,
    val orientation: String? = null,
    val theme: String? = null,
    val animationEnabled: Boolean? = null,
    val autoUpdateEnabled: Boolean? = null,
    val sleepTimeout: Int? = null,
    val configuration: Map<String, String>? = null
)

/**
 * Health check response
 */
data class HealthCheckResponse(
    val status: String,
    val timestamp: String,
    val version: String,
    val services: Map<String, String>
)

/**
 * Display status reporting
 */
data class DisplayStatusRequest(
    val status: String,
    val currentMenuId: Long?,
    val errorMessage: String?,
    val systemHealth: SystemHealthData,
    val timestamp: String
)

data class SystemHealthData(
    val cpuUsage: Int,
    val memoryUsage: Int,
    val diskUsage: Int,
    val networkStatus: String,
    val temperature: Int?,
    val errors: List<String>
)

data class DisplayStatusResponse(
    val acknowledged: Boolean,
    val nextCheckIn: String?,
    val actions: List<DisplayCommand>?
)

/**
 * Media info response
 */
data class MediaInfoResponse(
    val id: String,
    val url: String,
    val type: String,
    val size: Long,
    val mimeType: String,
    val checksum: String?,
    val cacheExpiry: String?
)