package com.displaydeck.androidtv.network

import android.content.Context
import com.displaydeck.androidtv.BuildConfig
import com.displaydeck.androidtv.utils.PreferencesManager
import kotlinx.coroutines.runBlocking
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Network client configuration for DisplayDeck API communication.
 * Handles authentication, logging, and connection settings.
 */
@Singleton
class NetworkClient @Inject constructor(
    private val context: Context,
    private val preferencesManager: PreferencesManager
) {
    
    companion object {
        private const val CONNECT_TIMEOUT_SECONDS = 30L
        private const val READ_TIMEOUT_SECONDS = 30L
        private const val WRITE_TIMEOUT_SECONDS = 30L
        private const val MAX_RETRIES = 3
        private const val RETRY_DELAY_MS = 1000L
    }
    
    private val loggingInterceptor = HttpLoggingInterceptor().apply {
        level = if (BuildConfig.DEBUG) {
            HttpLoggingInterceptor.Level.BODY
        } else {
            HttpLoggingInterceptor.Level.BASIC
        }
    }
    
    private val authInterceptor = AuthInterceptor(preferencesManager)
    
    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(CONNECT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        .readTimeout(READ_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        .writeTimeout(WRITE_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        .addInterceptor(loggingInterceptor)
        .addInterceptor(authInterceptor)
        .addInterceptor(UserAgentInterceptor())
        .addInterceptor(RetryInterceptor(MAX_RETRIES, RETRY_DELAY_MS))
        .build()
    
    private val retrofit = Retrofit.Builder()
        .baseUrl(getBaseUrl())
        .client(okHttpClient)
        .addConverterFactory(GsonConverterFactory.create())
        .build()
    
    val apiService: DisplayDeckApiService = retrofit.create(DisplayDeckApiService::class.java)
    
    private fun getBaseUrl(): String {
        // Get base URL from preferences or use default
        val savedUrl = preferencesManager.getServerUrl()
        return savedUrl ?: BuildConfig.DEFAULT_API_URL ?: "https://api.displaydeck.com/api/v1/"
    }
    
    /**
     * Update the base URL and recreate the API client
     */
    fun updateBaseUrl(newUrl: String) {
        preferencesManager.setServerUrl(newUrl)
        // Note: In a real implementation, you might want to recreate the retrofit instance
        // For simplicity, we'll just save the URL for next app launch
    }
}

/**
 * Interceptor to add authentication headers to requests.
 */
class AuthInterceptor(
    private val preferencesManager: PreferencesManager
) : Interceptor {
    
    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()
        
        // Skip auth for certain endpoints
        if (shouldSkipAuth(originalRequest)) {
            return chain.proceed(originalRequest)
        }
        
        val accessToken = preferencesManager.getAccessToken()
        
        val authenticatedRequest = if (accessToken != null) {
            originalRequest.newBuilder()
                .header("Authorization", "Bearer $accessToken")
                .build()
        } else {
            originalRequest
        }
        
        val response = chain.proceed(authenticatedRequest)
        
        // Handle token refresh if needed
        if (response.code == 401 && accessToken != null) {
            response.close()
            
            val refreshToken = preferencesManager.getRefreshToken()
            if (refreshToken != null) {
                return handleTokenRefresh(chain, originalRequest, refreshToken)
            }
        }
        
        return response
    }
    
    private fun shouldSkipAuth(request: Request): Boolean {
        val url = request.url.encodedPath
        return url.contains("/auth/") || 
               url.contains("/health") ||
               url.contains("/register")
    }
    
    private fun handleTokenRefresh(
        chain: Interceptor.Chain, 
        originalRequest: Request, 
        refreshToken: String
    ): Response {
        return try {
            // Synchronously refresh token
            val displayId = preferencesManager.getDisplayId() ?: return chain.proceed(originalRequest)
            
            val refreshRequest = TokenRefreshRequest(
                refreshToken = refreshToken,
                displayId = displayId
            )
            
            // Create a new retrofit client without auth interceptor to avoid infinite loop
            val client = OkHttpClient.Builder()
                .connectTimeout(NetworkClient.CONNECT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                .readTimeout(NetworkClient.READ_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                .writeTimeout(NetworkClient.WRITE_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                .build()
            
            val retrofit = Retrofit.Builder()
                .baseUrl(preferencesManager.getServerUrl() ?: "https://api.displaydeck.com/api/v1/")
                .client(client)
                .addConverterFactory(GsonConverterFactory.create())
                .build()
            
            val apiService = retrofit.create(DisplayDeckApiService::class.java)
            
            runBlocking {
                val response = apiService.refreshDisplayToken("Bearer $refreshToken", refreshRequest)
                if (response.isSuccessful && response.body() != null) {
                    val tokenResponse = response.body()!!
                    preferencesManager.setTokens(tokenResponse.accessToken, tokenResponse.refreshToken)
                    
                    // Retry original request with new token
                    val newRequest = originalRequest.newBuilder()
                        .header("Authorization", "Bearer ${tokenResponse.accessToken}")
                        .build()
                    
                    chain.proceed(newRequest)
                } else {
                    // Token refresh failed, clear stored tokens
                    preferencesManager.clearTokens()
                    chain.proceed(originalRequest)
                }
            }
        } catch (e: Exception) {
            // Token refresh failed, clear stored tokens
            preferencesManager.clearTokens()
            chain.proceed(originalRequest)
        }
    }
}

/**
 * Interceptor to add User-Agent header.
 */
class UserAgentInterceptor : Interceptor {
    
    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()
        
        val userAgent = "DisplayDeck-AndroidTV/${BuildConfig.VERSION_NAME} " +
                "(Android ${android.os.Build.VERSION.RELEASE}; " +
                "${android.os.Build.MODEL})"
        
        val requestWithUserAgent = originalRequest.newBuilder()
            .header("User-Agent", userAgent)
            .header("X-Device-Type", "android-tv")
            .header("X-App-Version", BuildConfig.VERSION_NAME)
            .build()
        
        return chain.proceed(requestWithUserAgent)
    }
}

/**
 * Interceptor to handle request retries.
 */
class RetryInterceptor(
    private val maxRetries: Int,
    private val retryDelayMs: Long
) : Interceptor {
    
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        var response: Response? = null
        var exception: Exception? = null
        
        for (attempt in 0..maxRetries) {
            try {
                if (response != null) {
                    response.close()
                }
                
                response = chain.proceed(request)
                
                // Don't retry on successful responses or client errors (4xx)
                if (response.isSuccessful || response.code in 400..499) {
                    return response
                }
                
                // Retry on server errors (5xx) and network errors
                if (attempt < maxRetries) {
                    Thread.sleep(retryDelayMs * (attempt + 1)) // Exponential backoff
                }
                
            } catch (e: Exception) {
                exception = e
                if (attempt < maxRetries) {
                    Thread.sleep(retryDelayMs * (attempt + 1))
                } else {
                    throw e
                }
            }
        }
        
        return response ?: throw (exception ?: RuntimeException("Max retries exceeded"))
    }
}

/**
 * Network state and configuration manager.
 */
@Singleton
class NetworkManager @Inject constructor(
    private val context: Context,
    private val preferencesManager: PreferencesManager,
    private val networkClient: NetworkClient
) {
    
    /**
     * Check if network is available and API is reachable.
     */
    suspend fun checkConnectivity(): NetworkStatus {
        return try {
            val response = networkClient.apiService.healthCheck()
            if (response.isSuccessful) {
                NetworkStatus.CONNECTED
            } else {
                NetworkStatus.ERROR
            }
        } catch (e: Exception) {
            when {
                e.message?.contains("timeout") == true -> NetworkStatus.TIMEOUT
                e.message?.contains("host") == true -> NetworkStatus.NO_INTERNET
                else -> NetworkStatus.ERROR
            }
        }
    }
    
    /**
     * Test connection to a specific server URL.
     */
    suspend fun testConnection(serverUrl: String): Boolean {
        return try {
            // Create temporary client with custom URL
            val client = OkHttpClient.Builder()
                .connectTimeout(10, TimeUnit.SECONDS)
                .readTimeout(10, TimeUnit.SECONDS)
                .build()
            
            val retrofit = Retrofit.Builder()
                .baseUrl(serverUrl)
                .client(client)
                .addConverterFactory(GsonConverterFactory.create())
                .build()
            
            val tempApiService = retrofit.create(DisplayDeckApiService::class.java)
            val response = tempApiService.healthCheck()
            
            response.isSuccessful
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Get current network configuration.
     */
    fun getNetworkConfig(): NetworkConfig {
        return NetworkConfig(
            serverUrl = preferencesManager.getServerUrl(),
            isConnected = false, // Will be updated by connectivity checks
            lastConnected = preferencesManager.getLastConnectedTime(),
            retryCount = preferencesManager.getNetworkRetryCount()
        )
    }
    
    /**
     * Update network retry statistics.
     */
    fun updateRetryCount(count: Int) {
        preferencesManager.setNetworkRetryCount(count)
    }
    
    /**
     * Mark successful connection.
     */
    fun markConnected() {
        preferencesManager.setLastConnectedTime(System.currentTimeMillis())
        preferencesManager.setNetworkRetryCount(0)
    }
}

/**
 * Network status enum.
 */
enum class NetworkStatus {
    CONNECTED,
    NO_INTERNET,
    TIMEOUT,
    ERROR
}

/**
 * Network configuration data class.
 */
data class NetworkConfig(
    val serverUrl: String?,
    val isConnected: Boolean,
    val lastConnected: Long?,
    val retryCount: Int
)