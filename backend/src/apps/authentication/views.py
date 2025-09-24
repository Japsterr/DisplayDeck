# Authentication views for DisplayDeck API

from rest_framework import status, generics, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from django.utils.decorators import method_decorator
try:
    from django_ratelimit.decorators import ratelimit
except ImportError:
    # Fallback if django-ratelimit is not installed
    def ratelimit(key=None, rate=None, method=None):
        def decorator(func):
            return func
        return decorator
from drf_spectacular.utils import extend_schema, OpenApiResponse
from drf_spectacular.openapi import OpenApiParameter

from .models import UserSession
from .serializers import (
    UserRegistrationSerializer,
    UserLoginSerializer,
    UserProfileSerializer,
    PasswordChangeSerializer,
    PasswordResetRequestSerializer,
    PasswordResetConfirmSerializer,
    LoginResponseSerializer,
    RegisterResponseSerializer,
    StandardErrorSerializer,
    ValidationErrorSerializer,
    TokenRefreshResponseSerializer
)


User = get_user_model()


@extend_schema(
    request=UserRegistrationSerializer,
    responses={
        201: RegisterResponseSerializer,
        400: ValidationErrorSerializer,
    },
    tags=['Authentication'],
    summary="Register new user",
    description="Create a new user account with email, password and profile information."
)
@method_decorator(ratelimit(key='ip', rate='3/min', method='POST'), name='post')
class UserRegistrationView(generics.CreateAPIView):
    """
    API endpoint for user registration.
    """
    serializer_class = UserRegistrationSerializer
    permission_classes = [permissions.AllowAny]
    
    def create(self, request, *args, **kwargs):
        """Create a new user account."""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user = serializer.save()
        
        return Response({
            'user': UserProfileSerializer(user).data,
            'message': 'Account created successfully. You can now log in.'
        }, status=status.HTTP_201_CREATED)


@extend_schema(
    request=UserLoginSerializer,
    responses={
        200: LoginResponseSerializer,
        400: StandardErrorSerializer,
        401: StandardErrorSerializer,
    },
    tags=['Authentication'],
    summary="User login",
    description="Authenticate user with email and password, returns JWT tokens."
)
@method_decorator(ratelimit(key='ip', rate='5/min', method='POST'), name='post')
class UserLoginView(TokenObtainPairView):
    """
    API endpoint for user login with JWT token generation.
    """
    serializer_class = UserLoginSerializer
    
    def post(self, request, *args, **kwargs):
        """Authenticate user and return JWT tokens."""
        response = super().post(request, *args, **kwargs)
        
        if response.status_code == 200:
            # Get user from token
            serializer = self.get_serializer(data=request.data)
            serializer.is_valid()
            
            try:
                user = User.objects.get(email__iexact=request.data.get('email'))
                
                # Create user session for tracking
                self._create_user_session(user, request)
                
                # Add user profile to response
                response.data['user'] = UserProfileSerializer(user).data
                
            except User.DoesNotExist:
                pass
        
        return response
    
    def _create_user_session(self, user, request):
        """Create a user session for tracking purposes."""
        from django.contrib.sessions.models import Session
        from datetime import timedelta
        from django.utils import timezone
        
        # Get or create session
        if not request.session.session_key:
            request.session.create()
        
        # Get client information
        ip_address = self._get_client_ip(request)
        user_agent = request.META.get('HTTP_USER_AGENT', '')
        
        # Determine device type from user agent
        device_type = self._determine_device_type(user_agent)
        
        # Create user session record
        UserSession.objects.create(
            user=user,
            session_key=request.session.session_key,
            ip_address=ip_address,
            user_agent=user_agent,
            device_type=device_type,
            expires_at=timezone.now() + timedelta(hours=24)
        )
    
    def _get_client_ip(self, request):
        """Get client IP address from request."""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0].strip()
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip
    
    def _determine_device_type(self, user_agent):
        """Determine device type from user agent string."""
        user_agent_lower = user_agent.lower()
        
        if any(device in user_agent_lower for device in ['mobile', 'android', 'iphone']):
            return 'mobile'
        elif 'tablet' in user_agent_lower or 'ipad' in user_agent_lower:
            return 'tablet'
        else:
            return 'desktop'


@extend_schema(
    responses={
        200: TokenRefreshResponseSerializer,
        401: StandardErrorSerializer,
    },
    tags=['Authentication'],
    summary="Refresh JWT token",
    description="Obtain a new access token using a refresh token."
)
class CustomTokenRefreshView(TokenRefreshView):
    """
    Custom token refresh view for JWT tokens.
    """
    pass


@extend_schema(
    responses={
        200: UserProfileSerializer,
        401: StandardErrorSerializer,
    },
    tags=['Authentication'],
    summary="Get user profile",
    description="Retrieve the authenticated user's profile information."
)
class UserProfileView(generics.RetrieveUpdateAPIView):
    """
    API endpoint to retrieve and update user profile.
    """
    serializer_class = UserProfileSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_object(self):
        """Return the current authenticated user."""
        return self.request.user


@extend_schema(
    request=PasswordChangeSerializer,
    responses={
        200: {"description": "Password changed successfully"},
        400: ValidationErrorSerializer,
        401: StandardErrorSerializer,
    },
    tags=['Authentication'],
    summary="Change password",
    description="Change the authenticated user's password."
)
class PasswordChangeView(APIView):
    """
    API endpoint for changing user password (authenticated users).
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        """Change user password."""
        serializer = PasswordChangeSerializer(
            data=request.data,
            context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        
        return Response({
            'message': 'Password changed successfully.'
        }, status=status.HTTP_200_OK)


@extend_schema(
    request=PasswordResetRequestSerializer,
    responses={
        200: {"description": "Password reset email sent"},
        400: ValidationErrorSerializer,
    },
    tags=['Authentication'],
    summary="Request password reset",
    description="Send password reset instructions to user's email."
)
@method_decorator(ratelimit(key='ip', rate='3/5min', method='POST'), name='post')
class PasswordResetRequestView(APIView):
    """
    API endpoint for requesting password reset via email.
    """
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        """Send password reset email."""
        serializer = PasswordResetRequestSerializer(
            data=request.data,
            context={
                'ip_address': self._get_client_ip(request),
                'user_agent': request.META.get('HTTP_USER_AGENT', '')
            }
        )
        serializer.is_valid(raise_exception=True)
        
        reset_request = serializer.save()
        
        if reset_request:
            # In a real application, send email here
            # For now, we'll just return success
            # TODO: Implement email sending
            pass
        
        # Always return success for security (don't reveal if email exists)
        return Response({
            'message': 'If this email is associated with an account, you will receive reset instructions.'
        }, status=status.HTTP_200_OK)
    
    def _get_client_ip(self, request):
        """Get client IP address from request."""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0].strip()
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip


@extend_schema(
    request=PasswordResetConfirmSerializer,
    responses={
        200: {"description": "Password reset successfully"},
        400: ValidationErrorSerializer,
    },
    tags=['Authentication'],
    summary="Confirm password reset",
    description="Reset password using the token received via email."
)
class PasswordResetConfirmView(APIView):
    """
    API endpoint for confirming password reset with token.
    """
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        """Reset password with token."""
        serializer = PasswordResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user = serializer.save()
        
        return Response({
            'message': 'Password reset successfully. You can now log in with your new password.'
        }, status=status.HTTP_200_OK)


@extend_schema(
    responses={
        200: {"description": "Logged out successfully"},
        401: StandardErrorSerializer,
    },
    tags=['Authentication'],
    summary="User logout",
    description="Logout user by blacklisting the refresh token."
)
class UserLogoutView(APIView):
    """
    API endpoint for user logout (blacklist refresh token).
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        """Logout user and blacklist refresh token."""
        try:
            refresh_token = request.data.get('refresh')
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
            
            # End user sessions
            self._end_user_sessions(request.user, request)
            
            return Response({
                'message': 'Logged out successfully.'
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            return Response({
                'error': 'Invalid token or logout failed.'
            }, status=status.HTTP_400_BAD_REQUEST)
    
    def _end_user_sessions(self, user, request):
        """End active user sessions."""
        # Mark current session as inactive
        if request.session.session_key:
            UserSession.objects.filter(
                user=user,
                session_key=request.session.session_key,
                is_active=True
            ).update(is_active=False)


@extend_schema(
    responses={
        200: {
            "type": "object",
            "properties": {
                "authenticated": {"type": "boolean"},
                "user": UserProfileSerializer,
            }
        },
        401: StandardErrorSerializer,
    },
    tags=['Authentication'],
    summary="Check authentication status",
    description="Check if the current request is authenticated and return user info."
)
@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def auth_check(request):
    """
    Check authentication status and return user information.
    """
    return Response({
        'authenticated': True,
        'user': UserProfileSerializer(request.user).data
    })


@extend_schema(
    parameters=[
        OpenApiParameter(name='page', type=int, description='Page number'),
        OpenApiParameter(name='page_size', type=int, description='Items per page'),
    ],
    responses={
        200: {
            "type": "object",
            "properties": {
                "sessions": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "id": {"type": "string", "format": "uuid"},
                            "device_type": {"type": "string"},
                            "ip_address": {"type": "string"},
                            "is_active": {"type": "boolean"},
                            "created_at": {"type": "string", "format": "date-time"},
                            "last_activity": {"type": "string", "format": "date-time"},
                        }
                    }
                }
            }
        },
        401: StandardErrorSerializer,
    },
    tags=['Authentication'],
    summary="Get user sessions",
    description="Retrieve active and recent sessions for the authenticated user."
)
class UserSessionsView(generics.ListAPIView):
    """
    API endpoint to retrieve user's active sessions.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Return sessions for the authenticated user."""
        return UserSession.objects.filter(
            user=self.request.user
        ).order_by('-last_activity')
    
    def list(self, request, *args, **kwargs):
        """List user sessions with custom response format."""
        queryset = self.get_queryset()
        page = self.paginate_queryset(queryset)
        
        sessions_data = []
        for session in (page if page else queryset):
            sessions_data.append({
                'id': session.id,
                'device_type': session.get_device_type_display(),
                'ip_address': session.ip_address,
                'is_active': session.is_active,
                'created_at': session.created_at,
                'last_activity': session.last_activity,
                'user_agent': session.user_agent[:100] if session.user_agent else None,  # Truncate for display
            })
        
        if page:
            return self.get_paginated_response({'sessions': sessions_data})
        
        return Response({'sessions': sessions_data})


@extend_schema(
    responses={
        200: {"description": "Session terminated successfully"},
        404: StandardErrorSerializer,
        401: StandardErrorSerializer,
    },
    tags=['Authentication'],
    summary="Terminate session",
    description="Terminate a specific user session."
)
@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def terminate_session(request, session_id):
    """
    Terminate a specific user session.
    """
    try:
        session = UserSession.objects.get(
            id=session_id,
            user=request.user
        )
        session.terminate_session()
        
        return Response({
            'message': 'Session terminated successfully.'
        })
        
    except UserSession.DoesNotExist:
        return Response({
            'error': 'Session not found.'
        }, status=status.HTTP_404_NOT_FOUND)