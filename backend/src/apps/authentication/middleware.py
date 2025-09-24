"""
Cross-platform API token authentication middleware.

This middleware provides consistent authentication across web, mobile, and Android TV platforms
by supporting multiple authentication methods:
1. JWT Bearer tokens (for web and mobile)
2. API keys (for service-to-service calls)
3. Display tokens (for Android TV displays)
4. Session authentication (for web admin interface)
"""

import logging
import jwt
from datetime import datetime, timedelta
from django.http import JsonResponse
from django.utils.deprecation import MiddlewareMixin
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.conf import settings
from apps.authentication.models import User
from apps.displays.models import DisplayDevice
from apps.businesses.models import BusinessAccount

logger = logging.getLogger(__name__)
User = get_user_model()


class CrossPlatformAuthMiddleware(MiddlewareMixin):
    """
    Middleware for handling authentication across all platforms.
    
    This middleware should be placed after Django's AuthenticationMiddleware
    in the middleware stack.
    """
    
    def __init__(self, get_response=None):
        self.get_response = get_response
        super().__init__(get_response)
        
    def process_request(self, request):
        """Process authentication for incoming requests"""
        
        try:
            # Skip authentication for certain paths
            if self._should_skip_auth(request):
                return None
            
            auth_result = None
            
            # Try different authentication methods in order
            
            # Method 1: JWT Bearer token authentication
            auth_result = self._authenticate_jwt_bearer(request)
            
            # Method 2: API Key authentication (for service-to-service)
            if not auth_result:
                auth_result = self._authenticate_api_key(request)
            
            # Method 3: Display token authentication (for Android TV)
            if not auth_result:
                auth_result = self._authenticate_display_token(request)
            
            # Method 4: Session authentication (fallback for web admin)
            if not auth_result and hasattr(request, 'user') and request.user.is_authenticated:
                auth_result = {
                    'user': request.user,
                    'platform': 'web',
                    'auth_method': 'session'
                }
            
            # Set authentication info on request
            if auth_result:
                request.auth_user = auth_result['user']
                request.auth_platform = auth_result.get('platform', 'unknown')
                request.auth_method = auth_result.get('auth_method', 'unknown')
                
                # Set user for Django compatibility
                if not hasattr(request, 'user') or not request.user.is_authenticated:
                    request.user = auth_result['user']
                    
                logger.debug(f"Authenticated user: {auth_result['user'].email} "
                           f"via {auth_result['auth_method']} ({auth_result.get('platform')})")
            else:
                # Set anonymous user
                request.auth_user = None
                request.auth_platform = None
                request.auth_method = None
                
        except Exception as e:
            logger.error(f"Authentication error: {str(e)}")
            return JsonResponse({
                'error': 'Authentication failed',
                'message': 'Unable to process authentication'
            }, status=401)
        
        return None
    
    def _should_skip_auth(self, request):
        """Check if authentication should be skipped for this request"""
        
        skip_paths = [
            '/admin/',
            '/health/',
            '/api/v1/auth/login/',
            '/api/v1/auth/register/',
            '/api/v1/auth/refresh/',
            '/static/',
            '/media/',
            '/favicon.ico',
            '/robots.txt'
        ]
        
        # Skip for certain paths
        for path in skip_paths:
            if request.path.startswith(path):
                return True
                
        # Skip for OPTIONS requests (CORS preflight)
        if request.method == 'OPTIONS':
            return True
            
        return False
    
    def _authenticate_jwt_bearer(self, request):
        """Authenticate using JWT Bearer token"""
        
        try:
            # Get Authorization header
            auth_header = request.META.get('HTTP_AUTHORIZATION')
            if not auth_header or not auth_header.startswith('Bearer '):
                return None
            
            # Extract token
            token = auth_header[7:]  # Remove 'Bearer ' prefix
            
            # Check cache first
            cache_key = f"jwt_auth_{token[:16]}..."  # Truncate for security
            cached_result = cache.get(cache_key)
            if cached_result:
                return cached_result
            
            # Decode and verify JWT
            try:
                payload = jwt.decode(
                    token,
                    settings.SECRET_KEY,
                    algorithms=['HS256']
                )
            except jwt.ExpiredSignatureError:
                logger.debug("JWT token has expired")
                return None
            except jwt.InvalidTokenError as e:
                logger.debug(f"Invalid JWT token: {str(e)}")
                return None
            
            # Get user from token payload
            user_id = payload.get('user_id')
            if not user_id:
                return None
            
            try:
                user = User.objects.get(id=user_id, is_active=True)
            except User.DoesNotExist:
                return None
            
            # Determine platform from token payload or user agent
            platform = payload.get('platform', self._detect_platform_from_user_agent(request))
            
            auth_result = {
                'user': user,
                'platform': platform,
                'auth_method': 'jwt_bearer',
                'token_payload': payload
            }
            
            # Cache the result for a short time
            cache.set(cache_key, auth_result, 300)  # 5 minutes
            
            return auth_result
            
        except Exception as e:
            logger.warning(f"JWT authentication error: {str(e)}")
            return None
    
    def _authenticate_api_key(self, request):
        """Authenticate using API key for service-to-service calls"""
        
        try:
            # Get API key from header
            api_key = request.META.get('HTTP_X_API_KEY')
            if not api_key:
                return None
            
            # Check cache first
            cache_key = f"api_key_auth_{api_key[:8]}..."  # Truncate for security
            cached_result = cache.get(cache_key)
            if cached_result:
                return cached_result
            
            # In a real implementation, you would have an APIKey model
            # For now, we'll use a simple check against settings
            valid_api_keys = getattr(settings, 'VALID_API_KEYS', {})
            
            if api_key not in valid_api_keys:
                return None
            
            # Get associated user or create service user
            service_config = valid_api_keys[api_key]
            user_email = service_config.get('user_email')
            
            if user_email:
                try:
                    user = User.objects.get(email=user_email, is_active=True)
                except User.DoesNotExist:
                    return None
            else:
                # Create or get service user
                user, _ = User.objects.get_or_create(
                    email='service@displaydeck.com',
                    defaults={
                        'first_name': 'Service',
                        'last_name': 'Account',
                        'is_active': True,
                        'is_staff': False
                    }
                )
            
            auth_result = {
                'user': user,
                'platform': 'service',
                'auth_method': 'api_key',
                'api_key_config': service_config
            }
            
            # Cache the result
            cache.set(cache_key, auth_result, 3600)  # 1 hour
            
            return auth_result
            
        except Exception as e:
            logger.warning(f"API key authentication error: {str(e)}")
            return None
    
    def _authenticate_display_token(self, request):
        """Authenticate display device using display token"""
        
        try:
            # Get display token from header
            display_token = request.META.get('HTTP_X_DISPLAY_TOKEN')
            if not display_token:
                return None
            
            # Check cache first
            cache_key = f"display_auth_{display_token[:16]}..."
            cached_result = cache.get(cache_key)
            if cached_result:
                return cached_result
            
            # Find display device by token
            try:
                display = DisplayDevice.objects.select_related('business').get(
                    auth_token=display_token,
                    is_active=True,
                    business__is_active=True
                )
            except DisplayDevice.DoesNotExist:
                return None
            
            # Create or get display service user
            user, _ = User.objects.get_or_create(
                email=f'display-{display.id}@displaydeck.com',
                defaults={
                    'first_name': f'Display',
                    'last_name': display.name,
                    'is_active': True,
                    'is_staff': False
                }
            )
            
            auth_result = {
                'user': user,
                'platform': 'android_tv',
                'auth_method': 'display_token',
                'display': display,
                'business': display.business
            }
            
            # Cache the result
            cache.set(cache_key, auth_result, 1800)  # 30 minutes
            
            # Update display last seen
            display.last_seen = datetime.now()
            display.save(update_fields=['last_seen'])
            
            return auth_result
            
        except Exception as e:
            logger.warning(f"Display token authentication error: {str(e)}")
            return None
    
    def _detect_platform_from_user_agent(self, request):
        """Detect platform from User-Agent header"""
        
        user_agent = request.META.get('HTTP_USER_AGENT', '').lower()
        
        if 'expo' in user_agent or 'react-native' in user_agent:
            return 'mobile'
        elif 'android' in user_agent and 'tv' in user_agent:
            return 'android_tv'
        elif any(browser in user_agent for browser in ['chrome', 'firefox', 'safari', 'edge']):
            return 'web'
        else:
            return 'unknown'


def require_auth(auth_methods=None, platforms=None):
    """
    Decorator to require authentication for a view.
    
    Args:
        auth_methods: List of allowed authentication methods
        platforms: List of allowed platforms
    """
    
    def decorator(view_func):
        def wrapper(request, *args, **kwargs):
            # Check if user is authenticated
            if not hasattr(request, 'auth_user') or not request.auth_user:
                return JsonResponse({
                    'error': 'Authentication required',
                    'message': 'This endpoint requires authentication'
                }, status=401)
            
            # Check authentication method if specified
            if auth_methods and request.auth_method not in auth_methods:
                return JsonResponse({
                    'error': 'Authentication method not allowed',
                    'message': f'This endpoint requires one of: {", ".join(auth_methods)}'
                }, status=403)
            
            # Check platform if specified
            if platforms and request.auth_platform not in platforms:
                return JsonResponse({
                    'error': 'Platform not allowed',
                    'message': f'This endpoint is only available for: {", ".join(platforms)}'
                }, status=403)
            
            return view_func(request, *args, **kwargs)
        
        return wrapper
    return decorator


def require_display_auth(view_func):
    """Decorator to require display device authentication"""
    
    def wrapper(request, *args, **kwargs):
        if (not hasattr(request, 'auth_method') or 
            request.auth_method != 'display_token'):
            return JsonResponse({
                'error': 'Display authentication required',
                'message': 'This endpoint requires display device authentication'
            }, status=401)
        
        return view_func(request, *args, **kwargs)
    
    return wrapper


def require_service_auth(view_func):
    """Decorator to require service-to-service authentication"""
    
    def wrapper(request, *args, **kwargs):
        if (not hasattr(request, 'auth_method') or 
            request.auth_method != 'api_key'):
            return JsonResponse({
                'error': 'Service authentication required',
                'message': 'This endpoint requires API key authentication'
            }, status=401)
        
        return view_func(request, *args, **kwargs)
    
    return wrapper


class PlatformSpecificView:
    """Mixin for views that need platform-specific behavior"""
    
    def get_platform_context(self, request):
        """Get platform-specific context for the request"""
        
        context = {
            'platform': getattr(request, 'auth_platform', None),
            'auth_method': getattr(request, 'auth_method', None),
            'user': getattr(request, 'auth_user', None)
        }
        
        # Add platform-specific data
        if hasattr(request, 'display'):
            context['display'] = request.display
            context['business'] = getattr(request.display, 'business', None)
        
        return context
    
    def is_mobile_request(self, request):
        """Check if request is from mobile platform"""
        return getattr(request, 'auth_platform', None) == 'mobile'
    
    def is_web_request(self, request):
        """Check if request is from web platform"""
        return getattr(request, 'auth_platform', None) == 'web'
    
    def is_display_request(self, request):
        """Check if request is from display device"""
        return getattr(request, 'auth_platform', None) == 'android_tv'