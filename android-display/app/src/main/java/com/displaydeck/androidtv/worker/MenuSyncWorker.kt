package com.displaydeck.androidtv.worker

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.*
import com.displaydeck.androidtv.data.cache.*
import com.displaydeck.androidtv.data.network.*
import com.displaydeck.androidtv.data.repository.*
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import android.util.Log
import java.util.concurrent.TimeUnit

/**
 * Background worker for syncing menu data with remote server
 */
@HiltWorker
class MenuSyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted workerParams: WorkerParameters,
    private val apiService: ApiService,
    private val menuCacheRepository: MenuCacheRepository,
    private val businessCacheRepository: BusinessCacheRepository,
    private val displaySettingsRepository: DisplaySettingsRepository
) : CoroutineWorker(context, workerParams) {

    companion object {
        private const val TAG = "MenuSyncWorker"
        const val WORK_NAME = "menu_sync_work"
        private const val RETRY_DELAY_SECONDS = 30L
    }

    override suspend fun doWork(): Result {
        return try {
            Log.i(TAG, "Starting menu sync")
            
            val displaySettings = displaySettingsRepository.getDisplaySettings()
            if (displaySettings?.isPaired != true) {
                Log.w(TAG, "Display not paired, skipping sync")
                return Result.success()
            }

            val businessId = displaySettings.assignedMenuId?.let { menuId ->
                menuCacheRepository.getMenu(menuId)?.businessId
            }

            if (businessId == null) {
                Log.w(TAG, "No business ID found, skipping sync")
                return Result.success()
            }

            // Sync business data
            syncBusiness(businessId)
            
            // Sync menu data
            syncMenusForBusiness(businessId)
            
            // Update last sync time
            displaySettingsRepository.updateLastSync()
            
            Log.i(TAG, "Menu sync completed successfully")
            Result.success()
            
        } catch (e: Exception) {
            Log.e(TAG, "Menu sync failed", e)
            
            if (runAttemptCount < 3) {
                Log.i(TAG, "Retrying menu sync (attempt ${runAttemptCount + 1}/3)")
                Result.retry()
            } else {
                Log.e(TAG, "Menu sync failed after 3 attempts")
                Result.failure()
            }
        }
    }

    private suspend fun syncBusiness(businessId: Int) {
        try {
            val result = safeApiCall { apiService.getBusiness(businessId) }
            
            when (result) {
                is ApiResult.Success -> {
                    val businessDto = result.data
                    val cachedBusiness = CachedBusiness(
                        id = businessDto.id,
                        name = businessDto.name,
                        description = businessDto.description,
                        logoUrl = businessDto.logo_url,
                        address = businessDto.address,
                        phone = businessDto.phone,
                        email = businessDto.email,
                        website = businessDto.website,
                        timezone = businessDto.timezone,
                        lastUpdated = System.currentTimeMillis(),
                        cachedAt = System.currentTimeMillis()
                    )
                    
                    businessCacheRepository.cacheBusiness(cachedBusiness)
                    Log.d(TAG, "Business synced: ${businessDto.name}")
                }
                
                is ApiResult.Error -> {
                    Log.e(TAG, "Failed to sync business: ${result.message}")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error syncing business", e)
            throw e
        }
    }

    private suspend fun syncMenusForBusiness(businessId: Int) {
        try {
            val result = safeApiCall { apiService.getActiveBusinessMenus(businessId) }
            
            when (result) {
                is ApiResult.Success -> {
                    val menuDtos = result.data
                    val cachedMenus = menuDtos.map { menuDto ->
                        convertMenuDtoToCachedMenu(menuDto)
                    }
                    
                    menuCacheRepository.cacheMenus(cachedMenus)
                    Log.d(TAG, "Synced ${cachedMenus.size} menus for business $businessId")
                }
                
                is ApiResult.Error -> {
                    Log.e(TAG, "Failed to sync menus: ${result.message}")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error syncing menus", e)
            throw e
        }
    }

    private suspend fun convertMenuDtoToCachedMenu(menuDto: MenuDto): CachedMenu {
        return CachedMenu(
            id = menuDto.id,
            businessId = menuDto.business_id,
            name = menuDto.name,
            description = menuDto.description,
            isActive = menuDto.is_active,
            displayOrder = menuDto.display_order,
            backgroundColor = menuDto.background_color,
            textColor = menuDto.text_color,
            fontFamily = menuDto.font_family,
            categories = menuDto.categories.map { categoryDto ->
                CachedMenuCategory(
                    id = categoryDto.id,
                    menuId = categoryDto.menu_id,
                    name = categoryDto.name,
                    description = categoryDto.description,
                    displayOrder = categoryDto.display_order,
                    isVisible = categoryDto.is_visible,
                    items = categoryDto.items.map { itemDto ->
                        CachedMenuItem(
                            id = itemDto.id,
                            categoryId = itemDto.category_id,
                            name = itemDto.name,
                            description = itemDto.description,
                            price = itemDto.price,
                            imageUrl = itemDto.image_url,
                            isAvailable = itemDto.is_available,
                            isFeatured = itemDto.is_featured,
                            displayOrder = itemDto.display_order,
                            allergens = itemDto.allergens,
                            dietaryInfo = itemDto.dietary_info
                        )
                    }
                )
            },
            lastUpdated = System.currentTimeMillis(),
            cachedAt = System.currentTimeMillis()
        )
    }
}

/**
 * Utility class for scheduling menu sync work
 */
object MenuSyncScheduler {
    
    fun schedulePeriodicSync(context: Context, intervalHours: Long = 1) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .setRequiresBatteryNotLow(true)
            .build()

        val workRequest = PeriodicWorkRequestBuilder<MenuSyncWorker>(
            intervalHours, TimeUnit.HOURS,
            15, TimeUnit.MINUTES // Flex interval
        )
            .setConstraints(constraints)
            .setBackoffCriteria(
                BackoffPolicy.EXPONENTIAL,
                RETRY_DELAY_SECONDS,
                TimeUnit.SECONDS
            )
            .build()

        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(
                MenuSyncWorker.WORK_NAME,
                ExistingPeriodicWorkPolicy.REPLACE,
                workRequest
            )
    }
    
    fun scheduleOneTimeSync(context: Context) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val workRequest = OneTimeWorkRequestBuilder<MenuSyncWorker>()
            .setConstraints(constraints)
            .setBackoffCriteria(
                BackoffPolicy.EXPONENTIAL,
                RETRY_DELAY_SECONDS,
                TimeUnit.SECONDS
            )
            .build()

        WorkManager.getInstance(context).enqueue(workRequest)
    }
    
    fun cancelSync(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(MenuSyncWorker.WORK_NAME)
    }
}