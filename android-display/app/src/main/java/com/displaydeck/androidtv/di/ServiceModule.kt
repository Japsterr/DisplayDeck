package com.displaydeck.androidtv.di

import android.content.Context
import androidx.work.WorkManager
import com.displaydeck.androidtv.service.*
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object ServiceModule {

    @Provides
    @Singleton
    fun provideHealthMonitoringService(@ApplicationContext context: Context): HealthMonitoringService {
        return HealthMonitoringService(context)
    }

    @Provides
    @Singleton
    fun provideAutoUpdateService(
        @ApplicationContext context: Context,
        apiService: com.displaydeck.androidtv.data.network.ApiService,
        displaySettingsRepository: com.displaydeck.androidtv.data.repository.DisplaySettingsRepository
    ): AutoUpdateService {
        return AutoUpdateService(context, apiService, displaySettingsRepository)
    }

    @Provides
    @Singleton
    fun provideWorkManager(@ApplicationContext context: Context): WorkManager {
        return WorkManager.getInstance(context)
    }
}