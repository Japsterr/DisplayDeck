package com.displaydeck.androidtv.di

import androidx.work.DelegatingWorkerFactory
import com.displaydeck.androidtv.worker.*
import dagger.hilt.android.components.SingletonComponent
import dagger.hilt.android.scopes.SingletonScoped
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Custom WorkerFactory for Hilt dependency injection in Workers
 */
@Singleton
class HiltWorkerFactory @Inject constructor(
    // Inject any dependencies that workers need here
) : DelegatingWorkerFactory() {
    
    // The actual worker factory is provided by Hilt through the @HiltWorker annotation
    // No additional implementation needed here as Hilt handles the worker creation
}