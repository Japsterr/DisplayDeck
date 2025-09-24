package com.displaydeck.androidtv.data.network

import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString
import org.java_websocket.client.WebSocketClient
import org.java_websocket.handshake.ServerHandshake
import java.net.URI
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import android.util.Log

/**
 * WebSocket client for real-time communication with DisplayDeck backend
 */
@Singleton
class WebSocketService @Inject constructor() {
    
    private var webSocketClient: WebSocketClient? = null
    private val json = Json { ignoreUnknownKeys = true }
    
    // Connection state
    private val _connectionState = MutableStateFlow(WebSocketState.DISCONNECTED)
    val connectionState: StateFlow<WebSocketState> = _connectionState.asStateFlow()
    
    // Incoming messages
    private val _incomingMessages = MutableStateFlow<WebSocketMessage?>(null)
    val incomingMessages: StateFlow<WebSocketMessage?> = _incomingMessages.asStateFlow()
    
    // Menu update messages
    private val _menuUpdates = MutableStateFlow<MenuUpdateMessage?>(null)
    val menuUpdates: StateFlow<MenuUpdateMessage?> = _menuUpdates.asStateFlow()
    
    // Display assignment messages
    private val _displayAssignments = MutableStateFlow<DisplayAssignmentMessage?>(null)
    val displayAssignments: StateFlow<DisplayAssignmentMessage?> = _displayAssignments.asStateFlow()
    
    companion object {
        private const val TAG = "WebSocketService"
        private const val RECONNECT_DELAY_MS = 5000L
        private const val MAX_RECONNECT_ATTEMPTS = 10
    }
    
    private var reconnectAttempts = 0
    private var serverUri: URI? = null
    private var authToken: String? = null
    private var displayId: Int? = null
    
    /**
     * Connect to WebSocket server
     */
    fun connect(serverUrl: String, token: String, displayId: Int) {
        try {
            this.authToken = token
            this.displayId = displayId
            
            // Build WebSocket URL with authentication
            val wsUrl = serverUrl.replace("http", "ws") + "/ws/displays/$displayId/?token=$token"
            serverUri = URI.create(wsUrl)
            
            disconnect() // Close existing connection if any
            
            webSocketClient = object : WebSocketClient(serverUri) {
                override fun onOpen(handshake: ServerHandshake?) {
                    Log.i(TAG, "WebSocket connected")
                    _connectionState.value = WebSocketState.CONNECTED
                    reconnectAttempts = 0
                    
                    // Send initial connection message
                    sendConnectionMessage()
                }
                
                override fun onMessage(message: String?) {
                    Log.d(TAG, "WebSocket message received: $message")
                    message?.let { handleIncomingMessage(it) }
                }
                
                override fun onClose(code: Int, reason: String?, remote: Boolean) {
                    Log.w(TAG, "WebSocket closed: $code - $reason (remote: $remote)")
                    _connectionState.value = WebSocketState.DISCONNECTED
                    
                    // Attempt reconnection if not manually closed
                    if (remote && reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
                        scheduleReconnect()
                    }
                }
                
                override fun onError(ex: Exception?) {
                    Log.e(TAG, "WebSocket error", ex)
                    _connectionState.value = WebSocketState.ERROR
                    
                    // Attempt reconnection on error
                    if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
                        scheduleReconnect()
                    }
                }
            }
            
            _connectionState.value = WebSocketState.CONNECTING
            webSocketClient?.connect()
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to connect WebSocket", e)
            _connectionState.value = WebSocketState.ERROR
        }
    }
    
    /**
     * Disconnect from WebSocket server
     */
    fun disconnect() {
        webSocketClient?.close()
        webSocketClient = null
        _connectionState.value = WebSocketState.DISCONNECTED
        reconnectAttempts = MAX_RECONNECT_ATTEMPTS // Prevent reconnection
    }
    
    /**
     * Send message to server
     */
    fun sendMessage(message: WebSocketMessage) {
        try {
            val jsonMessage = json.encodeToString(message)
            webSocketClient?.send(jsonMessage)
            Log.d(TAG, "WebSocket message sent: $jsonMessage")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send WebSocket message", e)
        }
    }
    
    /**
     * Send heartbeat to maintain connection
     */
    fun sendHeartbeat() {
        val heartbeatMessage = WebSocketMessage(
            type = "heartbeat",
            data = mapOf(
                "display_id" to (displayId ?: 0),
                "timestamp" to System.currentTimeMillis()
            )
        )
        sendMessage(heartbeatMessage)
    }
    
    /**
     * Handle incoming WebSocket messages
     */
    private fun handleIncomingMessage(message: String) {
        try {
            val wsMessage = json.decodeFromString<WebSocketMessage>(message)
            _incomingMessages.value = wsMessage
            
            // Handle specific message types
            when (wsMessage.type) {
                "menu_update" -> {
                    wsMessage.data?.let { data ->
                        try {
                            val menuUpdate = json.decodeFromString<MenuUpdateMessage>(
                                json.encodeToString(data)
                            )
                            _menuUpdates.value = menuUpdate
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to parse menu update message", e)
                        }
                    }
                }
                
                "display_assignment" -> {
                    wsMessage.data?.let { data ->
                        try {
                            val assignment = json.decodeFromString<DisplayAssignmentMessage>(
                                json.encodeToString(data)
                            )
                            _displayAssignments.value = assignment
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to parse display assignment message", e)
                        }
                    }
                }
                
                "ping" -> {
                    // Respond to server ping with pong
                    sendMessage(WebSocketMessage(type = "pong"))
                }
                
                "error" -> {
                    wsMessage.data?.get("message")?.let { errorMessage ->
                        Log.e(TAG, "Server error: $errorMessage")
                    }
                }
                
                else -> {
                    Log.d(TAG, "Unknown message type: ${wsMessage.type}")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse WebSocket message: $message", e)
        }
    }
    
    /**
     * Send initial connection message
     */
    private fun sendConnectionMessage() {
        val connectionMessage = WebSocketMessage(
            type = "connect",
            data = mapOf(
                "display_id" to (displayId ?: 0),
                "client_type" to "android_tv",
                "version" to "1.0.0"
            )
        )
        sendMessage(connectionMessage)
    }
    
    /**
     * Schedule reconnection attempt
     */
    private fun scheduleReconnect() {
        reconnectAttempts++
        _connectionState.value = WebSocketState.RECONNECTING
        
        Log.i(TAG, "Scheduling reconnect attempt $reconnectAttempts/$MAX_RECONNECT_ATTEMPTS")
        
        // Use a simple delay mechanism (in production, use proper scheduling)
        Thread {
            Thread.sleep(RECONNECT_DELAY_MS)
            
            if (reconnectAttempts <= MAX_RECONNECT_ATTEMPTS && 
                _connectionState.value == WebSocketState.RECONNECTING) {
                
                serverUri?.let { uri ->
                    authToken?.let { token ->
                        displayId?.let { id ->
                            connect(uri.toString().replace("/ws/displays/$id/?token=$token", ""), token, id)
                        }
                    }
                }
            }
        }.start()
    }
    
    /**
     * Check if WebSocket is connected
     */
    fun isConnected(): Boolean {
        return _connectionState.value == WebSocketState.CONNECTED
    }
    
    /**
     * Get current connection state
     */
    fun getCurrentConnectionState(): WebSocketState {
        return _connectionState.value
    }
}

enum class WebSocketState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    RECONNECTING,
    ERROR
}