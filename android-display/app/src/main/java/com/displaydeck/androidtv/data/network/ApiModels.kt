package com.displaydeck.androidtv.data.network

import kotlinx.serialization.Serializable

// Base API response wrapper
@Serializable
data class ApiResponse<T>(
    val success: Boolean,
    val data: T? = null,
    val error: String? = null,
    val timestamp: String? = null
)

// Authentication models
@Serializable
data class LoginRequest(
    val email: String,
    val password: String
)

@Serializable
data class TokenResponse(
    val access_token: String,
    val refresh_token: String,
    val expires_in: Int,
    val token_type: String = "Bearer"
)

@Serializable
data class DisplayPairRequest(
    val display_name: String,
    val device_id: String,
    val pairing_code: String
)

@Serializable
data class DisplayPairResponse(
    val display_id: Int,
    val access_token: String,
    val refresh_token: String,
    val business_id: Int,
    val assigned_menu_id: Int?
)

// Business models
@Serializable
data class BusinessDto(
    val id: Int,
    val name: String,
    val description: String?,
    val logo_url: String?,
    val address: String?,
    val phone: String?,
    val email: String?,
    val website: String?,
    val timezone: String,
    val created_at: String,
    val updated_at: String
)

// Menu models
@Serializable
data class MenuDto(
    val id: Int,
    val business_id: Int,
    val name: String,
    val description: String?,
    val is_active: Boolean,
    val display_order: Int,
    val background_color: String?,
    val text_color: String?,
    val font_family: String?,
    val categories: List<MenuCategoryDto> = emptyList(),
    val created_at: String,
    val updated_at: String
)

@Serializable
data class MenuCategoryDto(
    val id: Int,
    val menu_id: Int,
    val name: String,
    val description: String?,
    val display_order: Int,
    val is_visible: Boolean,
    val items: List<MenuItemDto> = emptyList()
)

@Serializable
data class MenuItemDto(
    val id: Int,
    val category_id: Int,
    val name: String,
    val description: String?,
    val price: String?,
    val image_url: String?,
    val is_available: Boolean,
    val is_featured: Boolean,
    val display_order: Int,
    val allergens: List<String> = emptyList(),
    val dietary_info: List<String> = emptyList(),
    val created_at: String,
    val updated_at: String
)

// Display models
@Serializable
data class DisplayDto(
    val id: Int,
    val business_id: Int,
    val name: String,
    val device_id: String,
    val assigned_menu_id: Int?,
    val is_online: Boolean,
    val last_seen: String?,
    val created_at: String,
    val updated_at: String
)

@Serializable
data class DisplayUpdateRequest(
    val name: String? = null,
    val assigned_menu_id: Int? = null
)

// Error response models
@Serializable
data class ErrorResponse(
    val error: String,
    val message: String? = null,
    val details: Map<String, List<String>>? = null
)

// WebSocket message models
@Serializable
data class WebSocketMessage(
    val type: String,
    val data: Map<String, Any>? = null,
    val timestamp: String? = null
)

@Serializable
data class MenuUpdateMessage(
    val menu_id: Int,
    val business_id: Int,
    val action: String, // "update", "delete", "create"
    val menu_data: MenuDto? = null
)

@Serializable
data class DisplayAssignmentMessage(
    val display_id: Int,
    val menu_id: Int?,
    val business_id: Int
)