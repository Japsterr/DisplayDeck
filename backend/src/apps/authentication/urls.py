# URL patterns for authentication endpoints

from django.urls import path
from rest_framework_simplejwt.views import TokenVerifyView

from .views import (
    UserRegistrationView,
    UserLoginView,
    CustomTokenRefreshView,
    UserProfileView,
    PasswordChangeView,
    PasswordResetRequestView,
    PasswordResetConfirmView,
    UserLogoutView,
    UserSessionsView,
    auth_check,
    terminate_session,
)

app_name = 'authentication'

urlpatterns = [
    # User registration and authentication
    path('register/', UserRegistrationView.as_view(), name='register'),
    path('login/', UserLoginView.as_view(), name='login'),
    path('logout/', UserLogoutView.as_view(), name='logout'),
    
    # JWT token management
    path('token/refresh/', CustomTokenRefreshView.as_view(), name='token_refresh'),
    path('token/verify/', TokenVerifyView.as_view(), name='token_verify'),
    
    # User profile management
    path('profile/', UserProfileView.as_view(), name='profile'),
    path('check/', auth_check, name='auth_check'),
    
    # Password management
    path('password/change/', PasswordChangeView.as_view(), name='password_change'),
    path('password/reset/', PasswordResetRequestView.as_view(), name='password_reset'),
    path('password/reset/confirm/', PasswordResetConfirmView.as_view(), name='password_reset_confirm'),
    
    # Session management
    path('sessions/', UserSessionsView.as_view(), name='user_sessions'),
    path('sessions/<uuid:session_id>/terminate/', terminate_session, name='terminate_session'),
]