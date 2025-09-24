package com.displaydeck.androidtv.workers

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.*
import com.displaydeck.androidtv.data.cache.CacheRepository
import com.displaydeck.androidtv.data.cache.entities.*
import com.displaydeck.androidtv.network.NetworkClient
import com.displaydeck.androidtv.utils.PreferencesManager
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

/**
 * Background worker for synchronizing menu data with the backend server.
 * Handles periodic sync, cache management, and offline data persistence.
 */
@HiltWorker
class MenuSyncWorker @AssistedInject constructor(
    @Assisted private val context: Context,
    @Assisted private val workerParams: WorkerParameters,
    private val cacheRepository: CacheRepository,
    private val networkClient: NetworkClient,
    private val preferencesManager: PreferencesManager
) : CoroutineWorker(context, workerParams) {
    
    companion object {
        const val TAG = "MenuSyncWorker"
        const val WORK_NAME = "menu_sync_work"
        
        // Input parameters
        const val PARAM_FORCE_SYNC = "force_sync"
        const val PARAM_MENU_ID = "menu_id"
        const val PARAM_BUSINESS_ID = "business_id"
        
        // Output data keys
        const val OUTPUT_SYNC_RESULT = "sync_result"
        const val OUTPUT_UPDATED_MENUS = "updated_menus"
        const val OUTPUT_ERROR_MESSAGE = "error_message"
        
        /**
         * Schedule periodic menu synchronization.
         */
        fun schedulePeriodicSync(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .setRequiresBatteryNotLow(true)
                .build()
            
            val periodicWorkRequest = PeriodicWorkRequestBuilder<MenuSyncWorker>(
                15, TimeUnit.MINUTES, // Repeat interval
                5, TimeUnit.MINUTES   // Flex interval
            )
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    WorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .addTag(TAG)
                .build()
            
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    periodicWorkRequest
                )
        }
        
        /**
         * Schedule one-time menu sync.
         */
        fun scheduleOneTimeSync(
            context: Context,
            forceSync: Boolean = false,
            menuId: Long? = null,
            businessId: Long? = null
        ) {
            val inputData = Data.Builder()
                .putBoolean(PARAM_FORCE_SYNC, forceSync)
                .apply {
                    menuId?.let { putLong(PARAM_MENU_ID, it) }
                    businessId?.let { putLong(PARAM_BUSINESS_ID, it) }
                }
                .build()
            
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            
            val oneTimeWorkRequest = OneTimeWorkRequestBuilder<MenuSyncWorker>()
                .setConstraints(constraints)
                .setInputData(inputData)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    WorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .addTag(TAG)
                .build()
            
            WorkManager.getInstance(context)
                .enqueueUniqueWork(
                    "menu_sync_${System.currentTimeMillis()}",
                    ExistingWorkPolicy.REPLACE,
                    oneTimeWorkRequest
                )
        }
        
        /**
         * Cancel all menu sync work.
         */
        fun cancelAllSync(context: Context) {
            WorkManager.getInstance(context).cancelAllWorkByTag(TAG)
        }
    }
    
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        Log.d(TAG, "Starting menu synchronization")
        
        try {
            val displayId = preferencesManager.getDisplayId()
            val accessToken = preferencesManager.getAccessToken()
            
            if (displayId == null || accessToken == null) {
                Log.e(TAG, "Cannot sync: missing display ID or access token")
                return@withContext Result.failure(
                    Data.Builder()
                        .putString(OUTPUT_ERROR_MESSAGE, "Authentication required")
                        .build()
                )
            }
            
            val forceSync = inputData.getBoolean(PARAM_FORCE_SYNC, false)
            val specificMenuId = if (inputData.getLong(PARAM_MENU_ID, -1) != -1L) {
                inputData.getLong(PARAM_MENU_ID, -1)
            } else null
            
            val syncResult = when {
                specificMenuId != null -> syncSpecificMenu(displayId, specificMenuId, forceSync)
                else -> syncAllMenus(displayId, forceSync)
            }
            
            when (syncResult) {
                is SyncResult.Success -> {
                    Log.d(TAG, "Menu sync completed successfully")
                    Result.success(
                        Data.Builder()
                            .putString(OUTPUT_SYNC_RESULT, "success")
                            .putInt(OUTPUT_UPDATED_MENUS, syncResult.updatedCount)
                            .build()
                    )
                }
                is SyncResult.PartialSuccess -> {
                    Log.w(TAG, "Menu sync partially successful: ${syncResult.errors}")
                    Result.success(
                        Data.Builder()
                            .putString(OUTPUT_SYNC_RESULT, "partial")
                            .putInt(OUTPUT_UPDATED_MENUS, syncResult.updatedCount)
                            .putString(OUTPUT_ERROR_MESSAGE, syncResult.errors.joinToString(", "))
                            .build()
                    )
                }
                is SyncResult.Failure -> {
                    Log.e(TAG, "Menu sync failed: ${syncResult.error}")
                    Result.retry()
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error during menu sync", e)
            Result.failure(
                Data.Builder()
                    .putString(OUTPUT_ERROR_MESSAGE, e.message ?: "Unknown error")
                    .build()
            )
        }
    }
    
    private suspend fun syncAllMenus(displayId: String, forceSync: Boolean): SyncResult {
        val updatedMenus = mutableListOf<Long>()
        val errors = mutableListOf<String>()
        
        try {
            // Get current display menu assignment
            val response = networkClient.apiService.getDisplayMenu(displayId, "Bearer ${preferencesManager.getAccessToken()}")
            
            if (response.isSuccessful && response.body() != null) {
                val menuResponse = response.body()!!
                val syncSuccess = syncMenuFromResponse(menuResponse, forceSync)
                
                if (syncSuccess) {
                    updatedMenus.add(menuResponse.menu.id)
                } else {
                    errors.add("Failed to sync menu ${menuResponse.menu.id}")
                }
                
                // Also sync business data
                syncBusinessFromResponse(menuResponse.business)
            } else {
                errors.add("Failed to fetch display menu: ${response.code()}")
            }
        } catch (e: Exception) {
            return SyncResult.Failure("Network error: ${e.message}")
        }
        
        return when {
            errors.isEmpty() -> SyncResult.Success(updatedMenus.size)
            updatedMenus.isNotEmpty() -> SyncResult.PartialSuccess(updatedMenus.size, errors)
            else -> SyncResult.Failure(errors.first())
        }
    }
    
    private suspend fun syncSpecificMenu(displayId: String, menuId: Long, forceSync: Boolean): SyncResult {
        return try {
            // Check if menu needs updating
            if (!forceSync) {
                val checkResponse = networkClient.apiService.checkMenuUpdates(
                    displayId, 
                    "Bearer ${preferencesManager.getAccessToken()}", 
                    getCurrentMenuVersion(menuId)
                )
                
                if (checkResponse.isSuccessful && checkResponse.body()?.hasUpdates == false) {
                    return SyncResult.Success(0) // No updates needed
                }
            }
            
            // Fetch updated menu
            val response = networkClient.apiService.getDisplayMenu(displayId, "Bearer ${preferencesManager.getAccessToken()}")
            
            if (response.isSuccessful && response.body() != null) {
                val menuResponse = response.body()!!
                
                if (menuResponse.menu.id == menuId) {
                    val success = syncMenuFromResponse(menuResponse, true)
                    if (success) {
                        SyncResult.Success(1)
                    } else {
                        SyncResult.Failure("Failed to process menu data")
                    }
                } else {
                    SyncResult.Failure("Requested menu not assigned to display")
                }
            } else {
                SyncResult.Failure("Failed to fetch menu: ${response.code()}")
            }
        } catch (e: Exception) {
            SyncResult.Failure("Network error: ${e.message}")
        }
    }
    
    private suspend fun syncMenuFromResponse(menuResponse: com.displaydeck.androidtv.network.MenuResponse, forceUpdate: Boolean): Boolean {
        return try {
            // Convert API response to cache entities
            val cachedMenu = CachedMenu(
                id = menuResponse.menu.id,
                businessId = menuResponse.business.id,
                displayId = preferencesManager.getDisplayId()?.toLongOrNull(),
                name = menuResponse.menu.name,
                description = menuResponse.menu.description,
                isActive = menuResponse.menu.isActive,
                updatedAt = System.currentTimeMillis(),
                version = menuResponse.version
            )
            
            val cachedCategories = menuResponse.menu.categories.map { category ->
                CachedMenuCategory(
                    id = category.id,
                    menuId = menuResponse.menu.id,
                    name = category.name,
                    description = category.description,
                    displayOrder = category.displayOrder,
                    isActive = category.isActive,
                    updatedAt = System.currentTimeMillis()
                )
            }
            
            val cachedItems = menuResponse.menu.categories.flatMap { category ->
                category.items.map { item ->
                    CachedMenuItem(
                        id = item.id,
                        menuId = menuResponse.menu.id,
                        categoryId = category.id,
                        name = item.name,
                        description = item.description,
                        price = item.price,
                        imageUrl = item.imageUrl,
                        isAvailable = item.isAvailable,
                        displayOrder = item.displayOrder,
                        allergens = item.allergens,
                        nutritionInfo = item.nutritionInfo?.let { nutrition ->
                            NutritionInfo(
                                calories = nutrition.calories,
                                protein = nutrition.protein,
                                carbs = nutrition.carbs,
                                fat = nutrition.fat,
                                fiber = nutrition.fiber,
                                sodium = nutrition.sodium
                            )
                        },
                        tags = item.tags,
                        updatedAt = System.currentTimeMillis()
                    )
                }
            }
            
            // Save to cache
            cacheRepository.syncMenuData(cachedMenu, cachedCategories, cachedItems)
            
            // Update sync status
            cacheRepository.syncDao.recordSyncAttempt("menu", menuResponse.menu.id.toString(), true)
            
            Log.d(TAG, "Successfully synced menu ${menuResponse.menu.id}")
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to sync menu data", e)
            
            // Record sync failure
            cacheRepository.syncDao.recordSyncAttempt("menu", menuResponse.menu.id.toString(), false, e.message)
            false
        }
    }
    
    private suspend fun syncBusinessFromResponse(businessData: com.displaydeck.androidtv.network.BusinessData): Boolean {
        return try {
            val cachedBusiness = CachedBusiness(
                id = businessData.id,
                name = businessData.name,
                description = businessData.description,
                address = businessData.address,
                businessType = businessData.businessType,
                logoUrl = businessData.logoUrl,
                themeColor = businessData.themeColor,
                operatingHours = businessData.operatingHours,
                contactInfo = businessData.contactInfo,
                isActive = true,
                updatedAt = System.currentTimeMillis()
            )
            
            cacheRepository.syncBusinessData(cachedBusiness)
            
            Log.d(TAG, "Successfully synced business ${businessData.id}")
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to sync business data", e)
            cacheRepository.syncDao.recordSyncAttempt("business", businessData.id.toString(), false, e.message)
            false
        }
    }
    
    private suspend fun getCurrentMenuVersion(menuId: Long): Int {
        return try {
            val cachedMenu = cacheRepository.menuDao.getMenuById(menuId)
            cachedMenu?.version ?: 1
        } catch (e: Exception) {
            1 // Default version if unable to get current version
        }
    }
}

/**
 * Sync result sealed class.
 */
sealed class SyncResult {
    data class Success(val updatedCount: Int) : SyncResult()
    data class PartialSuccess(val updatedCount: Int, val errors: List<String>) : SyncResult()
    data class Failure(val error: String) : SyncResult()
}