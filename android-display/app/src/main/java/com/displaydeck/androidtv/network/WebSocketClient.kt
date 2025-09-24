package com.displaydeck.androidtv.network

import android.content.Context
import android.util.Log
import com.displaydeck.androidtv.utils.PreferencesManager
import com.google.gson.Gson
import com.google.gson.JsonSyntaxException
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.*
import okhttp3.*
import okio.ByteString
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/**
 * WebSocket client for real-time communication with DisplayDeck backend.
 * Handles menu updates, display commands, and live synchronization.
 */
@Singleton
class WebSocketClient @Inject constructor(
    private val context: Context,
    private val preferencesManager: PreferencesManager,
    private val gson: Gson
) {
    
    companion object {
        private const val TAG = "WebSocketClient"
        private const val RECONNECT_INTERVAL_MS = 5000L
        private const val MAX_RECONNECT_ATTEMPTS = 10
        private const val PING_INTERVAL_SECONDS = 30L
        private const val CONNECTION_TIMEOUT_SECONDS = 30L
    }
    
    private var webSocket: WebSocket? = null
    private var reconnectAttempts = 0
    private var isManualDisconnect = false
    
    private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // Message channels and flows
    private val _connectionState = MutableStateFlow(ConnectionState.DISCONNECTED)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()
    
    private val _messages = Channel<WebSocketMessage>(Channel.UNLIMITED)
    val messages = _messages.receiveAsFlow()
    
    private val okHttpClient = OkHttpClient.Builder()
        .pingInterval(PING_INTERVAL_SECONDS, TimeUnit.SECONDS)
        .connectTimeout(CONNECTION_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.SECONDS) // No read timeout for WebSocket
        .build()
    
    private val webSocketListener = object : WebSocketListener() {
        
        override fun onOpen(webSocket: WebSocket, response: Response) {
            Log.d(TAG, "WebSocket connection opened")
            _connectionState.value = ConnectionState.CONNECTED
            reconnectAttempts = 0
            
            // Send authentication message
            sendAuthenticationMessage()
        }
        
        override fun onMessage(webSocket: WebSocket, text: String) {
            Log.d(TAG, "WebSocket message received: $text")
            handleTextMessage(text)
        }
        
        override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
            Log.d(TAG, "WebSocket binary message received: ${bytes.size} bytes")
            handleBinaryMessage(bytes)
        }
        
        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            Log.d(TAG, "WebSocket closing: $code - $reason")
            _connectionState.value = ConnectionState.DISCONNECTING
        }
        
        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            Log.d(TAG, "WebSocket closed: $code - $reason")
            _connectionState.value = ConnectionState.DISCONNECTED
            
            // Attempt reconnection if not manually disconnected
            if (!isManualDisconnect) {
                scheduleReconnect()
            }
        }
        
        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            Log.e(TAG, "WebSocket connection failed", t)
            _connectionState.value = ConnectionState.ERROR
            
            // Attempt reconnection
            if (!isManualDisconnect) {
                scheduleReconnect()
            }
        }
    }
    
    /**
     * Connect to WebSocket server.
     */
    fun connect() {
        if (_connectionState.value == ConnectionState.CONNECTED) {
            Log.d(TAG, "Already connected")
            return
        }
        
        val displayId = preferencesManager.getDisplayId()
        val accessToken = preferencesManager.getAccessToken()
        
        if (displayId == null || accessToken == null) {
            Log.e(TAG, "Cannot connect: missing displayId or accessToken")
            _connectionState.value = ConnectionState.ERROR
            return
        }
        
        isManualDisconnect = false
        _connectionState.value = ConnectionState.CONNECTING
        
        val wsUrl = buildWebSocketUrl()
        val request = Request.Builder()
            .url(wsUrl)
            .addHeader("Authorization", "Bearer $accessToken")
            .addHeader("X-Display-Id", displayId)
            .build()
        
        webSocket?.close(1000, "Reconnecting")
        webSocket = okHttpClient.newWebSocket(request, webSocketListener)
        
        Log.d(TAG, "Connecting to WebSocket: $wsUrl")
    }
    
    /**
     * Disconnect from WebSocket server.
     */
    fun disconnect() {
        isManualDisconnect = true
        _connectionState.value = ConnectionState.DISCONNECTING
        
        webSocket?.close(1000, "Manual disconnect")
        webSocket = null
        
        Log.d(TAG, "WebSocket disconnected manually")
    }
    
    /**
     * Send a message through WebSocket.
     */
    fun sendMessage(message: WebSocketMessage) {
        if (_connectionState.value != ConnectionState.CONNECTED) {
            Log.w(TAG, "Cannot send message: not connected")
            return
        }
        
        try {
            val json = gson.toJson(message)
            webSocket?.send(json)
            Log.d(TAG, "Message sent: ${message.type}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send message", e)
        }
    }
    
    /**
     * Send heartbeat message to maintain connection.
     */
    fun sendHeartbeat() {
        val heartbeat = WebSocketMessage(
            type = MessageType.HEARTBEAT,
            data = mapOf(
                "timestamp" to System.currentTimeMillis(),
                "displayId" to preferencesManager.getDisplayId()
            )
        )
        sendMessage(heartbeat)
    }
    
    private fun sendAuthenticationMessage() {
        val displayId = preferencesManager.getDisplayId() ?: return
        val accessToken = preferencesManager.getAccessToken() ?: return
        
        val authMessage = WebSocketMessage(
            type = MessageType.AUTHENTICATE,
            data = mapOf(
                "displayId" to displayId,
                "token" to accessToken,
                "clientType" to "android-tv"
            )
        )
        sendMessage(authMessage)
    }
    
    private fun handleTextMessage(text: String) {
        try {
            val message = gson.fromJson(text, WebSocketMessage::class.java)
            coroutineScope.launch {
                _messages.send(message)
            }
        } catch (e: JsonSyntaxException) {
            Log.e(TAG, "Failed to parse WebSocket message: $text", e)
        }
    }
    
    private fun handleBinaryMessage(bytes: ByteString) {
        // Handle binary messages if needed (e.g., compressed data)
        Log.d(TAG, "Binary message handling not implemented")
    }
    
    private fun scheduleReconnect() {
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            Log.e(TAG, "Max reconnection attempts reached")
            _connectionState.value = ConnectionState.ERROR
            return
        }
        
        reconnectAttempts++
        val delay = RECONNECT_INTERVAL_MS * reconnectAttempts
        
        Log.d(TAG, "Scheduling reconnection attempt $reconnectAttempts in ${delay}ms")
        
        coroutineScope.launch {
            delay(delay)
            if (!isManualDisconnect) {
                connect()
            }
        }
    }
    
    private fun buildWebSocketUrl(): String {
        val serverUrl = preferencesManager.getServerUrl() ?: "wss://api.displaydeck.com"
        val baseUrl = serverUrl.replace("http://", "ws://").replace("https://", "wss://")
        return "$baseUrl/ws/displays/"
    }
    
    /**
     * Clean up resources.
     */
    fun cleanup() {
        isManualDisconnect = true
        webSocket?.close(1000, "Cleanup")
        coroutineScope.cancel()
    }
}

/**
 * WebSocket connection states.
 */
enum class ConnectionState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    DISCONNECTING,
    ERROR
}

/**
 * WebSocket message types.
 */
object MessageType {
    const val AUTHENTICATE = "authenticate"
    const val AUTHENTICATED = "authenticated"
    const val HEARTBEAT = "heartbeat"
    const val HEARTBEAT_RESPONSE = "heartbeat_response"
    const val MENU_UPDATE = "menu_update"
    const val BUSINESS_UPDATE = "business_update"
    const val DISPLAY_COMMAND = "display_command"
    const val SETTINGS_UPDATE = "settings_update"
    const val STATUS_REQUEST = "status_request"
    const val ERROR = "error"
    const val SYNC_REQUEST = "sync_request"
}

/**
 * WebSocket message structure.
 */
data class WebSocketMessage(
    val type: String,
    val data: Map<String, Any>? = null,
    val timestamp: Long = System.currentTimeMillis(),
    val id: String? = null
)

/**
 * WebSocket message handler interface.
 */
interface WebSocketMessageHandler {
    suspend fun handleMessage(message: WebSocketMessage)
}

/**
 * Default message handler implementation.
 */
@Singleton
class DefaultWebSocketMessageHandler @Inject constructor(
    private val preferencesManager: PreferencesManager
) : WebSocketMessageHandler {
    
    companion object {
        private const val TAG = "WebSocketMessageHandler"
    }
    
    override suspend fun handleMessage(message: WebSocketMessage) {
        Log.d(TAG, "Handling message: ${message.type}")
        
        when (message.type) {
            MessageType.AUTHENTICATED -> {
                Log.d(TAG, "WebSocket authentication successful")
            }
            
            MessageType.HEARTBEAT_RESPONSE -> {
                Log.d(TAG, "Heartbeat response received")
            }
            
            MessageType.MENU_UPDATE -> {
                handleMenuUpdate(message)
            }
            
            MessageType.BUSINESS_UPDATE -> {
                handleBusinessUpdate(message)
            }
            
            MessageType.DISPLAY_COMMAND -> {
                handleDisplayCommand(message)
            }
            
            MessageType.SETTINGS_UPDATE -> {
                handleSettingsUpdate(message)
            }
            
            MessageType.STATUS_REQUEST -> {
                handleStatusRequest(message)
            }
            
            MessageType.ERROR -> {
                handleError(message)
            }
            
            MessageType.SYNC_REQUEST -> {
                handleSyncRequest(message)
            }
            
            else -> {
                Log.w(TAG, "Unknown message type: ${message.type}")
            }
        }
    }
    
    private suspend fun handleMenuUpdate(message: WebSocketMessage) {
        val data = message.data ?: return
        val menuId = (data["menuId"] as? Number)?.toLong()
        val version = (data["version"] as? Number)?.toInt()
        
        Log.d(TAG, "Menu update: menuId=$menuId, version=$version")
        
        // Trigger menu sync
        // This would typically notify a service or repository to fetch the updated menu
    }
    
    private suspend fun handleBusinessUpdate(message: WebSocketMessage) {
        val data = message.data ?: return
        val businessId = (data["businessId"] as? Number)?.toLong()
        
        Log.d(TAG, "Business update: businessId=$businessId")
        
        // Trigger business data sync
    }
    
    private suspend fun handleDisplayCommand(message: WebSocketMessage) {
        val data = message.data ?: return
        val command = data["command"] as? String
        val parameters = data["parameters"] as? Map<*, *>
        
        Log.d(TAG, "Display command: $command")
        
        when (command) {
            "restart" -> {
                // Handle restart command
                Log.d(TAG, "Restart command received")
            }
            
            "refresh_menu" -> {
                // Handle refresh menu command
                Log.d(TAG, "Refresh menu command received")
            }
            
            "update_settings" -> {
                // Handle update settings command
                Log.d(TAG, "Update settings command received")
            }
            
            else -> {
                Log.w(TAG, "Unknown command: $command")
            }
        }
    }
    
    private suspend fun handleSettingsUpdate(message: WebSocketMessage) {
        val data = message.data ?: return
        
        Log.d(TAG, "Settings update received")
        
        // Update local settings based on server changes
    }
    
    private suspend fun handleStatusRequest(message: WebSocketMessage) {
        Log.d(TAG, "Status request received")
        
        // Respond with current display status
        // This would typically be handled by a service
    }
    
    private suspend fun handleError(message: WebSocketMessage) {
        val data = message.data ?: return
        val errorCode = data["code"] as? String
        val errorMessage = data["message"] as? String
        
        Log.e(TAG, "WebSocket error: $errorCode - $errorMessage")
    }
    
    private suspend fun handleSyncRequest(message: WebSocketMessage) {
        val data = message.data ?: return
        val entityType = data["entityType"] as? String
        val entityId = data["entityId"] as? String
        
        Log.d(TAG, "Sync request: $entityType/$entityId")
        
        // Trigger specific entity sync
    }
}