/**
 * Performance optimization utilities for DisplayDeck frontend.
 * Includes lazy loading, memoization, bundle optimization, and performance monitoring.
 */

import React, { lazy, memo, useMemo, useCallback, useRef, useEffect, useState } from 'react';

/**
 * Lazy loading utilities for code splitting and dynamic imports.
 */
export class LazyLoadManager {
  private static loadedModules = new Map<string, Promise<any>>();
  private static preloadQueue = new Set<string>();

  /**
   * Create a lazy-loaded component with error boundary.
   */
  static createLazyComponent<T>(importFn: () => Promise<{ default: T }>, fallback?: React.ComponentType) {
    const LazyComponent = lazy(importFn);
    
    return memo((props: any) => {
      return (
        <React.Suspense fallback={fallback ? <fallback /> : <div>Loading...</div>}>
          <LazyComponent {...props} />
        </React.Suspense>
      );
    });
  }

  /**
   * Preload a module for faster future loading.
   */
  static preload(moduleId: string, importFn: () => Promise<any>) {
    if (!this.loadedModules.has(moduleId) && !this.preloadQueue.has(moduleId)) {
      this.preloadQueue.add(moduleId);
      
      // Use requestIdleCallback if available, otherwise use setTimeout
      const preloadFn = () => {
        const promise = importFn();
        this.loadedModules.set(moduleId, promise);
        this.preloadQueue.delete(moduleId);
      };

      if ('requestIdleCallback' in window) {
        requestIdleCallback(preloadFn);
      } else {
        setTimeout(preloadFn, 0);
      }
    }
  }

  /**
   * Get preloaded module if available.
   */
  static getPreloaded(moduleId: string): Promise<any> | null {
    return this.loadedModules.get(moduleId) || null;
  }
}

/**
 * Memoization utilities for expensive operations.
 */
export class MemoizationHelper {
  private static cache = new Map<string, { value: any; timestamp: number }>();
  private static readonly DEFAULT_TTL = 5 * 60 * 1000; // 5 minutes

  /**
   * Memoize a function with TTL support.
   */
  static memoizeWithTTL<T extends (...args: any[]) => any>(
    fn: T,
    keyFn?: (...args: Parameters<T>) => string,
    ttl = this.DEFAULT_TTL
  ): T {
    return ((...args: Parameters<T>) => {
      const key = keyFn ? keyFn(...args) : JSON.stringify(args);
      const cached = this.cache.get(key);
      
      if (cached && Date.now() - cached.timestamp < ttl) {
        return cached.value;
      }
      
      const result = fn(...args);
      this.cache.set(key, { value: result, timestamp: Date.now() });
      
      return result;
    }) as T;
  }

  /**
   * Clear expired cache entries.
   */
  static cleanup() {
    const now = Date.now();
    for (const [key, { timestamp }] of this.cache) {
      if (now - timestamp > this.DEFAULT_TTL) {
        this.cache.delete(key);
      }
    }
  }

  /**
   * Clear all cache entries.
   */
  static clear() {
    this.cache.clear();
  }
}

/**
 * React hooks for performance optimization.
 */

/**
 * Debounced version of a value.
 */
export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(handler);
    };
  }, [value, delay]);

  return debouncedValue;
}

/**
 * Throttled version of a callback function.
 */
export function useThrottle<T extends (...args: any[]) => any>(
  callback: T,
  delay: number
): T {
  const lastRun = useRef<number>(0);
  
  return useCallback((...args: Parameters<T>) => {
    const now = Date.now();
    if (now - lastRun.current >= delay) {
      lastRun.current = now;
      return callback(...args);
    }
  }, [callback, delay]) as T;
}

/**
 * Memoized selector function.
 */
export function useMemoizedSelector<T, R>(
  selector: (data: T) => R,
  data: T,
  deps?: React.DependencyList
): R {
  return useMemo(() => selector(data), deps ? [data, ...deps] : [data]);
}

/**
 * Virtual scrolling hook for large lists.
 */
export function useVirtualScrolling<T>(
  items: T[],
  itemHeight: number,
  containerHeight: number
) {
  const [scrollTop, setScrollTop] = useState(0);
  
  const startIndex = Math.floor(scrollTop / itemHeight);
  const endIndex = Math.min(
    startIndex + Math.ceil(containerHeight / itemHeight) + 1,
    items.length
  );
  
  const visibleItems = items.slice(startIndex, endIndex);
  const offsetY = startIndex * itemHeight;
  const totalHeight = items.length * itemHeight;
  
  return {
    visibleItems,
    startIndex,
    endIndex,
    offsetY,
    totalHeight,
    setScrollTop
  };
}

/**
 * Intersection Observer hook for lazy loading.
 */
export function useIntersectionObserver(
  elementRef: React.RefObject<Element>,
  options?: IntersectionObserverInit
): boolean {
  const [isIntersecting, setIsIntersecting] = useState(false);

  useEffect(() => {
    const element = elementRef.current;
    if (!element) return;

    const observer = new IntersectionObserver(
      ([entry]) => setIsIntersecting(entry.isIntersecting),
      options
    );

    observer.observe(element);

    return () => observer.disconnect();
  }, [elementRef, options]);

  return isIntersecting;
}

/**
 * Performance monitoring utilities.
 */
export class PerformanceMonitor {
  private static measurements = new Map<string, number[]>();
  private static readonly MAX_MEASUREMENTS = 100;

  /**
   * Start measuring performance for a given operation.
   */
  static startMeasurement(name: string): () => void {
    const start = performance.now();
    
    return () => {
      const duration = performance.now() - start;
      this.recordMeasurement(name, duration);
    };
  }

  /**
   * Record a performance measurement.
   */
  static recordMeasurement(name: string, duration: number) {
    if (!this.measurements.has(name)) {
      this.measurements.set(name, []);
    }
    
    const measurements = this.measurements.get(name)!;
    measurements.push(duration);
    
    // Keep only the latest measurements
    if (measurements.length > this.MAX_MEASUREMENTS) {
      measurements.shift();
    }
  }

  /**
   * Get performance statistics for a measurement.
   */
  static getStats(name: string) {
    const measurements = this.measurements.get(name) || [];
    if (measurements.length === 0) {
      return null;
    }

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
   * Get all performance statistics.
   */
  static getAllStats() {
    const stats: Record<string, any> = {};
    for (const name of this.measurements.keys()) {
      stats[name] = this.getStats(name);
    }
    return stats;
  }

  /**
   * Clear all measurements.
   */
  static clear() {
    this.measurements.clear();
  }
}

/**
 * Performance-optimized component wrapper.
 */
export function withPerformanceOptimization<P extends object>(
  Component: React.ComponentType<P>,
  options: {
    memo?: boolean;
    measureRender?: boolean;
    preload?: () => Promise<any>;
  } = {}
) {
  const { memo: useMemo = true, measureRender = false, preload } = options;
  
  let WrappedComponent = Component;
  
  // Apply memoization if requested
  if (useMemo) {
    WrappedComponent = memo(WrappedComponent);
  }
  
  // Add render performance measurement
  if (measureRender) {
    const componentName = Component.displayName || Component.name || 'Anonymous';
    
    WrappedComponent = (props: P) => {
      const endMeasurement = PerformanceMonitor.startMeasurement(`render_${componentName}`);
      
      useEffect(() => {
        endMeasurement();
      });
      
      return <Component {...props} />;
    };
  }
  
  // Add preloading capability
  if (preload) {
    const componentName = Component.displayName || Component.name || 'Anonymous';
    LazyLoadManager.preload(componentName, preload);
  }
  
  return WrappedComponent;
}

/**
 * Bundle optimization utilities.
 */
export class BundleOptimizer {
  /**
   * Dynamically import a module with retry logic.
   */
  static async dynamicImport<T>(
    importFn: () => Promise<T>,
    retries = 3,
    delay = 1000
  ): Promise<T> {
    let lastError: Error;
    
    for (let attempt = 0; attempt <= retries; attempt++) {
      try {
        return await importFn();
      } catch (error) {
        lastError = error as Error;
        
        if (attempt < retries) {
          await new Promise(resolve => setTimeout(resolve, delay * Math.pow(2, attempt)));
        }
      }
    }
    
    throw lastError!;
  }

  /**
   * Preload critical resources.
   */
  static preloadCriticalResources(resources: Array<{ href: string; type: 'script' | 'style' | 'font' }>) {
    resources.forEach(({ href, type }) => {
      const link = document.createElement('link');
      link.rel = 'preload';
      link.href = href;
      
      if (type === 'script') {
        link.as = 'script';
      } else if (type === 'style') {
        link.as = 'style';
      } else if (type === 'font') {
        link.as = 'font';
        link.crossOrigin = 'anonymous';
      }
      
      document.head.appendChild(link);
    });
  }

  /**
   * Prefetch non-critical resources.
   */
  static prefetchResources(urls: string[]) {
    urls.forEach(url => {
      const link = document.createElement('link');
      link.rel = 'prefetch';
      link.href = url;
      document.head.appendChild(link);
    });
  }
}

/**
 * Image optimization utilities.
 */
export class ImageOptimizer {
  /**
   * Create optimized image source set.
   */
  static createSrcSet(baseUrl: string, sizes: number[]): string {
    return sizes
      .map(size => `${baseUrl}?w=${size}&q=75 ${size}w`)
      .join(', ');
  }

  /**
   * Lazy load image with placeholder.
   */
  static useLazyImage(src: string, placeholder?: string) {
    const [imageSrc, setImageSrc] = useState(placeholder || '');
    const [isLoaded, setIsLoaded] = useState(false);
    const imgRef = useRef<HTMLImageElement>(null);
    
    const isVisible = useIntersectionObserver(imgRef, {
      threshold: 0.1,
      rootMargin: '50px'
    });

    useEffect(() => {
      if (isVisible && !isLoaded) {
        const img = new Image();
        img.onload = () => {
          setImageSrc(src);
          setIsLoaded(true);
        };
        img.src = src;
      }
    }, [isVisible, src, isLoaded]);

    return { imageSrc, isLoaded, imgRef };
  }

  /**
   * Get responsive image props.
   */
  static getResponsiveProps(baseUrl: string) {
    const sizes = [320, 640, 960, 1280, 1920];
    
    return {
      srcSet: this.createSrcSet(baseUrl, sizes),
      sizes: '(max-width: 320px) 320px, (max-width: 640px) 640px, (max-width: 960px) 960px, (max-width: 1280px) 1280px, 1920px'
    };
  }
}

// Export all performance optimization utilities