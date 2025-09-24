package com.displaydeck.androidtv.data.cache.dao

import androidx.room.*
import com.displaydeck.androidtv.data.cache.entities.CachedMenu
import com.displaydeck.androidtv.data.cache.entities.CachedMenuCategory
import com.displaydeck.androidtv.data.cache.entities.CachedMenuItem
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object for cached menu operations.
 * Provides methods for CRUD operations on menu data with offline support.
 */
@Dao
interface CachedMenuDao {
    
    // Menu operations
    @Query("SELECT * FROM cached_menus WHERE business_id = :businessId AND is_active = 1")
    fun getActiveMenusForBusiness(businessId: Long): Flow<List<CachedMenu>>
    
    @Query("SELECT * FROM cached_menus WHERE id = :menuId")
    suspend fun getMenuById(menuId: Long): CachedMenu?
    
    @Query("SELECT * FROM cached_menus WHERE business_id = :businessId ORDER BY updated_at DESC LIMIT 1")
    suspend fun getLatestMenuForBusiness(businessId: Long): CachedMenu?
    
    @Query("SELECT * FROM cached_menus WHERE display_id = :displayId AND is_active = 1")
    fun getActiveMenuForDisplay(displayId: Long): Flow<CachedMenu?>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMenu(menu: CachedMenu): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMenus(menus: List<CachedMenu>): List<Long>
    
    @Update
    suspend fun updateMenu(menu: CachedMenu)
    
    @Delete
    suspend fun deleteMenu(menu: CachedMenu)
    
    @Query("DELETE FROM cached_menus WHERE business_id = :businessId")
    suspend fun deleteMenusForBusiness(businessId: Long)
    
    @Query("DELETE FROM cached_menus WHERE id = :menuId")
    suspend fun deleteMenuById(menuId: Long)
    
    // Menu with categories and items (complex queries)
    @Transaction
    @Query("SELECT * FROM cached_menus WHERE id = :menuId")
    suspend fun getMenuWithCategories(menuId: Long): MenuWithCategories?
    
    @Transaction
    @Query("SELECT * FROM cached_menus WHERE business_id = :businessId AND is_active = 1")
    fun getActiveMenusWithCategoriesForBusiness(businessId: Long): Flow<List<MenuWithCategories>>
    
    @Transaction
    @Query("SELECT * FROM cached_menus WHERE display_id = :displayId AND is_active = 1")
    fun getActiveMenuWithCategoriesForDisplay(displayId: Long): Flow<MenuWithCategories?>
    
    // Category operations
    @Query("SELECT * FROM cached_menu_categories WHERE menu_id = :menuId ORDER BY display_order ASC")
    suspend fun getCategoriesForMenu(menuId: Long): List<CachedMenuCategory>
    
    @Query("SELECT * FROM cached_menu_categories WHERE id = :categoryId")
    suspend fun getCategoryById(categoryId: Long): CachedMenuCategory?
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCategory(category: CachedMenuCategory): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCategories(categories: List<CachedMenuCategory>): List<Long>
    
    @Update
    suspend fun updateCategory(category: CachedMenuCategory)
    
    @Delete
    suspend fun deleteCategory(category: CachedMenuCategory)
    
    @Query("DELETE FROM cached_menu_categories WHERE menu_id = :menuId")
    suspend fun deleteCategoriesForMenu(menuId: Long)
    
    // Item operations
    @Query("SELECT * FROM cached_menu_items WHERE category_id = :categoryId ORDER BY display_order ASC")
    suspend fun getItemsForCategory(categoryId: Long): List<CachedMenuItem>
    
    @Query("SELECT * FROM cached_menu_items WHERE menu_id = :menuId ORDER BY display_order ASC")
    suspend fun getItemsForMenu(menuId: Long): List<CachedMenuItem>
    
    @Query("SELECT * FROM cached_menu_items WHERE id = :itemId")
    suspend fun getItemById(itemId: Long): CachedMenuItem?
    
    @Query("SELECT * FROM cached_menu_items WHERE menu_id = :menuId AND is_available = 1 ORDER BY display_order ASC")
    suspend fun getAvailableItemsForMenu(menuId: Long): List<CachedMenuItem>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertItem(item: CachedMenuItem): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertItems(items: List<CachedMenuItem>): List<Long>
    
    @Update
    suspend fun updateItem(item: CachedMenuItem)
    
    @Delete
    suspend fun deleteItem(item: CachedMenuItem)
    
    @Query("DELETE FROM cached_menu_items WHERE menu_id = :menuId")
    suspend fun deleteItemsForMenu(menuId: Long)
    
    @Query("DELETE FROM cached_menu_items WHERE category_id = :categoryId")
    suspend fun deleteItemsForCategory(categoryId: Long)
    
    // Search operations
    @Query("""
        SELECT * FROM cached_menu_items 
        WHERE menu_id = :menuId 
        AND (name LIKE '%' || :query || '%' OR description LIKE '%' || :query || '%')
        AND is_available = 1
        ORDER BY display_order ASC
    """)
    suspend fun searchItemsInMenu(menuId: Long, query: String): List<CachedMenuItem>
    
    @Query("""
        SELECT * FROM cached_menu_items 
        WHERE category_id = :categoryId 
        AND (name LIKE '%' || :query || '%' OR description LIKE '%' || :query || '%')
        AND is_available = 1
        ORDER BY display_order ASC
    """)
    suspend fun searchItemsInCategory(categoryId: Long, query: String): List<CachedMenuItem>
    
    // Availability operations
    @Query("UPDATE cached_menu_items SET is_available = :isAvailable WHERE id = :itemId")
    suspend fun updateItemAvailability(itemId: Long, isAvailable: Boolean)
    
    @Query("UPDATE cached_menu_items SET is_available = :isAvailable WHERE category_id = :categoryId")
    suspend fun updateCategoryItemsAvailability(categoryId: Long, isAvailable: Boolean)
    
    @Query("UPDATE cached_menus SET is_active = :isActive WHERE id = :menuId")
    suspend fun updateMenuActiveStatus(menuId: Long, isActive: Boolean)
    
    // Sync and cache management
    @Query("SELECT COUNT(*) FROM cached_menus WHERE business_id = :businessId")
    suspend fun getMenuCountForBusiness(businessId: Long): Int
    
    @Query("SELECT MAX(updated_at) FROM cached_menus WHERE business_id = :businessId")
    suspend fun getLatestUpdateTimeForBusiness(businessId: Long): Long?
    
    @Query("DELETE FROM cached_menus WHERE updated_at < :cutoffTime")
    suspend fun deleteOldMenus(cutoffTime: Long): Int
    
    @Query("SELECT * FROM cached_menus WHERE last_sync < :cutoffTime OR last_sync IS NULL")
    suspend fun getMenusNeedingSync(cutoffTime: Long): List<CachedMenu>
    
    // Transaction for complete menu replacement
    @Transaction
    suspend fun replaceMenu(
        menu: CachedMenu,
        categories: List<CachedMenuCategory>,
        items: List<CachedMenuItem>
    ) {
        // Delete existing data
        deleteItemsForMenu(menu.id)
        deleteCategoriesForMenu(menu.id)
        deleteMenuById(menu.id)
        
        // Insert new data
        insertMenu(menu)
        insertCategories(categories)
        insertItems(items)
    }
    
    @Transaction
    suspend fun replaceMenuForBusiness(
        businessId: Long,
        menu: CachedMenu,
        categories: List<CachedMenuCategory>,
        items: List<CachedMenuItem>
    ) {
        // Delete existing menus for business
        deleteMenusForBusiness(businessId)
        
        // Insert new menu data
        insertMenu(menu)
        insertCategories(categories)
        insertItems(items)
    }
}

/**
 * Data class representing a menu with its categories and items.
 * Used for complex queries that need to fetch related data.
 */
data class MenuWithCategories(
    @Embedded val menu: CachedMenu,
    @Relation(
        entity = CachedMenuCategory::class,
        parentColumn = "id",
        entityColumn = "menu_id"
    )
    val categories: List<CategoryWithItems>
)

/**
 * Data class representing a category with its items.
 */
data class CategoryWithItems(
    @Embedded val category: CachedMenuCategory,
    @Relation(
        parentColumn = "id",
        entityColumn = "category_id"
    )
    val items: List<CachedMenuItem>
)