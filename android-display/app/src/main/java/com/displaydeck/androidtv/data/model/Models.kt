package com.displaydeck.androidtv.data.model

import kotlinx.serialization.Serializable

@Serializable
data class MenuItem(
    val id: Int,
    val name: String,
    val description: String = "",
    val price: Double,
    val imageUrl: String? = null,
    val isAvailable: Boolean = true,
    val category: String,
    val allergens: List<String> = emptyList(),
    val nutritionInfo: NutritionInfo? = null
)

@Serializable
data class MenuCategory(
    val id: Int,
    val name: String,
    val description: String = "",
    val displayOrder: Int = 0,
    val items: List<MenuItem> = emptyList()
)

@Serializable
data class Menu(
    val id: Int,
    val name: String,
    val description: String = "",
    val isActive: Boolean = true,
    val categories: List<MenuCategory> = emptyList(),
    val lastUpdated: String? = null
)

@Serializable
data class BusinessInfo(
    val id: Int,
    val name: String,
    val address: String = "",
    val logo: String? = null,
    val primaryColor: String? = null,
    val secondaryColor: String? = null
)

@Serializable
data class NutritionInfo(
    val calories: Int? = null,
    val protein: Double? = null,
    val carbs: Double? = null,
    val fat: Double? = null,
    val fiber: Double? = null,
    val sodium: Double? = null
)

@Serializable
data class WebSocketUpdate(
    val type: String,
    val data: kotlinx.serialization.json.JsonObject
)