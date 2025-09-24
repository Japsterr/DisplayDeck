"""
Comprehensive health check endpoints for DisplayDeck services.

This module provides health monitoring for all system components including
database, cache, external services, and application-specific health metrics.
"""

import logging
import json
import time
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from django.http import JsonResponse
from django.db import connection
from django.core.cache import cache
from django.conf import settings
from django.utils import timezone
from django.db.models import Count
from apps.businesses.models import BusinessAccount
from apps.displays.models import DisplayDevice
from apps.menus.models import Menu
from apps.authentication.models import User

logger = logging.getLogger(__name__)


class HealthChecker:
    """Main health checker class"""
    
    def __init__(self):
        self.checks = {}
        
    def add_check(self, name: str, check_func, critical: bool = True):
        """Add a health check function"""
        self.checks[name] = {
            'func': check_func,
            'critical': critical
        }
    
    def run_all_checks(self) -> Dict[str, Any]:
        """Run all health checks and return results"""
        results = {
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'checks': {},
            'summary': {
                'total': len(self.checks),
                'passed': 0,
                'failed': 0,
                'warnings': 0
            }
        }
        
        overall_healthy = True
        
        for check_name, check_config in self.checks.items():
            start_time = time.time()
            
            try:
                check_result = check_config['func']()
                duration = time.time() - start_time
                
                result = {
                    'status': 'pass' if check_result.get('healthy', True) else 'fail',
                    'duration_ms': round(duration * 1000, 2),
                    'critical': check_config['critical'],
                    **check_result
                }
                
                if result['status'] == 'pass':
                    results['summary']['passed'] += 1
                else:
                    results['summary']['failed'] += 1
                    if check_config['critical']:
                        overall_healthy = False
                    else:
                        results['summary']['warnings'] += 1
                        
            except Exception as e:
                duration = time.time() - start_time
                logger.error(f"Health check '{check_name}' failed with exception: {str(e)}")
                
                result = {
                    'status': 'fail',
                    'duration_ms': round(duration * 1000, 2),
                    'critical': check_config['critical'],
                    'healthy': False,
                    'error': str(e)
                }
                
                results['summary']['failed'] += 1
                if check_config['critical']:
                    overall_healthy = False
                else:
                    results['summary']['warnings'] += 1
            
            results['checks'][check_name] = result
        
        results['status'] = 'healthy' if overall_healthy else 'unhealthy'
        return results


# Initialize health checker
health_checker = HealthChecker()


def check_database():
    """Check database connectivity and performance"""
    try:
        start_time = time.time()
        
        # Test basic connectivity
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        
        # Check connection pool
        connections_used = len([conn for conn in connection.queries])
        
        # Test a simple query performance
        query_start = time.time()
        user_count = User.objects.count()
        query_duration = time.time() - query_start
        
        duration = time.time() - start_time
        
        return {
            'healthy': True,
            'database_engine': connection.vendor,
            'connections_used': connections_used,
            'query_duration_ms': round(query_duration * 1000, 2),
            'user_count': user_count,
            'message': 'Database is accessible and responsive'
        }
        
    except Exception as e:
        return {
            'healthy': False,
            'error': str(e),
            'message': 'Database connectivity failed'
        }


def check_cache():
    """Check Redis cache connectivity and performance"""
    try:
        test_key = 'health_check_test'
        test_value = f'test_{int(time.time())}'
        
        # Test write
        cache.set(test_key, test_value, 30)
        
        # Test read
        retrieved_value = cache.get(test_key)
        
        if retrieved_value != test_value:
            return {
                'healthy': False,
                'message': 'Cache write/read test failed',
                'expected': test_value,
                'actual': retrieved_value
            }
        
        # Clean up test key
        cache.delete(test_key)
        
        # Get cache statistics if available
        cache_stats = {}
        try:
            from django_redis import get_redis_connection
            redis_conn = get_redis_connection("default")
            info = redis_conn.info()
            cache_stats = {
                'connected_clients': info.get('connected_clients', 0),
                'used_memory_human': info.get('used_memory_human', 'unknown'),
                'keyspace_hits': info.get('keyspace_hits', 0),
                'keyspace_misses': info.get('keyspace_misses', 0)
            }
        except Exception:
            pass
        
        return {
            'healthy': True,
            'message': 'Cache is accessible and functional',
            'stats': cache_stats
        }
        
    except Exception as e:
        return {
            'healthy': False,
            'error': str(e),
            'message': 'Cache connectivity failed'
        }


def check_websockets():
    """Check WebSocket channel layer connectivity"""
    try:
        from channels.layers import get_channel_layer
        
        channel_layer = get_channel_layer()
        if channel_layer is None:
            return {
                'healthy': False,
                'message': 'Channel layer not configured'
            }
        
        # Test channel layer (basic connectivity)
        # Note: Full WebSocket testing would require more complex setup
        
        return {
            'healthy': True,
            'message': 'WebSocket channel layer is configured',
            'backend': getattr(channel_layer, 'config', {}).get('hosts', 'unknown')
        }
        
    except Exception as e:
        return {
            'healthy': False,
            'error': str(e),
            'message': 'WebSocket check failed'
        }


def check_display_devices():
    """Check display device connectivity and health"""
    try:
        total_displays = DisplayDevice.objects.count()
        online_displays = DisplayDevice.objects.filter(is_online=True).count()
        
        # Check for displays that haven't been seen recently (last 5 minutes)
        five_minutes_ago = timezone.now() - timedelta(minutes=5)
        stale_displays = DisplayDevice.objects.filter(
            is_active=True,
            last_seen__lt=five_minutes_ago
        ).count()
        
        # Get display health statistics
        critical_displays = DisplayDevice.objects.filter(
            health_status__contains='critical'
        ).count()
        
        health_good = total_displays > 0 and stale_displays == 0 and critical_displays == 0
        
        message = f"{online_displays}/{total_displays} displays online"
        if stale_displays > 0:
            message += f", {stale_displays} stale"
        if critical_displays > 0:
            message += f", {critical_displays} critical"
        
        return {
            'healthy': health_good,
            'total_displays': total_displays,
            'online_displays': online_displays,
            'stale_displays': stale_displays,
            'critical_displays': critical_displays,
            'message': message
        }
        
    except Exception as e:
        return {
            'healthy': False,
            'error': str(e),
            'message': 'Display device check failed'
        }


def check_business_data():
    """Check business and menu data integrity"""
    try:
        business_count = BusinessAccount.objects.filter(is_active=True).count()
        menu_count = Menu.objects.filter(is_active=True).count()
        
        # Check for businesses without menus
        businesses_without_menus = BusinessAccount.objects.filter(
            is_active=True
        ).annotate(
            menu_count=Count('menus')
        ).filter(menu_count=0).count()
        
        # Check for recent activity (users created in last 24 hours)
        yesterday = timezone.now() - timedelta(days=1)
        recent_users = User.objects.filter(date_joined__gte=yesterday).count()
        
        health_good = business_count > 0 and menu_count > 0
        
        return {
            'healthy': health_good,
            'active_businesses': business_count,
            'active_menus': menu_count,
            'businesses_without_menus': businesses_without_menus,
            'recent_new_users': recent_users,
            'message': f"{business_count} businesses, {menu_count} menus"
        }
        
    except Exception as e:
        return {
            'healthy': False,
            'error': str(e),
            'message': 'Business data check failed'
        }


def check_disk_space():
    """Check available disk space"""
    try:
        import shutil
        
        # Check main disk usage
        disk_usage = shutil.disk_usage('/')
        total_gb = disk_usage.total / (1024**3)
        free_gb = disk_usage.free / (1024**3)
        used_gb = (disk_usage.total - disk_usage.free) / (1024**3)
        usage_percent = (used_gb / total_gb) * 100
        
        # Check media directory if it exists
        media_usage = None
        try:
            if hasattr(settings, 'MEDIA_ROOT'):
                media_disk = shutil.disk_usage(settings.MEDIA_ROOT)
                media_usage = {
                    'total_gb': round(media_disk.total / (1024**3), 2),
                    'free_gb': round(media_disk.free / (1024**3), 2),
                    'usage_percent': round(((media_disk.total - media_disk.free) / media_disk.total) * 100, 2)
                }
        except Exception:
            pass
        
        # Determine health based on usage
        health_good = usage_percent < 85  # Alert if > 85% full
        
        return {
            'healthy': health_good,
            'total_gb': round(total_gb, 2),
            'free_gb': round(free_gb, 2),
            'used_gb': round(used_gb, 2),
            'usage_percent': round(usage_percent, 2),
            'media_usage': media_usage,
            'message': f"Disk usage: {round(usage_percent, 1)}%"
        }
        
    except Exception as e:
        return {
            'healthy': False,
            'error': str(e),
            'message': 'Disk space check failed'
        }


def check_memory_usage():
    """Check memory usage"""
    try:
        import psutil
        
        memory = psutil.virtual_memory()
        
        # Convert to GB for readability
        total_gb = memory.total / (1024**3)
        available_gb = memory.available / (1024**3)
        used_gb = (memory.total - memory.available) / (1024**3)
        usage_percent = memory.percent
        
        # Check health
        health_good = usage_percent < 85
        
        return {
            'healthy': health_good,
            'total_gb': round(total_gb, 2),
            'available_gb': round(available_gb, 2),
            'used_gb': round(used_gb, 2),
            'usage_percent': round(usage_percent, 2),
            'message': f"Memory usage: {round(usage_percent, 1)}%"
        }
        
    except ImportError:
        return {
            'healthy': True,
            'message': 'Memory monitoring not available (psutil not installed)',
            'skipped': True
        }
    except Exception as e:
        return {
            'healthy': False,
            'error': str(e),
            'message': 'Memory check failed'
        }


def check_external_services():
    """Check external service dependencies"""
    try:
        import requests
        from urllib.parse import urlparse
        
        external_checks = []
        
        # Check if we're configured to use external services
        # This would be customized based on your actual external dependencies
        
        # Example: Check a hypothetical external API
        # if hasattr(settings, 'EXTERNAL_API_URL'):
        #     try:
        #         response = requests.get(
        #             f"{settings.EXTERNAL_API_URL}/health",
        #             timeout=5
        #         )
        #         external_checks.append({
        #             'service': 'External API',
        #             'status': 'healthy' if response.status_code == 200 else 'unhealthy',
        #             'response_time_ms': response.elapsed.total_seconds() * 1000
        #         })
        #     except Exception as e:
        #         external_checks.append({
        #             'service': 'External API',
        #             'status': 'error',
        #             'error': str(e)
        #         })
        
        return {
            'healthy': True,
            'external_services': external_checks,
            'message': f"Checked {len(external_checks)} external services"
        }
        
    except Exception as e:
        return {
            'healthy': False,
            'error': str(e),
            'message': 'External service check failed'
        }


# Register all health checks
health_checker.add_check('database', check_database, critical=True)
health_checker.add_check('cache', check_cache, critical=True)
health_checker.add_check('websockets', check_websockets, critical=False)
health_checker.add_check('display_devices', check_display_devices, critical=False)
health_checker.add_check('business_data', check_business_data, critical=False)
health_checker.add_check('disk_space', check_disk_space, critical=False)
health_checker.add_check('memory_usage', check_memory_usage, critical=False)
health_checker.add_check('external_services', check_external_services, critical=False)


def health_check_view(request):
    """Main health check endpoint"""
    results = health_checker.run_all_checks()
    
    # Determine HTTP status code
    status_code = 200 if results['status'] == 'healthy' else 503
    
    return JsonResponse(results, status=status_code)


def health_check_simple(request):
    """Simple health check that just returns OK if basic services are up"""
    try:
        # Quick database check
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        
        # Quick cache check
        cache.set('simple_health_check', 'ok', 10)
        
        return JsonResponse({
            'status': 'ok',
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        return JsonResponse({
            'status': 'error',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }, status=503)


def health_check_detailed(request):
    """Detailed health check with additional metrics"""
    results = health_checker.run_all_checks()
    
    # Add additional system information
    results['system_info'] = {
        'django_version': getattr(settings, 'DJANGO_VERSION', 'unknown'),
        'python_version': __import__('sys').version,
        'debug_mode': settings.DEBUG,
        'timezone': str(timezone.get_current_timezone()),
        'installed_apps': len(settings.INSTALLED_APPS),
        'middleware': len(settings.MIDDLEWARE)
    }
    
    # Add performance metrics
    results['performance'] = {
        'total_check_duration_ms': sum([
            check['duration_ms'] for check in results['checks'].values()
        ]),
        'slowest_check': max(
            results['checks'].items(),
            key=lambda x: x[1]['duration_ms']
        )[0] if results['checks'] else None
    }
    
    status_code = 200 if results['status'] == 'healthy' else 503
    return JsonResponse(results, status=status_code)


def liveness_probe(request):
    """Kubernetes liveness probe - basic application responsiveness"""
    return JsonResponse({
        'status': 'alive',
        'timestamp': datetime.now().isoformat()
    })


def readiness_probe(request):
    """Kubernetes readiness probe - check if ready to serve traffic"""
    try:
        # Check critical dependencies only
        db_check = check_database()
        cache_check = check_cache()
        
        if db_check['healthy'] and cache_check['healthy']:
            return JsonResponse({
                'status': 'ready',
                'timestamp': datetime.now().isoformat()
            })
        else:
            return JsonResponse({
                'status': 'not_ready',
                'database': db_check['healthy'],
                'cache': cache_check['healthy'],
                'timestamp': datetime.now().isoformat()
            }, status=503)
            
    except Exception as e:
        return JsonResponse({
            'status': 'not_ready',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }, status=503)