package com.displaydeck.androidtv.data.repository

import kotlinx.coroutines.flow.Flow

interface PairingRepository {
    suspend fun generatePairingToken(): String
    suspend fun waitForPairing(token: String): Flow<Boolean>
    suspend fun savePairingInfo(displayToken: String, businessId: Int)
}