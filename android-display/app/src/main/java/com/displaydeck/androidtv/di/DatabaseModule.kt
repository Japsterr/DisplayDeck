package com.displaydeck.androidtv.di

import android.content.Context
import androidx.room.Room
import com.displaydeck.androidtv.data.cache.*
import com.displaydeck.androidtv.data.repository.*
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideAppDatabase(@ApplicationContext context: Context): AppDatabase {
        return Room.databaseBuilder(
            context,
            AppDatabase::class.java,
            AppDatabase.DATABASE_NAME
        )
        .fallbackToDestructiveMigration() // For development - remove in production
        .build()
    }

    @Provides
    fun provideMenuCacheDao(database: AppDatabase): MenuCacheDao {
        return database.menuCacheDao()
    }

    @Provides
    fun provideBusinessCacheDao(database: AppDatabase): BusinessCacheDao {
        return database.businessCacheDao()
    }

    @Provides
    fun provideDisplaySettingsDao(database: AppDatabase): DisplaySettingsDao {
        return database.displaySettingsDao()
    }

    @Provides
    fun provideSyncStatusDao(database: AppDatabase): SyncStatusDao {
        return database.syncStatusDao()
    }

    @Provides
    fun provideMediaCacheDao(database: AppDatabase): MediaCacheDao {
        return database.mediaCacheDao()
    }
}

@Module
@InstallIn(SingletonComponent::class)
object RepositoryModule {

    @Provides
    @Singleton
    fun provideMenuCacheRepository(
        menuDao: MenuCacheDao,
        syncStatusDao: SyncStatusDao
    ): MenuCacheRepository {
        return MenuCacheRepository(menuDao, syncStatusDao)
    }

    @Provides
    @Singleton
    fun provideBusinessCacheRepository(
        businessDao: BusinessCacheDao,
        syncStatusDao: SyncStatusDao
    ): BusinessCacheRepository {
        return BusinessCacheRepository(businessDao, syncStatusDao)
    }

    @Provides
    @Singleton
    fun provideDisplaySettingsRepository(
        displaySettingsDao: DisplaySettingsDao
    ): DisplaySettingsRepository {
        return DisplaySettingsRepository(displaySettingsDao)
    }

    @Provides
    @Singleton
    fun provideMediaCacheRepository(
        mediaCacheDao: MediaCacheDao
    ): MediaCacheRepository {
        return MediaCacheRepository(mediaCacheDao)
    }
}