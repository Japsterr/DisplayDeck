"""
WebSocket routing configuration for DisplayDeck.

Defines WebSocket URL patterns and routing for real-time communication
between display devices, admin dashboard, and the backend system.
"""

from django.urls import re_path, path
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from channels.security.websocket import AllowedHostsOriginValidator

from apps.common.consumers import DisplayConsumer, AdminDashboardConsumer
from apps.common.middleware import DisplayTokenAuthMiddleware

# WebSocket URL patterns
websocket_urlpatterns = [
    # Display device WebSocket connections
    re_path(r'ws/displays/(?P<display_id>[0-9a-f-]+)/$', 
            DisplayConsumer.as_asgi(), 
            name='display_websocket'),
    
    # Admin dashboard WebSocket connections
    re_path(r'ws/admin/businesses/(?P<business_id>[0-9a-f-]+)/$', 
            AdminDashboardConsumer.as_asgi(), 
            name='admin_websocket'),
    
    # Business-wide notifications (for all admins)
    re_path(r'ws/businesses/(?P<business_id>[0-9a-f-]+)/notifications/$', 
            AdminDashboardConsumer.as_asgi(), 
            name='business_notifications'),
]

# Main application routing
application = ProtocolTypeRouter({
    # WebSocket connections
    'websocket': AllowedHostsOriginValidator(
        AuthMiddlewareStack(
            URLRouter(websocket_urlpatterns)
        )
    ),
    
    # HTTP connections are handled by Django's WSGI application
    # 'http': get_asgi_application(),
})

# Alternative routing for different authentication patterns
display_websocket_urlpatterns = [
    # Display connections use token authentication
    re_path(r'ws/displays/(?P<display_id>[0-9a-f-]+)/$', 
            DisplayConsumer.as_asgi()),
]

admin_websocket_urlpatterns = [
    # Admin connections use session authentication
    re_path(r'ws/admin/businesses/(?P<business_id>[0-9a-f-]+)/$', 
            AdminDashboardConsumer.as_asgi()),
    re_path(r'ws/businesses/(?P<business_id>[0-9a-f-]+)/notifications/$', 
            AdminDashboardConsumer.as_asgi()),
]

# Combined routing with custom auth middleware
display_application = ProtocolTypeRouter({
    'websocket': AllowedHostsOriginValidator(
        DisplayTokenAuthMiddleware(
            URLRouter(display_websocket_urlpatterns)
        )
    ),
})

admin_application = ProtocolTypeRouter({
    'websocket': AllowedHostsOriginValidator(
        AuthMiddlewareStack(
            URLRouter(admin_websocket_urlpatterns)
        )
    ),
})

# Final application combining both
combined_application = ProtocolTypeRouter({
    'websocket': AllowedHostsOriginValidator(
        URLRouter([
            # Display connections (token auth)
            re_path(r'ws/displays/', 
                   DisplayTokenAuthMiddleware(
                       URLRouter(display_websocket_urlpatterns)
                   )),
            
            # Admin connections (session auth)  
            re_path(r'ws/(admin|businesses)/', 
                   AuthMiddlewareStack(
                       URLRouter(admin_websocket_urlpatterns)
                   )),
        ])
    ),
})