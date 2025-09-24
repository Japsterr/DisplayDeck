/**
 * Performance optimization utilities for DisplayDeck React Native mobile app.
 * Includes memory management, image optimization, and native performance monitoring.
 */

import { InteractionManager, Platform, Dimensions } from 'react-native';
import { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

/**
 * Native performance monitoring utilities.
 */
export class NativePerformanceMonitor {
  private static measurements: Map<string, number[]> = new Map();
  private static readonly MAX_MEASUREMENTS = 50;

  /**
   * Start measuring native performance.
   */
  static startMeasurement(name: string): () => void {
    const start = Date.now();
    
    return () => {
      const duration = Date.now() - start;
      this.recordMeasurement(name, duration);
    };
  }

  /**
   * Record performance measurement.
   */
  static recordMeasurement(name: string, duration: number) {
    if (!this.measurements.has(name)) {
      this.measurements.set(name, []);
    }
    
    const measurements = this.measurements.get(name)!;
    measurements.push(duration);
    
    if (measurements.length > this.MAX_MEASUREMENTS) {
      measurements.shift();
    }
  }

  /**
   * Get performance statistics.
   */
  static getStats(name: string) {
    const measurements = this.measurements.get(name) || [];
    if (measurements.length === 0) return null;

    const sorted = [...measurements].sort((a, b) => a - b);
    const sum = measurements.reduce((a, b) => a + b, 0);
    
    return {
      count: measurements.length,
      min: sorted[0],
      max: sorted[sorted.length - 1],
      avg: sum / measurements.length,
      median: sorted[Math.floor(sorted.length / 2)],
      p95: sorted[Math.floor(sorted.length * 0.95)]
    };
  }

  /**
   * Monitor memory usage (iOS only).
   */
  static getMemoryUsage(): Promise<number | null> {
    return new Promise((resolve) => {
      if (Platform.OS === 'ios') {
        // Use native module or performance API if available
        resolve(null); // Placeholder - would need native implementation
      } else {
        resolve(null);
      }
    });
  }

  /**
   * Monitor JavaScript thread performance.
   */
  static measureJSThreadPerformance(): Promise<{ fps: number; jsLoad: number }> {
    return new Promise((resolve) => {
      let frameCount = 0;
      const startTime = Date.now();
      
      const measureFrame = () => {
        frameCount++;
        
        if (Date.now() - startTime >= 1000) {
          const fps = frameCount;
          const jsLoad = 100 - (fps / 60) * 100; // Rough JS thread load estimate
          
          resolve({ fps, jsLoad: Math.max(0, jsLoad) });
        } else {
          requestAnimationFrame(measureFrame);
        }
      };
      
      requestAnimationFrame(measureFrame);
    });
  }
}

/**
 * Memory management utilities.
 */
export class MemoryManager {
  private static imageCache: Map<string, any> = new Map();
  private static readonly MAX_CACHE_SIZE = 50; // Maximum cached images

  /**
   * Clear unnecessary caches and free memory.
   */
  static clearCaches() {
    // Clear image cache
    this.imageCache.clear();
    
    // Force garbage collection if available
    if (global.gc) {
      global.gc();
    }
  }

  /**
   * Monitor and manage image cache.
   */
  static manageImageCache(uri: string, image: any) {
    if (this.imageCache.size >= this.MAX_CACHE_SIZE) {
      // Remove oldest entries
      const firstKey = this.imageCache.keys().next().value;
      this.imageCache.delete(firstKey);
    }
    
    this.imageCache.set(uri, image);
  }

  /**
   * Get cached image.
   */
  static getCachedImage(uri: string) {
    return this.imageCache.get(uri);
  }

  /**
   * Estimate memory usage.
   */
  static estimateMemoryUsage(): number {
    const imageMemory = this.imageCache.size * 1024 * 1024; // Rough estimate
    return imageMemory;
  }
}

/**
 * Image optimization utilities for React Native.
 */
export class MobileImageOptimizer {
  private static readonly SCREEN_DIMENSIONS = Dimensions.get('window');
  private static readonly SCREEN_WIDTH = MobileImageOptimizer.SCREEN_DIMENSIONS.width;
  private static readonly SCREEN_HEIGHT = MobileImageOptimizer.SCREEN_DIMENSIONS.height;

  /**
   * Get optimized image dimensions.
   */
  static getOptimizedDimensions(
    originalWidth: number,
    originalHeight: number,
    maxWidth: number = this.SCREEN_WIDTH,
    maxHeight: number = this.SCREEN_HEIGHT
  ): { width: number; height: number } {
    const aspectRatio = originalWidth / originalHeight;
    
    let width = originalWidth;
    let height = originalHeight;
    
    if (width > maxWidth) {
      width = maxWidth;
      height = width / aspectRatio;
    }
    
    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspectRatio;
    }
    
    return {
      width: Math.round(width),
      height: Math.round(height)
    };
  }

  /**
   * Generate optimized image URI with parameters.
   */
  static getOptimizedImageUri(
    baseUri: string,
    width?: number,
    height?: number,
    quality: number = 75
  ): string {
    const params = new URLSearchParams();
    
    if (width) params.append('w', width.toString());
    if (height) params.append('h', height.toString());
    params.append('q', quality.toString());
    params.append('f', 'auto'); // Auto format selection
    
    return `${baseUri}?${params.toString()}`;
  }

  /**
   * Preload critical images.
   */
  static async preloadImages(uris: string[]): Promise<void> {
    const promises = uris.map(uri => 
      new Promise<void>((resolve, reject) => {
        const image = new Image();
        image.onload = () => {
          MemoryManager.manageImageCache(uri, image);
          resolve();
        };
        image.onerror = reject;
        image.src = uri;
      })
    );

    try {
      await Promise.allSettled(promises);
    } catch (error) {
      console.warn('Some images failed to preload:', error);
    }
  }
}

/**
 * React Native performance hooks.
 */

/**
 * Hook for optimizing expensive operations with InteractionManager.
 */
export function useInteractionManager<T>(
  expensiveOperation: () => T,
  deps: React.DependencyList
): T | null {
  const [result, setResult] = useState<T | null>(null);

  useEffect(() => {
    const handle = InteractionManager.runAfterInteractions(() => {
      const operationResult = expensiveOperation();
      setResult(operationResult);
    });

    return () => handle.cancel();
  }, deps);

  return result;
}

/**
 * Hook for debounced values with native optimization.
 */
export function useNativeDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);
  const timeoutRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }

    timeoutRef.current = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    };
  }, [value, delay]);

  return debouncedValue;
}

/**
 * Hook for optimized list rendering with virtualization hints.
 */
export function useOptimizedList<T>(
  data: T[],
  itemHeight: number,
  windowSize: number = 10
) {
  const [visibleRange, setVisibleRange] = useState({ start: 0, end: windowSize });

  const getItemLayout = useCallback((_: any, index: number) => ({
    length: itemHeight,
    offset: itemHeight * index,
    index,
  }), [itemHeight]);

  const onViewableItemsChanged = useCallback(({ viewableItems }: any) => {
    if (viewableItems.length > 0) {
      const start = Math.max(0, viewableItems[0].index - windowSize / 2);
      const end = Math.min(data.length, viewableItems[viewableItems.length - 1].index + windowSize / 2);
      
      setVisibleRange({ start, end });
    }
  }, [data.length, windowSize]);

  const optimizedData = useMemo(() => {
    return data.slice(visibleRange.start, visibleRange.end);
  }, [data, visibleRange]);

  return {
    optimizedData,
    getItemLayout,
    onViewableItemsChanged,
    viewabilityConfig: {
      itemVisiblePercentThreshold: 50,
      minimumViewTime: 300,
    },
  };
}

/**
 * Hook for monitoring component render performance.
 */
export function useRenderPerformance(componentName: string, enabled: boolean = __DEV__) {
  const renderCount = useRef(0);
  const lastRenderTime = useRef(Date.now());

  useEffect(() => {
    if (!enabled) return;

    renderCount.current++;
    const currentTime = Date.now();
    const renderDuration = currentTime - lastRenderTime.current;
    
    if (renderDuration > 16) { // More than one frame at 60fps
      console.warn(
        `Slow render detected in ${componentName}: ${renderDuration}ms (render #${renderCount.current})`
      );
    }

    lastRenderTime.current = currentTime;
  });

  useEffect(() => {
    if (!enabled) return;

    return () => {
      console.log(`Component ${componentName} rendered ${renderCount.current} times`);
    };
  }, [componentName, enabled]);
}

/**
 * Async storage optimization utilities.
 */
export class OptimizedAsyncStorage {
  private static cache: Map<string, { data: any; timestamp: number }> = new Map();
  private static readonly CACHE_TTL = 5 * 60 * 1000; // 5 minutes

  /**
   * Get item with caching.
   */
  static async getItem(key: string): Promise<string | null> {
    // Check cache first
    const cached = this.cache.get(key);
    if (cached && Date.now() - cached.timestamp < this.CACHE_TTL) {
      return cached.data;
    }

    // Fetch from AsyncStorage
    const data = await AsyncStorage.getItem(key);
    
    // Update cache
    this.cache.set(key, { data, timestamp: Date.now() });
    
    return data;
  }

  /**
   * Set item with cache invalidation.
   */
  static async setItem(key: string, value: string): Promise<void> {
    await AsyncStorage.setItem(key, value);
    
    // Update cache
    this.cache.set(key, { data: value, timestamp: Date.now() });
  }

  /**
   * Batch operations for better performance.
   */
  static async multiGet(keys: string[]): Promise<readonly [string, string | null][]> {
    const cachedResults: [string, string | null][] = [];
    const keysToFetch: string[] = [];

    // Check cache for each key
    keys.forEach(key => {
      const cached = this.cache.get(key);
      if (cached && Date.now() - cached.timestamp < this.CACHE_TTL) {
        cachedResults.push([key, cached.data]);
      } else {
        keysToFetch.push(key);
      }
    });

    // Fetch remaining keys
    let fetchedResults: readonly [string, string | null][] = [];
    if (keysToFetch.length > 0) {
      fetchedResults = await AsyncStorage.multiGet(keysToFetch);
      
      // Update cache
      fetchedResults.forEach(([key, value]) => {
        this.cache.set(key, { data: value, timestamp: Date.now() });
      });
    }

    return [...cachedResults, ...fetchedResults];
  }

  /**
   * Clear expired cache entries.
   */
  static clearExpiredCache() {
    const now = Date.now();
    for (const [key, { timestamp }] of this.cache) {
      if (now - timestamp > this.CACHE_TTL) {
        this.cache.delete(key);
      }
    }
  }
}

/**
 * Network optimization utilities for mobile.
 */
export class MobileNetworkOptimizer {
  /**
   * Optimize API requests for mobile networks.
   */
  static createOptimizedFetch() {
    return async (url: string, options: RequestInit = {}) => {
      const optimizedOptions: RequestInit = {
        ...options,
        headers: {
          'Cache-Control': 'max-age=300', // 5 minutes
          'Accept-Encoding': 'gzip, br',
          ...options.headers,
        },
      };

      // Add timeout for mobile networks
      const timeoutId = setTimeout(() => {
        throw new Error('Request timeout');
      }, 15000); // 15 seconds

      try {
        const response = await fetch(url, optimizedOptions);
        clearTimeout(timeoutId);
        return response;
      } catch (error) {
        clearTimeout(timeoutId);
        throw error;
      }
    };
  }

  /**
   * Implement retry logic for unstable mobile connections.
   */
  static async fetchWithRetry(
    url: string,
    options: RequestInit = {},
    maxRetries: number = 3
  ): Promise<Response> {
    let lastError: Error;

    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        const optimizedFetch = this.createOptimizedFetch();
        return await optimizedFetch(url, options);
      } catch (error) {
        lastError = error as Error;
        
        if (attempt < maxRetries) {
          // Exponential backoff
          await new Promise(resolve => 
            setTimeout(resolve, Math.pow(2, attempt) * 1000)
          );
        }
      }
    }

    throw lastError!;
  }
}

/**
 * Battery optimization utilities.
 */
export class BatteryOptimizer {
  private static backgroundTasks: Set<() => void> = new Set();
  private static isAppInBackground = false;

  /**
   * Register a background task that should be paused when app is backgrounded.
   */
  static registerBackgroundTask(task: () => void) {
    this.backgroundTasks.add(task);
  }

  /**
   * Unregister a background task.
   */
  static unregisterBackgroundTask(task: () => void) {
    this.backgroundTasks.delete(task);
  }

  /**
   * Pause all background tasks to save battery.
   */
  static pauseBackgroundTasks() {
    this.isAppInBackground = true;
    // Implementation would pause registered tasks
  }

  /**
   * Resume background tasks when app becomes active.
   */
  static resumeBackgroundTasks() {
    this.isAppInBackground = false;
    // Implementation would resume registered tasks
  }

  /**
   * Get battery optimization recommendations.
   */
  static getOptimizationRecommendations(): string[] {
    const recommendations: string[] = [];
    
    if (this.backgroundTasks.size > 5) {
      recommendations.push('Consider reducing background tasks');
    }
    
    // Add more battery optimization recommendations
    return recommendations;
  }
}

// Export all utilities
export default {
  NativePerformanceMonitor,
  MemoryManager,
  MobileImageOptimizer,
  OptimizedAsyncStorage,
  MobileNetworkOptimizer,
  BatteryOptimizer,
};