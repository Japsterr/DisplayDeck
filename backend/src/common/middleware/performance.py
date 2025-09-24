"""
Database performance optimization middleware for DisplayDeck.
Implements query optimization, connection pooling, and performance monitoring.
"""

import logging
import time
from django.conf import settings
from django.db import connection
from django.core.cache import cache
from django.utils.deprecation import MiddlewareMixin
from django.http import JsonResponse

logger = logging.getLogger('performance')


class DatabasePerformanceMiddleware(MiddlewareMixin):
    """
    Middleware to monitor and optimize database performance.
    Tracks slow queries, connection usage, and provides performance metrics.
    """
    
    def __init__(self, get_response):
        super().__init__(get_response)
        self.get_response = get_response
        self.slow_query_threshold = getattr(settings, 'PERFORMANCE_MONITORING', {}).get('SLOW_QUERY_THRESHOLD', 0.5)
        self.slow_request_threshold = getattr(settings, 'PERFORMANCE_MONITORING', {}).get('SLOW_REQUEST_THRESHOLD', 2.0)
    
    def process_request(self, request):
        """Initialize performance tracking for the request."""
        request._db_queries_start = len(connection.queries)
        request._start_time = time.time()
        
        # Reset connection queries for accurate tracking
        connection.queries_logged.clear() if hasattr(connection, 'queries_logged') else None
        
    def process_response(self, request, response):
        """Process response and log performance metrics."""
        if not hasattr(request, '_start_time'):
            return response
            
        # Calculate request timing
        total_time = time.time() - request._start_time
        
        # Calculate database metrics
        db_queries = len(connection.queries) - getattr(request, '_db_queries_start', 0)
        db_time = sum(float(query['time']) for query in connection.queries[getattr(request, '_db_queries_start', 0):])
        
        # Log slow requests
        if total_time > self.slow_request_threshold:
            logger.warning(
                f"Slow request: {request.method} {request.get_full_path()} "
                f"took {total_time:.2f}s with {db_queries} queries ({db_time:.2f}s DB time)"
            )
        
        # Log slow individual queries
        self._log_slow_queries(connection.queries[getattr(request, '_db_queries_start', 0):])
        
        # Add performance headers in debug mode
        if settings.DEBUG:
            response['X-DB-Queries'] = str(db_queries)
            response['X-DB-Time'] = f"{db_time:.3f}"
            response['X-Total-Time'] = f"{total_time:.3f}"
        
        # Cache performance metrics
        self._cache_performance_metrics(request, total_time, db_queries, db_time)
        
        return response
    
    def _log_slow_queries(self, queries):
        """Log individual slow queries."""
        for query in queries:
            query_time = float(query['time'])
            if query_time > self.slow_query_threshold:
                logger.warning(
                    f"Slow query ({query_time:.3f}s): {query['sql'][:200]}..."
                )
    
    def _cache_performance_metrics(self, request, total_time, db_queries, db_time):
        """Cache performance metrics for monitoring dashboard."""
        cache_key = f"perf_metrics_{int(time.time() // 60)}"  # Per minute
        
        current_metrics = cache.get(cache_key, {
            'requests': 0,
            'total_time': 0,
            'total_queries': 0,
            'total_db_time': 0,
            'slow_requests': 0
        })
        
        current_metrics['requests'] += 1
        current_metrics['total_time'] += total_time
        current_metrics['total_queries'] += db_queries
        current_metrics['total_db_time'] += db_time
        
        if total_time > self.slow_request_threshold:
            current_metrics['slow_requests'] += 1
        
        cache.set(cache_key, current_metrics, 300)  # 5 minutes


class QueryOptimizationMiddleware(MiddlewareMixin):
    """
    Middleware to apply automatic query optimizations.
    """
    
    def process_request(self, request):
        """Apply query optimizations before processing."""
        # Enable connection pooling parameters
        connection.ensure_connection()
        
        # Set optimal connection parameters for this request
        if hasattr(connection, 'connection') and connection.connection:
            cursor = connection.cursor()
            
            # Set work_mem for complex queries (PostgreSQL specific)
            cursor.execute("SET work_mem = '16MB'")
            
            # Enable parallel query execution
            cursor.execute("SET max_parallel_workers_per_gather = 2")
            
            # Optimize for OLTP workloads
            cursor.execute("SET random_page_cost = 1.1")
            
            cursor.close()


class CacheOptimizationMiddleware(MiddlewareMixin):
    """
    Middleware to optimize caching strategies and cache hit rates.
    """
    
    def process_request(self, request):
        """Process incoming request for cache optimization."""
        # Add cache-friendly headers for static content
        if self._is_static_content(request):
            request.cache_timeout = 3600  # 1 hour for static content
        elif self._is_api_content(request):
            request.cache_timeout = 300   # 5 minutes for API responses
        else:
            request.cache_timeout = 60    # 1 minute for dynamic content
    
    def process_response(self, request, response):
        """Add optimal cache headers to response."""
        if hasattr(request, 'cache_timeout') and response.status_code == 200:
            cache_timeout = getattr(request, 'cache_timeout', 300)
            
            # Set cache-control headers
            response['Cache-Control'] = f'max-age={cache_timeout}, public'
            
            # Add ETag for conditional requests
            if not response.has_header('ETag'):
                response['ETag'] = f'"{hash(response.content)}"'
            
            # Add Vary headers for API responses
            if self._is_api_content(request):
                response['Vary'] = 'Accept, Authorization'
        
        return response
    
    def _is_static_content(self, request):
        """Check if request is for static content."""
        path = request.path_info
        return any(path.startswith(prefix) for prefix in ['/static/', '/media/'])
    
    def _is_api_content(self, request):
        """Check if request is for API content."""
        return request.path_info.startswith('/api/')


class CompressionMiddleware(MiddlewareMixin):
    """
    Middleware to handle response compression optimization.
    """
    
    def process_response(self, request, response):
        """Apply compression optimizations to response."""
        # Skip compression for small responses
        if len(response.content) < 1024:
            return response
        
        # Add compression hints
        response['Vary'] = response.get('Vary', '') + ', Accept-Encoding'
        
        # Suggest optimal compression for different content types
        content_type = response.get('Content-Type', '')
        
        if 'application/json' in content_type:
            response['X-Compress-Hint'] = 'gzip,br'
        elif 'text/html' in content_type:
            response['X-Compress-Hint'] = 'gzip,br'
        elif 'text/css' in content_type or 'application/javascript' in content_type:
            response['X-Compress-Hint'] = 'gzip,br'
        
        return response


def get_performance_metrics():
    """
    Get current performance metrics from cache.
    Used for monitoring dashboard and health checks.
    """
    current_minute = int(time.time() // 60)
    metrics = {}
    
    # Collect metrics from last 5 minutes
    for i in range(5):
        cache_key = f"perf_metrics_{current_minute - i}"
        minute_metrics = cache.get(cache_key, {})
        
        if minute_metrics:
            for key, value in minute_metrics.items():
                metrics[key] = metrics.get(key, 0) + value
    
    # Calculate averages
    if metrics.get('requests', 0) > 0:
        metrics['avg_response_time'] = metrics['total_time'] / metrics['requests']
        metrics['avg_queries_per_request'] = metrics['total_queries'] / metrics['requests']
        metrics['avg_db_time_per_request'] = metrics['total_db_time'] / metrics['requests']
    else:
        metrics['avg_response_time'] = 0
        metrics['avg_queries_per_request'] = 0
        metrics['avg_db_time_per_request'] = 0
    
    return metrics


def get_database_health():
    """
    Check database connection health and performance.
    """
    try:
        cursor = connection.cursor()
        
        # Test basic connectivity
        start_time = time.time()
        cursor.execute("SELECT 1")
        connection_time = time.time() - start_time
        
        # Check connection count (PostgreSQL specific)
        cursor.execute("""
            SELECT count(*) as connection_count 
            FROM pg_stat_activity 
            WHERE state = 'active'
        """)
        active_connections = cursor.fetchone()[0]
        
        # Check for long-running queries
        cursor.execute("""
            SELECT count(*) as long_queries 
            FROM pg_stat_activity 
            WHERE state = 'active' 
            AND query_start < now() - interval '30 seconds'
        """)
        long_queries = cursor.fetchone()[0]
        
        # Get cache hit ratio
        cursor.execute("""
            SELECT 
                sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as cache_hit_ratio
            FROM pg_statio_user_tables
        """)
        result = cursor.fetchone()
        cache_hit_ratio = float(result[0]) if result and result[0] else 0
        
        cursor.close()
        
        return {
            'status': 'healthy',
            'connection_time_ms': round(connection_time * 1000, 2),
            'active_connections': active_connections,
            'long_running_queries': long_queries,
            'cache_hit_ratio': round(cache_hit_ratio * 100, 2)
        }
        
    except Exception as e:
        return {
            'status': 'unhealthy',
            'error': str(e)
        }


class PerformanceDashboardView:
    """
    View to provide performance metrics for monitoring dashboard.
    """
    
    def __call__(self, request):
        """Return performance metrics as JSON."""
        if not request.user.is_staff:
            return JsonResponse({'error': 'Unauthorized'}, status=403)
        
        metrics = get_performance_metrics()
        db_health = get_database_health()
        
        # Get cache statistics
        try:
            cache_stats = cache._cache.get_stats()
        except AttributeError:
            cache_stats = {'hits': 0, 'misses': 0}
        
        return JsonResponse({
            'performance': metrics,
            'database': db_health,
            'cache': cache_stats,
            'timestamp': time.time()
        })


# Custom database router for read/write splitting
class DatabaseRouter:
    """
    A router to control database operations for performance optimization.
    Routes read queries to read replicas when available.
    """
    
    def db_for_read(self, model, **hints):
        """Suggest the database to read from."""
        # Use read replica if configured
        if hasattr(settings, 'DATABASE_READ_REPLICA') and settings.DATABASE_READ_REPLICA:
            return 'read_replica'
        return None
    
    def db_for_write(self, model, **hints):
        """Suggest the database to write to."""
        # Always write to primary database
        return 'default'
    
    def allow_relation(self, obj1, obj2, **hints):
        """Allow relations between objects."""
        return True
    
    def allow_migrate(self, db, app_label, model_name=None, **hints):
        """Ensure that migrations only run on primary database."""
        return db == 'default'