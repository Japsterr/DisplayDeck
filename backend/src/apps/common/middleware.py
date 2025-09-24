"""
Custom middleware for WebSocket authentication in DisplayDeck.

Provides authentication middleware for display device token authentication
and admin session authentication for WebSocket connections.
"""

from django.contrib.auth.models import AnonymousUser
from django.contrib.auth import get_user_model
from django.db import close_old_connections
from channels.middleware import BaseMiddleware
from channels.db import database_sync_to_async
from urllib.parse import parse_qs
import jwt
from django.conf import settings

from apps.displays.models import Display

User = get_user_model()


class DisplayTokenAuthMiddleware(BaseMiddleware):
    """
    Authentication middleware for display device WebSocket connections.
    
    Authenticates display devices using device tokens instead of user sessions.
    The display_id is extracted from the URL and the device token from query params
    or headers.
    """
    
    def __init__(self, inner):
        super().__init__(inner)
    
    async def __call__(self, scope, receive, send):
        """Process WebSocket connection with display token authentication."""
        close_old_connections()
        
        # Extract display ID from URL
        display_id = scope['url_route']['kwargs'].get('display_id')
        
        if display_id:
            # Get device token from query parameters or headers
            device_token = self.get_device_token(scope)
            
            if device_token:
                # Validate device token and get display
                display = await self.get_display_by_token(display_id, device_token)
                
                if display:
                    # Set display in scope for consumer access
                    scope['display'] = display
                    scope['authenticated'] = True
                else:
                    scope['display'] = None
                    scope['authenticated'] = False
            else:
                scope['display'] = None
                scope['authenticated'] = False
        else:
            scope['display'] = None
            scope['authenticated'] = False
        
        return await super().__call__(scope, receive, send)
    
    def get_device_token(self, scope):
        """Extract device token from query parameters or headers."""
        # Try query parameters first
        query_string = scope.get('query_string', b'').decode()
        query_params = parse_qs(query_string)
        
        if 'token' in query_params:
            return query_params['token'][0]
        
        # Try headers
        headers = dict(scope.get('headers', []))
        
        # Check Authorization header
        auth_header = headers.get(b'authorization')
        if auth_header:
            auth_value = auth_header.decode()
            if auth_value.startswith('Bearer '):
                return auth_value[7:]  # Remove 'Bearer ' prefix
        
        # Check X-Device-Token header
        device_token_header = headers.get(b'x-device-token')
        if device_token_header:
            return device_token_header.decode()
        
        return None
    
    @database_sync_to_async
    def get_display_by_token(self, display_id, device_token):
        """Validate device token and return display if valid."""
        try:
            display = Display.objects.select_related('business').get(
                id=display_id,
                device_token=device_token,
                is_active=True
            )
            return display
        except Display.DoesNotExist:
            return None


class JWTAuthMiddleware(BaseMiddleware):
    """
    JWT authentication middleware for WebSocket connections.
    
    Authenticates users using JWT tokens for admin dashboard connections.
    """
    
    def __init__(self, inner):
        super().__init__(inner)
    
    async def __call__(self, scope, receive, send):
        """Process WebSocket connection with JWT authentication."""
        close_old_connections()
        
        # Get JWT token
        token = self.get_jwt_token(scope)
        
        if token:
            # Validate JWT and get user
            user = await self.get_user_from_jwt(token)
            scope['user'] = user or AnonymousUser()
        else:
            scope['user'] = AnonymousUser()
        
        return await super().__call__(scope, receive, send)
    
    def get_jwt_token(self, scope):
        """Extract JWT token from query parameters or headers."""
        # Try query parameters first
        query_string = scope.get('query_string', b'').decode()
        query_params = parse_qs(query_string)
        
        if 'token' in query_params:
            return query_params['token'][0]
        
        # Try headers
        headers = dict(scope.get('headers', []))
        
        # Check Authorization header
        auth_header = headers.get(b'authorization')
        if auth_header:
            auth_value = auth_header.decode()
            if auth_value.startswith('Bearer '):
                return auth_value[7:]  # Remove 'Bearer ' prefix
        
        # Check X-Auth-Token header
        auth_token_header = headers.get(b'x-auth-token')
        if auth_token_header:
            return auth_token_header.decode()
        
        return None
    
    @database_sync_to_async
    def get_user_from_jwt(self, token):
        """Validate JWT token and return user if valid."""
        try:
            # Decode JWT token
            payload = jwt.decode(
                token,
                settings.SECRET_KEY,
                algorithms=['HS256']
            )
            
            # Get user ID from payload
            user_id = payload.get('user_id')
            if user_id:
                user = User.objects.get(id=user_id, is_active=True)
                return user
        except (jwt.InvalidTokenError, User.DoesNotExist):
            pass
        
        return None


class SessionAuthMiddleware(BaseMiddleware):
    """
    Session-based authentication middleware for WebSocket connections.
    
    Uses Django session authentication for admin dashboard connections.
    This is an alternative to JWT auth for browsers with session cookies.
    """
    
    def __init__(self, inner):
        super().__init__(inner)
    
    async def __call__(self, scope, receive, send):
        """Process WebSocket connection with session authentication."""
        close_old_connections()
        
        # Get session key from cookies
        session_key = self.get_session_key(scope)
        
        if session_key:
            # Get user from session
            user = await self.get_user_from_session(session_key)
            scope['user'] = user or AnonymousUser()
        else:
            scope['user'] = AnonymousUser()
        
        return await super().__call__(scope, receive, send)
    
    def get_session_key(self, scope):
        """Extract session key from cookies."""
        headers = dict(scope.get('headers', []))
        cookie_header = headers.get(b'cookie')
        
        if cookie_header:
            cookie_string = cookie_header.decode()
            cookies = {}
            
            # Parse cookies
            for chunk in cookie_string.split(';'):
                if '=' in chunk:
                    key, value = chunk.strip().split('=', 1)
                    cookies[key] = value
            
            # Get Django session cookie
            session_key = cookies.get(settings.SESSION_COOKIE_NAME)
            return session_key
        
        return None
    
    @database_sync_to_async
    def get_user_from_session(self, session_key):
        """Get user from Django session."""
        from django.contrib.sessions.models import Session
        from django.contrib.auth import get_user_model
        
        User = get_user_model()
        
        try:
            session = Session.objects.get(session_key=session_key)
            session_data = session.get_decoded()
            user_id = session_data.get('_auth_user_id')
            
            if user_id:
                user = User.objects.get(id=user_id, is_active=True)
                return user
        except (Session.DoesNotExist, User.DoesNotExist):
            pass
        
        return None


class CombinedAuthMiddleware(BaseMiddleware):
    """
    Combined authentication middleware that supports multiple auth methods.
    
    Tries multiple authentication methods in order:
    1. Display device token (for display connections)
    2. JWT token (for API clients)
    3. Session authentication (for browser clients)
    """
    
    def __init__(self, inner):
        super().__init__(inner)
        self.display_auth = DisplayTokenAuthMiddleware(inner)
        self.jwt_auth = JWTAuthMiddleware(inner)
        self.session_auth = SessionAuthMiddleware(inner)
    
    async def __call__(self, scope, receive, send):
        """Process WebSocket connection with combined authentication."""
        close_old_connections()
        
        # Check if this is a display connection
        path = scope.get('path', '')
        if '/ws/displays/' in path:
            # Use display token authentication
            return await self.display_auth(scope, receive, send)
        
        # For admin/dashboard connections, try JWT first, then session
        token = self.jwt_auth.get_jwt_token(scope)
        if token:
            return await self.jwt_auth(scope, receive, send)
        else:
            return await self.session_auth(scope, receive, send)


# Factory function to create middleware stack
def create_websocket_auth_stack():
    """Create a complete WebSocket authentication middleware stack."""
    from channels.auth import AuthMiddlewareStack
    
    # Return the combined auth middleware
    return CombinedAuthMiddleware


# Middleware for specific connection types
def display_auth_middleware():
    """Get middleware for display device connections."""
    return DisplayTokenAuthMiddleware


def admin_auth_middleware():
    """Get middleware for admin dashboard connections."""
    from channels.auth import AuthMiddlewareStack
    return AuthMiddlewareStack  # Use Django's built-in auth middleware