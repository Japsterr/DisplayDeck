package com.displaydeck.androidtv.data.repository

import com.displaydeck.androidtv.data.model.BusinessInfo
import com.displaydeck.androidtv.data.model.Menu
import com.displaydeck.androidtv.data.model.WebSocketUpdate
import kotlinx.coroutines.flow.Flow

interface DisplayRepository {
    suspend fun getBusinessInfo(): BusinessInfo
    suspend fun getMenuData(): Menu
    suspend fun connectToWebSocket(): Flow<WebSocketUpdate>
    suspend fun saveDisplayToken(token: String)
    suspend fun getDisplayToken(): String?
}