# Authentication serializers for DisplayDeck API

from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model, authenticate
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.utils.translation import gettext_lazy as _
from .models import PasswordResetRequest
import secrets
from datetime import timedelta
from django.utils import timezone


User = get_user_model()


class UserRegistrationSerializer(serializers.ModelSerializer):
    """
    Serializer for user registration with email, password, and profile information.
    """
    password = serializers.CharField(
        write_only=True,
        min_length=8,
        style={'input_type': 'password'}
    )
    password_confirm = serializers.CharField(
        write_only=True,
        style={'input_type': 'password'}
    )
    
    class Meta:
        model = User
        fields = [
            'email', 'password', 'password_confirm',
            'first_name', 'last_name', 'phone_number'
        ]
        extra_kwargs = {
            'email': {'required': True},
            'first_name': {'required': True},
            'last_name': {'required': True},
        }
    
    def validate_email(self, value):
        """Validate email is unique."""
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError(
                _("A user with this email address already exists.")
            )
        return value.lower()
    
    def validate_password(self, value):
        """Validate password meets requirements."""
        try:
            validate_password(value)
        except DjangoValidationError as e:
            raise serializers.ValidationError(e.messages)
        return value
    
    def validate(self, attrs):
        """Validate password confirmation matches."""
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({
                'password_confirm': _("Password confirmation does not match.")
            })
        return attrs
    
    def create(self, validated_data):
        """Create new user with validated data."""
        # Remove password_confirm from validated data
        validated_data.pop('password_confirm')
        
        # Create user
        user = User.objects.create_user(**validated_data)
        
        # Set user as verified if using email verification is disabled
        # In production, this should be False and email verification should be implemented
        user.is_verified = True
        user.save(update_fields=['is_verified'])
        
        return user


class UserLoginSerializer(TokenObtainPairSerializer):
    """
    Custom login serializer that extends JWT token serializer.
    """
    email = serializers.EmailField(required=True)
    password = serializers.CharField(required=True, style={'input_type': 'password'})
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Remove the username field since we use email
        if 'username' in self.fields:
            del self.fields['username']
    
    def validate(self, attrs):
        """Validate login credentials."""
        email = attrs.get('email')
        password = attrs.get('password')
        
        if email and password:
            # Find user by email
            try:
                user = User.objects.get(email__iexact=email)
            except User.DoesNotExist:
                raise serializers.ValidationError(
                    _("No active account found with the given credentials.")
                )
            
            # Check if account is locked
            if user.is_account_locked():
                raise serializers.ValidationError(
                    _("Account is temporarily locked due to too many failed login attempts.")
                )
            
            # Authenticate user
            user = authenticate(email=email, password=password)
            
            if user is None:
                # Increment failed login attempts
                try:
                    user = User.objects.get(email__iexact=email)
                    user.increment_failed_login_attempts()
                except User.DoesNotExist:
                    pass
                
                raise serializers.ValidationError(
                    _("No active account found with the given credentials.")
                )
            
            # Check if user is active
            if not user.is_active:
                raise serializers.ValidationError(
                    _("User account is disabled.")
                )
            
            # Reset failed login attempts on successful login
            user.reset_failed_login_attempts()
            
            # Set username for JWT token generation
            attrs['username'] = user.email
            
        return super().validate(attrs)
    
    @classmethod
    def get_token(cls, user):
        """Customize JWT token with additional user information."""
        token = super().get_token(user)
        
        # Add custom claims
        token['email'] = user.email
        token['first_name'] = user.first_name
        token['last_name'] = user.last_name
        token['role'] = user.role
        token['is_verified'] = user.is_verified
        
        return token


class UserProfileSerializer(serializers.ModelSerializer):
    """
    Serializer for user profile information (read/update).
    """
    full_name = serializers.CharField(source='get_full_name', read_only=True)
    business_count = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = [
            'id', 'email', 'username', 'first_name', 'last_name', 'full_name',
            'phone_number', 'profile_image', 'role', 'is_verified',
            'business_count', 'date_joined', 'last_login'
        ]
        read_only_fields = ['id', 'email', 'username', 'role', 'is_verified', 'date_joined', 'last_login']
    
    def get_business_count(self, obj):
        """Get the number of businesses this user has access to."""
        return obj.businesses.count()
    
    def validate_phone_number(self, value):
        """Validate phone number format."""
        if value and not value.startswith('+'):
            # Add default country code if not provided
            value = f"+1{value}"
        return value


class PasswordChangeSerializer(serializers.Serializer):
    """
    Serializer for changing user password (authenticated users).
    """
    current_password = serializers.CharField(required=True, style={'input_type': 'password'})
    new_password = serializers.CharField(required=True, style={'input_type': 'password'})
    confirm_password = serializers.CharField(required=True, style={'input_type': 'password'})
    
    def validate_current_password(self, value):
        """Validate current password is correct."""
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError(_("Current password is incorrect."))
        return value
    
    def validate_new_password(self, value):
        """Validate new password meets requirements."""
        try:
            validate_password(value, user=self.context['request'].user)
        except DjangoValidationError as e:
            raise serializers.ValidationError(e.messages)
        return value
    
    def validate(self, attrs):
        """Validate password confirmation matches."""
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError({
                'confirm_password': _("Password confirmation does not match.")
            })
        return attrs
    
    def save(self):
        """Update user password."""
        user = self.context['request'].user
        user.set_password(self.validated_data['new_password'])
        user.save()
        return user


class PasswordResetRequestSerializer(serializers.Serializer):
    """
    Serializer for requesting password reset via email.
    """
    email = serializers.EmailField(required=True)
    
    def validate_email(self, value):
        """Validate email exists in system."""
        try:
            user = User.objects.get(email__iexact=value)
        except User.DoesNotExist:
            # Don't reveal that email doesn't exist for security
            raise serializers.ValidationError(
                _("If this email is associated with an account, you will receive reset instructions.")
            )
        return value.lower()
    
    def save(self):
        """Create password reset request."""
        email = self.validated_data['email']
        
        try:
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            # Return without creating request if user doesn't exist
            return None
        
        # Generate secure token
        token = secrets.token_urlsafe(32)
        
        # Create reset request
        reset_request = PasswordResetRequest.objects.create(
            user=user,
            token=token,
            expires_at=timezone.now() + timedelta(hours=1),  # 1 hour expiry
            ip_address=self.context.get('ip_address', '127.0.0.1'),
            user_agent=self.context.get('user_agent', '')
        )
        
        # Update user's reset token (for backward compatibility)
        user.password_reset_token = token
        user.password_reset_expires_at = reset_request.expires_at
        user.save(update_fields=['password_reset_token', 'password_reset_expires_at'])
        
        return reset_request


class PasswordResetConfirmSerializer(serializers.Serializer):
    """
    Serializer for confirming password reset with token.
    """
    token = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True, style={'input_type': 'password'})
    confirm_password = serializers.CharField(required=True, style={'input_type': 'password'})
    
    def validate_token(self, value):
        """Validate reset token is valid and not expired."""
        try:
            reset_request = PasswordResetRequest.objects.get(
                token=value,
                is_used=False
            )
        except PasswordResetRequest.DoesNotExist:
            raise serializers.ValidationError(_("Invalid or expired reset token."))
        
        if reset_request.is_expired():
            raise serializers.ValidationError(_("Reset token has expired."))
        
        self.reset_request = reset_request
        return value
    
    def validate_new_password(self, value):
        """Validate new password meets requirements."""
        try:
            # We'll validate against the user once we have the token
            validate_password(value)
        except DjangoValidationError as e:
            raise serializers.ValidationError(e.messages)
        return value
    
    def validate(self, attrs):
        """Validate password confirmation matches."""
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError({
                'confirm_password': _("Password confirmation does not match.")
            })
        return attrs
    
    def save(self):
        """Reset user password and mark token as used."""
        user = self.reset_request.user
        user.set_password(self.validated_data['new_password'])
        
        # Clear reset token fields
        user.password_reset_token = None
        user.password_reset_expires_at = None
        
        # Reset failed login attempts
        user.unlock_account()
        
        user.save()
        
        # Mark reset request as used
        self.reset_request.mark_as_used()
        
        return user


class EmailVerificationSerializer(serializers.Serializer):
    """
    Serializer for email verification (future implementation).
    """
    token = serializers.CharField(required=True)
    
    def validate_token(self, value):
        """Validate verification token."""
        # This would validate the email verification token
        # Implementation depends on email verification system
        return value


class UserListSerializer(serializers.ModelSerializer):
    """
    Lightweight serializer for user lists (admin/management views).
    """
    full_name = serializers.CharField(source='get_full_name', read_only=True)
    business_count = serializers.SerializerMethodField()
    last_login_display = serializers.DateTimeField(source='last_login', format='%Y-%m-%d %H:%M:%S', read_only=True)
    
    class Meta:
        model = User
        fields = [
            'id', 'email', 'full_name', 'role', 'is_active', 'is_verified',
            'business_count', 'date_joined', 'last_login_display'
        ]
    
    def get_business_count(self, obj):
        """Get the number of businesses this user has access to."""
        return obj.businesses.count()


class UserBusinessMembershipSerializer(serializers.Serializer):
    """
    Serializer for user's business memberships.
    """
    business_id = serializers.UUIDField(read_only=True)
    business_name = serializers.CharField(read_only=True)
    business_slug = serializers.CharField(read_only=True)
    role = serializers.CharField(read_only=True)
    permissions = serializers.ListField(read_only=True)
    joined_at = serializers.DateTimeField(read_only=True)
    is_active = serializers.BooleanField(read_only=True)


class TokenRefreshResponseSerializer(serializers.Serializer):
    """
    Serializer for token refresh response documentation.
    """
    access = serializers.CharField(help_text="New access token")
    refresh = serializers.CharField(help_text="New refresh token (if rotation enabled)")


class LoginResponseSerializer(serializers.Serializer):
    """
    Serializer for login response documentation.
    """
    access = serializers.CharField(help_text="Access token for API authentication")
    refresh = serializers.CharField(help_text="Refresh token for obtaining new access tokens")
    user = UserProfileSerializer(help_text="User profile information")


class RegisterResponseSerializer(serializers.Serializer):
    """
    Serializer for registration response documentation.
    """
    user = UserProfileSerializer(help_text="Created user profile information")
    message = serializers.CharField(help_text="Success message")


class StandardErrorSerializer(serializers.Serializer):
    """
    Standard error response serializer for API documentation.
    """
    error = serializers.CharField(help_text="Error message")
    details = serializers.DictField(required=False, help_text="Detailed error information")


class ValidationErrorSerializer(serializers.Serializer):
    """
    Validation error response serializer for API documentation.
    """
    field_errors = serializers.DictField(help_text="Field-specific validation errors")
    non_field_errors = serializers.ListField(
        required=False,
        help_text="General validation errors"
    )