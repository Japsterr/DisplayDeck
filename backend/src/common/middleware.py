"""
Django middleware for automatic tenant context detection and management.

This middleware automatically detects the tenant context based on various methods:
1. Subdomain-based tenant resolution (e.g., tenant1.displaydeck.com)
2. Custom header-based tenant resolution (X-Tenant-ID)
3. API key-based tenant resolution for service-to-service calls
4. User-based tenant resolution for authenticated requests
"""

import logging
import re
from django.http import HttpResponseBadRequest, JsonResponse
from django.utils.deprecation import MiddlewareMixin
from django.core.cache import cache
from django.conf import settings
from apps.businesses.models import BusinessAccount, BusinessMember
from apps.authentication.models import User

logger = logging.getLogger(__name__)


class TenantContext:
    """Thread-local tenant context manager"""
    
    def __init__(self):
        self._tenant = None
        self._user = None
        
    def set_tenant(self, tenant):
        self._tenant = tenant
        
    def get_tenant(self):
        return self._tenant
        
    def set_user(self, user):
        self._user = user
        
    def get_user(self):
        return self._user
        
    def clear(self):
        self._tenant = None
        self._user = None


# Thread-local tenant context
tenant_context = TenantContext()


class TenantMiddleware(MiddlewareMixin):
    """
    Middleware for automatic tenant context detection and management.
    
    This middleware must be placed early in the middleware stack, preferably
    after authentication middleware but before any business logic middleware.
    """
    
    TENANT_CACHE_TIMEOUT = 300  # 5 minutes
    SUBDOMAIN_PATTERN = re.compile(r'^([a-zA-Z0-9-]+)\.', re.IGNORECASE)
    
    def __init__(self, get_response=None):
        self.get_response = get_response
        super().__init__(get_response)
        
    def process_request(self, request):
        """Process incoming request to determine tenant context"""
        
        try:
            # Clear any previous tenant context
            tenant_context.clear()
            
            # Skip tenant resolution for certain paths
            if self._should_skip_tenant_resolution(request):
                return None
            
            tenant = None
            
            # Method 1: Subdomain-based tenant resolution
            if not tenant and hasattr(settings, 'ENABLE_SUBDOMAIN_TENANTS') and settings.ENABLE_SUBDOMAIN_TENANTS:
                tenant = self._resolve_tenant_by_subdomain(request)
            
            # Method 2: Custom header-based tenant resolution
            if not tenant:
                tenant = self._resolve_tenant_by_header(request)
            
            # Method 3: API key-based tenant resolution
            if not tenant:
                tenant = self._resolve_tenant_by_api_key(request)
            
            # Method 4: User-based tenant resolution (for authenticated users)
            if not tenant and hasattr(request, 'user') and request.user.is_authenticated:
                tenant = self._resolve_tenant_by_user(request)
            
            # Set tenant context
            if tenant:
                tenant_context.set_tenant(tenant)
                request.tenant = tenant
                
                # Add tenant info to logs
                logger.debug(f"Tenant context set: {tenant.slug} (ID: {tenant.id})")
            else:
                # For public endpoints, no tenant is required
                request.tenant = None
                logger.debug("No tenant context required for this request")
                
        except Exception as e:
            logger.error(f"Error in tenant resolution: {str(e)}")
            return JsonResponse({
                'error': 'Tenant resolution failed',
                'message': 'Unable to determine tenant context'
            }, status=400)
        
        return None
    
    def process_response(self, request, response):
        """Clean up tenant context after request processing"""
        tenant_context.clear()
        return response
    
    def _should_skip_tenant_resolution(self, request):
        """Check if tenant resolution should be skipped for this request"""
        
        skip_paths = [
            '/admin/',
            '/health/',
            '/api/v1/auth/login/',
            '/api/v1/auth/register/',
            '/api/v1/auth/refresh/',
            '/static/',
            '/media/',
            '/favicon.ico',
            '/robots.txt',
            '/sitemap.xml'
        ]
        
        # Skip for certain paths
        for path in skip_paths:
            if request.path.startswith(path):
                return True
        
        # Skip for non-API requests in development
        if settings.DEBUG and not request.path.startswith('/api/'):
            return True
            
        return False
    
    def _resolve_tenant_by_subdomain(self, request):
        """Resolve tenant by subdomain (e.g., tenant1.displaydeck.com)"""
        
        try:
            host = request.get_host()
            if not host:
                return None
            
            # Extract subdomain
            match = self.SUBDOMAIN_PATTERN.match(host)
            if not match:
                return None
            
            subdomain = match.group(1).lower()
            
            # Skip common subdomains
            if subdomain in ['www', 'api', 'app', 'admin', 'static', 'media']:
                return None
            
            # Cache lookup
            cache_key = f"tenant_subdomain_{subdomain}"
            tenant = cache.get(cache_key)
            
            if tenant is None:
                # Database lookup
                try:
                    tenant = BusinessAccount.objects.get(
                        slug=subdomain,
                        is_active=True
                    )
                    cache.set(cache_key, tenant, self.TENANT_CACHE_TIMEOUT)
                except BusinessAccount.DoesNotExist:
                    # Cache the negative result to avoid repeated DB queries
                    cache.set(cache_key, False, 60)  # Cache for 1 minute
                    return None
            
            return tenant if tenant else None
            
        except Exception as e:
            logger.warning(f"Error resolving tenant by subdomain: {str(e)}")
            return None
    
    def _resolve_tenant_by_header(self, request):
        """Resolve tenant by X-Tenant-ID header"""
        
        try:
            tenant_header = request.META.get('HTTP_X_TENANT_ID')
            if not tenant_header:
                return None
            
            # Support both ID and slug
            cache_key = f"tenant_header_{tenant_header}"
            tenant = cache.get(cache_key)
            
            if tenant is None:
                try:
                    # Try as integer ID first
                    if tenant_header.isdigit():
                        tenant = BusinessAccount.objects.get(
                            id=int(tenant_header),
                            is_active=True
                        )
                    else:
                        # Try as slug
                        tenant = BusinessAccount.objects.get(
                            slug=tenant_header.lower(),
                            is_active=True
                        )
                    
                    cache.set(cache_key, tenant, self.TENANT_CACHE_TIMEOUT)
                except BusinessAccount.DoesNotExist:
                    cache.set(cache_key, False, 60)
                    return None
            
            return tenant if tenant else None
            
        except Exception as e:
            logger.warning(f"Error resolving tenant by header: {str(e)}")
            return None
    
    def _resolve_tenant_by_api_key(self, request):
        """Resolve tenant by API key for service-to-service calls"""
        
        try:
            api_key = request.META.get('HTTP_X_API_KEY')
            if not api_key:
                return None
            
            # Cache lookup for API key
            cache_key = f"tenant_api_key_{api_key[:8]}..."  # Truncate for security
            tenant = cache.get(cache_key)
            
            if tenant is None:
                # In a real implementation, you would have an API key model
                # For now, we'll skip this resolution method
                return None
            
            return tenant if tenant else None
            
        except Exception as e:
            logger.warning(f"Error resolving tenant by API key: {str(e)}")
            return None
    
    def _resolve_tenant_by_user(self, request):
        """Resolve tenant by authenticated user's business memberships"""
        
        try:
            user = request.user
            if not user or not user.is_authenticated:
                return None
            
            # Cache user's primary tenant
            cache_key = f"user_primary_tenant_{user.id}"
            tenant = cache.get(cache_key)
            
            if tenant is None:
                # Get user's primary business membership
                try:
                    membership = BusinessMember.objects.select_related('business').filter(
                        user=user,
                        is_active=True,
                        business__is_active=True
                    ).order_by('-role', '-created_at').first()
                    
                    if membership:
                        tenant = membership.business
                        cache.set(cache_key, tenant, self.TENANT_CACHE_TIMEOUT)
                    else:
                        cache.set(cache_key, False, 60)
                        
                except Exception as e:
                    logger.warning(f"Error getting user's primary tenant: {str(e)}")
                    return None
            
            return tenant if tenant else None
            
        except Exception as e:
            logger.warning(f"Error resolving tenant by user: {str(e)}")
            return None


def get_current_tenant():
    """Get the current tenant from context"""
    return tenant_context.get_tenant()


def get_current_user():
    """Get the current user from context"""
    return tenant_context.get_user()


def require_tenant(view_func):
    """Decorator to require tenant context for a view"""
    
    def wrapper(request, *args, **kwargs):
        if not hasattr(request, 'tenant') or not request.tenant:
            return JsonResponse({
                'error': 'Tenant required',
                'message': 'This endpoint requires a valid tenant context'
            }, status=400)
        
        return view_func(request, *args, **kwargs)
    
    return wrapper


class TenantAwareQuerySet:
    """Mixin for QuerySets to automatically filter by tenant"""
    
    def for_tenant(self, tenant=None):
        """Filter queryset for specific tenant"""
        if tenant is None:
            tenant = get_current_tenant()
        
        if tenant:
            # Assuming models have a 'business' foreign key
            return self.filter(business=tenant)
        
        return self.none()


class TenantAwareModel:
    """Mixin for models to add tenant-aware methods"""
    
    def is_accessible_by_tenant(self, tenant=None):
        """Check if this model instance is accessible by the given tenant"""
        if tenant is None:
            tenant = get_current_tenant()
        
        if not tenant:
            return False
        
        # Assuming models have a 'business' foreign key
        return hasattr(self, 'business') and self.business == tenant
    
    @classmethod
    def get_for_tenant(cls, tenant=None):
        """Get queryset filtered for tenant"""
        if tenant is None:
            tenant = get_current_tenant()
        
        if tenant and hasattr(cls, 'objects'):
            return cls.objects.filter(business=tenant)
        
        return cls.objects.none()