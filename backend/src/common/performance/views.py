"""
Performance monitoring API views for DisplayDeck.
Provides endpoints for monitoring system performance, database health, and cache statistics.
"""

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response
from django.http import JsonResponse
from django.views.decorators.cache import cache_page
from django.utils.decorators import method_decorator
from django.views.generic import View
import json
import time
from .middleware.performance import get_performance_metrics, get_database_health
from .optimization.database import DatabaseOptimizer, CacheOptimizer


@api_view(['GET'])
@permission_classes([IsAdminUser])
def performance_dashboard(request):
    """
    Comprehensive performance dashboard endpoint.
    Returns system performance metrics, database health, and optimization recommendations.
    """
    try:
        # Get performance metrics
        performance_metrics = get_performance_metrics()
        
        # Get database health
        db_health = get_database_health()
        
        # Get cache performance
        cache_optimizer = CacheOptimizer()
        cache_stats = cache_optimizer.analyze_cache_performance()
        
        # Get database statistics
        db_optimizer = DatabaseOptimizer()
        table_stats = db_optimizer.get_table_statistics()
        connection_stats = db_optimizer.monitor_connections()
        
        # Calculate health score
        health_score = calculate_health_score(
            performance_metrics, 
            db_health, 
            cache_stats, 
            connection_stats
        )
        
        return Response({
            'timestamp': time.time(),
            'health_score': health_score,
            'performance': performance_metrics,
            'database': {
                'health': db_health,
                'connections': connection_stats,
                'table_count': len(table_stats),
                'largest_tables': table_stats[:5] if table_stats else []
            },
            'cache': cache_stats,
            'recommendations': get_performance_recommendations(
                performance_metrics, 
                db_health, 
                cache_stats
            )
        })
        
    except Exception as e:
        return Response({
            'error': str(e),
            'timestamp': time.time()
        }, status=500)


@api_view(['GET'])
@permission_classes([IsAdminUser])
def slow_queries(request):
    """
    Get slow query analysis.
    """
    try:
        threshold = float(request.GET.get('threshold', 1000))  # Default 1000ms
        
        db_optimizer = DatabaseOptimizer()
        slow_queries = db_optimizer.analyze_slow_queries(threshold)
        
        return Response({
            'threshold_ms': threshold,
            'slow_queries': slow_queries,
            'total_count': len(slow_queries),
            'timestamp': time.time()
        })
        
    except Exception as e:
        return Response({
            'error': str(e)
        }, status=500)


@api_view(['GET'])
@permission_classes([IsAdminUser])
def index_analysis(request):
    """
    Analyze database indexes and provide recommendations.
    """
    try:
        db_optimizer = DatabaseOptimizer()
        
        unused_indexes = db_optimizer.get_index_usage()
        missing_index_suggestions = db_optimizer.create_missing_indexes()
        
        return Response({
            'unused_indexes': unused_indexes,
            'missing_index_suggestions': missing_index_suggestions,
            'timestamp': time.time()
        })
        
    except Exception as e:
        return Response({
            'error': str(e)
        }, status=500)


@api_view(['POST'])
@permission_classes([IsAdminUser])
def optimize_database(request):
    """
    Trigger database optimization tasks.
    """
    try:
        analyze_only = request.data.get('analyze_only', False)
        
        db_optimizer = DatabaseOptimizer()
        
        result = {
            'timestamp': time.time(),
            'analyze_only': analyze_only,
            'optimizations_applied': []
        }
        
        if not analyze_only:
            # Apply optimizations
            optimizations = db_optimizer.optimize_queries()
            result['optimizations_applied'] = optimizations
            
            # Clear cache if requested
            if request.data.get('clear_cache', False):
                cache_optimizer = CacheOptimizer()
                cache_cleared = cache_optimizer.clear_expired_keys()
                result['cache_cleared'] = cache_cleared
        
        return Response(result)
        
    except Exception as e:
        return Response({
            'error': str(e)
        }, status=500)


@method_decorator(cache_page(60), name='dispatch')  # Cache for 1 minute
class PerformanceMetricsView(View):
    """
    Lightweight performance metrics endpoint for monitoring systems.
    """
    
    def get(self, request):
        """Get basic performance metrics."""
        try:
            metrics = get_performance_metrics()
            db_health = get_database_health()
            
            # Simplified response for monitoring
            response_data = {
                'status': 'healthy' if db_health.get('status') == 'healthy' else 'unhealthy',
                'timestamp': time.time(),
                'response_time_avg': metrics.get('avg_response_time', 0),
                'database_healthy': db_health.get('status') == 'healthy',
                'active_connections': db_health.get('active_connections', 0),
                'cache_hit_ratio': db_health.get('cache_hit_ratio', 0),
            }
            
            return JsonResponse(response_data)
            
        except Exception as e:
            return JsonResponse({
                'status': 'error',
                'error': str(e),
                'timestamp': time.time()
            }, status=500)


def calculate_health_score(performance_metrics, db_health, cache_stats, connection_stats):
    """
    Calculate overall system health score (0-100).
    """
    score = 100
    
    # Database health
    if db_health.get('status') != 'healthy':
        score -= 30
    
    # Response time penalty
    avg_response_time = performance_metrics.get('avg_response_time', 0)
    if avg_response_time > 2.0:  # >2 seconds
        score -= 20
    elif avg_response_time > 1.0:  # >1 second
        score -= 10
    
    # Database connection penalty
    active_connections = connection_stats.get('active_connections', 0)
    if active_connections > 50:
        score -= 15
    elif active_connections > 30:
        score -= 5
    
    # Cache hit rate bonus/penalty
    cache_hit_rate = cache_stats.get('hit_rate_percent', 0)
    if cache_hit_rate < 50:
        score -= 15
    elif cache_hit_rate > 90:
        score += 5
    
    # Long running queries penalty
    longest_query = connection_stats.get('longest_query_seconds', 0)
    if longest_query > 30:
        score -= 20
    elif longest_query > 10:
        score -= 10
    
    # Error rate penalty
    error_count = performance_metrics.get('slow_requests', 0)
    total_requests = performance_metrics.get('requests', 1)
    error_rate = (error_count / total_requests) * 100
    
    if error_rate > 5:
        score -= 25
    elif error_rate > 1:
        score -= 10
    
    return max(0, min(100, score))


def get_performance_recommendations(performance_metrics, db_health, cache_stats):
    """
    Generate performance recommendations based on metrics.
    """
    recommendations = []
    
    # Response time recommendations
    avg_response_time = performance_metrics.get('avg_response_time', 0)
    if avg_response_time > 1.0:
        recommendations.append({
            'type': 'performance',
            'priority': 'high',
            'message': f'Average response time is {avg_response_time:.2f}s. Consider optimizing slow queries and adding caching.',
            'action': 'optimize_queries'
        })
    
    # Database recommendations
    if db_health.get('status') != 'healthy':
        recommendations.append({
            'type': 'database',
            'priority': 'critical',
            'message': 'Database health check failed. Check connection and query performance.',
            'action': 'check_database'
        })
    
    # Cache recommendations
    cache_hit_rate = cache_stats.get('hit_rate_percent', 0)
    if cache_hit_rate < 70:
        recommendations.append({
            'type': 'cache',
            'priority': 'medium',
            'message': f'Cache hit rate is {cache_hit_rate:.1f}%. Consider improving caching strategy.',
            'action': 'improve_caching'
        })
    
    # Connection recommendations
    if db_health.get('active_connections', 0) > 30:
        recommendations.append({
            'type': 'database',
            'priority': 'medium',
            'message': f'High number of active database connections ({db_health["active_connections"]}). Consider connection pooling optimization.',
            'action': 'optimize_connections'
        })
    
    # Query recommendations
    queries_per_request = performance_metrics.get('avg_queries_per_request', 0)
    if queries_per_request > 10:
        recommendations.append({
            'type': 'queries',
            'priority': 'medium',
            'message': f'Average {queries_per_request:.1f} queries per request. Consider query optimization and eager loading.',
            'action': 'optimize_queries'
        })
    
    return recommendations


# URL patterns for performance monitoring
from django.urls import path

performance_urlpatterns = [
    path('api/performance/dashboard/', performance_dashboard, name='performance_dashboard'),
    path('api/performance/slow-queries/', slow_queries, name='slow_queries'),
    path('api/performance/indexes/', index_analysis, name='index_analysis'),
    path('api/performance/optimize/', optimize_database, name='optimize_database'),
    path('api/performance/metrics/', PerformanceMetricsView.as_view(), name='performance_metrics'),
]