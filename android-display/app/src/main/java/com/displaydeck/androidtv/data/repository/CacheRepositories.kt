package com.displaydeck.androidtv.data.repository

import com.displaydeck.androidtv.data.cache.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository for managing cached menu data with offline support
 */
@Singleton
class MenuCacheRepository @Inject constructor(
    private val menuDao: MenuCacheDao,
    private val syncStatusDao: SyncStatusDao
) {
    
    /**
     * Get menu by ID from cache
     */
    suspend fun getMenu(menuId: Int): CachedMenu? {
        return menuDao.getMenu(menuId)
    }
    
    /**
     * Get active menus for business from cache
     */
    suspend fun getActiveMenusForBusiness(businessId: Int): List<CachedMenu> {
        return menuDao.getActiveMenusForBusiness(businessId)
    }
    
    /**
     * Get active menus for business as Flow for reactive UI
     */
    fun getActiveMenusForBusinessFlow(businessId: Int): Flow<List<CachedMenu>> {
        return menuDao.getActiveMenusForBusinessFlow(businessId).distinctUntilChanged()
    }
    
    /**
     * Get all cached menus
     */
    suspend fun getAllMenus(): List<CachedMenu> {
        return menuDao.getAllMenus()
    }
    
    /**
     * Cache a single menu
     */
    suspend fun cacheMenu(menu: CachedMenu) {
        menuDao.insertMenu(menu.copy(cachedAt = System.currentTimeMillis()))
        
        // Mark as synced
        syncStatusDao.markSynced("menu", menu.id, System.currentTimeMillis())
    }
    
    /**
     * Cache multiple menus
     */
    suspend fun cacheMenus(menus: List<CachedMenu>) {
        val currentTime = System.currentTimeMillis()
        val cachedMenus = menus.map { it.copy(cachedAt = currentTime) }
        
        menuDao.insertMenus(cachedMenus)
        
        // Mark all as synced
        val syncStatuses = menus.map { menu ->
            SyncStatus(
                entityType = "menu",
                entityId = menu.id,
                lastSyncTime = currentTime,
                needsSync = false
            )
        }
        syncStatusDao.insertSyncStatuses(syncStatuses)
    }
    
    /**
     * Update cached menu
     */
    suspend fun updateMenu(menu: CachedMenu) {
        menuDao.updateMenu(menu.copy(lastUpdated = System.currentTimeMillis()))
        syncStatusDao.markNeedsSync("menu", menu.id)
    }
    
    /**
     * Delete cached menu
     */
    suspend fun deleteMenu(menuId: Int) {
        menuDao.deleteMenuById(menuId)
        syncStatusDao.deleteSyncStatus("menu", menuId)
    }
    
    /**
     * Delete all cached menus for a business
     */
    suspend fun deleteMenusForBusiness(businessId: Int) {
        val menus = menuDao.getActiveMenusForBusiness(businessId)
        menuDao.deleteMenusByBusiness(businessId)
        
        // Clean up sync statuses
        menus.forEach { menu ->
            syncStatusDao.deleteSyncStatus("menu", menu.id)
        }
    }
    
    /**
     * Clean up expired menu cache
     */
    suspend fun cleanupExpiredMenus() {
        val expireTime = DatabaseUtils.getMenuExpirationTime()
        menuDao.deleteExpiredMenus(expireTime)
    }
    
    /**
     * Get menu count for business
     */
    suspend fun getMenuCountForBusiness(businessId: Int): Int {
        return menuDao.getMenuCountForBusiness(businessId)
    }
    
    /**
     * Check if menu needs sync
     */
    suspend fun isMenuSyncPending(menuId: Int): Boolean {
        val syncStatus = syncStatusDao.getSyncStatus("menu", menuId)
        return syncStatus?.needsSync == true
    }
    
    /**
     * Get all menus that need sync
     */
    suspend fun getMenusNeedingSync(): List<SyncStatus> {
        return syncStatusDao.getSyncStatusForType("menu").filter { it.needsSync }
    }
}

/**
 * Repository for managing cached business data
 */
@Singleton
class BusinessCacheRepository @Inject constructor(
    private val businessDao: BusinessCacheDao,
    private val syncStatusDao: SyncStatusDao
) {
    
    /**
     * Get business by ID from cache
     */
    suspend fun getBusiness(businessId: Int): CachedBusiness? {
        return businessDao.getBusiness(businessId)
    }
    
    /**
     * Get all cached businesses
     */
    suspend fun getAllBusinesses(): List<CachedBusiness> {
        return businessDao.getAllBusinesses()
    }
    
    /**
     * Get all cached businesses as Flow
     */
    fun getAllBusinessesFlow(): Flow<List<CachedBusiness>> {
        return businessDao.getAllBusinessesFlow().distinctUntilChanged()
    }
    
    /**
     * Cache a single business
     */
    suspend fun cacheBusiness(business: CachedBusiness) {
        businessDao.insertBusiness(business.copy(cachedAt = System.currentTimeMillis()))
        
        // Mark as synced
        syncStatusDao.markSynced("business", business.id, System.currentTimeMillis())
    }
    
    /**
     * Cache multiple businesses
     */
    suspend fun cacheBusinesses(businesses: List<CachedBusiness>) {
        val currentTime = System.currentTimeMillis()
        val cachedBusinesses = businesses.map { it.copy(cachedAt = currentTime) }
        
        businessDao.insertBusinesses(cachedBusinesses)
        
        // Mark all as synced
        val syncStatuses = businesses.map { business ->
            SyncStatus(
                entityType = "business",
                entityId = business.id,
                lastSyncTime = currentTime,
                needsSync = false
            )
        }
        syncStatusDao.insertSyncStatuses(syncStatuses)
    }
    
    /**
     * Update cached business
     */
    suspend fun updateBusiness(business: CachedBusiness) {
        businessDao.updateBusiness(business.copy(lastUpdated = System.currentTimeMillis()))
        syncStatusDao.markNeedsSync("business", business.id)
    }
    
    /**
     * Delete cached business
     */
    suspend fun deleteBusiness(businessId: Int) {
        businessDao.deleteBusinessById(businessId)
        syncStatusDao.deleteSyncStatus("business", businessId)
    }
    
    /**
     * Clean up expired business cache
     */
    suspend fun cleanupExpiredBusinesses() {
        val expireTime = DatabaseUtils.getBusinessExpirationTime()
        businessDao.deleteExpiredBusinesses(expireTime)
    }
    
    /**
     * Check if business needs sync
     */
    suspend fun isBusinessSyncPending(businessId: Int): Boolean {
        val syncStatus = syncStatusDao.getSyncStatus("business", businessId)
        return syncStatus?.needsSync == true
    }
    
    /**
     * Get all businesses that need sync
     */
    suspend fun getBusinessesNeedingSync(): List<SyncStatus> {
        return syncStatusDao.getSyncStatusForType("business").filter { it.needsSync }
    }
}