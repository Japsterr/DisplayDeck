package com.displaydeck.androidtv.data.network

import retrofit2.Response
import retrofit2.http.*

interface ApiService {
    
    // Authentication endpoints
    @POST("auth/login/")
    suspend fun login(@Body request: LoginRequest): Response<TokenResponse>
    
    @POST("auth/refresh/")
    suspend fun refreshToken(@Body refreshToken: Map<String, String>): Response<TokenResponse>
    
    @POST("auth/logout/")
    suspend fun logout(): Response<Unit>
    
    // Display pairing endpoints
    @POST("displays/pair/")
    suspend fun pairDisplay(@Body request: DisplayPairRequest): Response<DisplayPairResponse>
    
    @GET("displays/{displayId}/")
    suspend fun getDisplay(@Path("displayId") displayId: Int): Response<DisplayDto>
    
    @PATCH("displays/{displayId}/")
    suspend fun updateDisplay(
        @Path("displayId") displayId: Int,
        @Body request: DisplayUpdateRequest
    ): Response<DisplayDto>
    
    @POST("displays/{displayId}/heartbeat/")
    suspend fun sendHeartbeat(@Path("displayId") displayId: Int): Response<Unit>
    
    // Business endpoints
    @GET("businesses/{businessId}/")
    suspend fun getBusiness(@Path("businessId") businessId: Int): Response<BusinessDto>
    
    @GET("businesses/")
    suspend fun getBusinesses(): Response<List<BusinessDto>>
    
    // Menu endpoints
    @GET("menus/{menuId}/")
    suspend fun getMenu(@Path("menuId") menuId: Int): Response<MenuDto>
    
    @GET("businesses/{businessId}/menus/")
    suspend fun getBusinessMenus(@Path("businessId") businessId: Int): Response<List<MenuDto>>
    
    @GET("businesses/{businessId}/menus/active/")
    suspend fun getActiveBusinessMenus(@Path("businessId") businessId: Int): Response<List<MenuDto>>
    
    // Menu category endpoints
    @GET("menus/{menuId}/categories/")
    suspend fun getMenuCategories(@Path("menuId") menuId: Int): Response<List<MenuCategoryDto>>
    
    // Menu item endpoints
    @GET("categories/{categoryId}/items/")
    suspend fun getCategoryItems(@Path("categoryId") categoryId: Int): Response<List<MenuItemDto>>
    
    // Health check endpoint
    @GET("health/")
    suspend fun healthCheck(): Response<Map<String, String>>
    
    // Version check endpoint
    @GET("version/")
    suspend fun getVersion(): Response<Map<String, String>>
}

interface AuthenticatedApiService : ApiService {
    // All endpoints here will automatically include authentication headers
}

// Extension functions for easier API response handling
suspend inline fun <T> safeApiCall(
    apiCall: suspend () -> Response<T>
): ApiResult<T> {
    return try {
        val response = apiCall()
        if (response.isSuccessful) {
            response.body()?.let { body ->
                ApiResult.Success(body)
            } ?: ApiResult.Error("Empty response body", response.code())
        } else {
            val errorBody = response.errorBody()?.string()
            ApiResult.Error(errorBody ?: "Unknown error", response.code())
        }
    } catch (e: Exception) {
        ApiResult.Error(e.message ?: "Network error", null)
    }
}

sealed class ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>()
    data class Error(val message: String, val code: Int? = null) : ApiResult<Nothing>()
    data class Loading(val isLoading: Boolean = true) : ApiResult<Nothing>()
}

// Extension function to convert ApiResult to nullable data
fun <T> ApiResult<T>.getDataOrNull(): T? {
    return when (this) {
        is ApiResult.Success -> data
        else -> null
    }
}

// Extension function to check if result is successful
fun <T> ApiResult<T>.isSuccess(): Boolean {
    return this is ApiResult.Success
}

// Extension function to check if result is error
fun <T> ApiResult<T>.isError(): Boolean {
    return this is ApiResult.Error
}