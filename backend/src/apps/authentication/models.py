# Custom User model for DisplayDeck authentication system

import uuid
from django.contrib.auth.models import AbstractUser, Group, Permission, UserManager
from django.db import models
from django.utils.translation import gettext_lazy as _
from django.core.validators import validate_email
from django.contrib.auth.validators import UnicodeUsernameValidator


class CustomUserManager(UserManager):
    """
    Custom User Manager that creates users with email as the primary identifier.
    """
    
    def create_user(self, email, password=None, **extra_fields):
        """Create and return a regular User with the given email and password."""
        if not email:
            raise ValueError(_('The Email field must be set'))
        
        email = self.normalize_email(email)
        
        # Set default values
        extra_fields.setdefault('is_staff', False)
        extra_fields.setdefault('is_superuser', False)
        
        # Generate username from email if not provided
        if not extra_fields.get('username'):
            username_base = email.split('@')[0]
            username = username_base
            counter = 1
            while self.model.objects.filter(username=username).exists():
                username = f"{username_base}{counter}"
                counter += 1
            extra_fields['username'] = username
        
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user
    
    def create_superuser(self, email, password=None, **extra_fields):
        """Create and return a superuser with the given email and password."""
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_verified', True)
        
        if extra_fields.get('is_staff') is not True:
            raise ValueError(_('Superuser must have is_staff=True.'))
        if extra_fields.get('is_superuser') is not True:
            raise ValueError(_('Superuser must have is_superuser=True.'))
        
        return self.create_user(email, password, **extra_fields)


class User(AbstractUser):
    """
    Custom User model extending Django's AbstractUser.
    Adds email as the primary authentication method and additional user metadata.
    """
    
    # Override the default username field to make it optional
    username_validator = UnicodeUsernameValidator()
    
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        help_text=_("Unique identifier for the user")
    )
    
    username = models.CharField(
        _("username"),
        max_length=150,
        unique=True,
        blank=True,
        null=True,
        help_text=_(
            "Optional. 150 characters or fewer. Letters, digits and @/./+/-/_ only."
        ),
        validators=[username_validator],
        error_messages={
            "unique": _("A user with that username already exists."),
        },
    )
    
    email = models.EmailField(
        _("email address"),
        unique=True,
        validators=[validate_email],
        help_text=_("Required. Enter a valid email address."),
        error_messages={
            "unique": _("A user with that email address already exists."),
        },
    )
    
    first_name = models.CharField(
        _("first name"), 
        max_length=150, 
        help_text=_("User's first name")
    )
    
    last_name = models.CharField(
        _("last name"), 
        max_length=150, 
        help_text=_("User's last name")
    )
    
    phone_number = models.CharField(
        _("phone number"),
        max_length=20,
        blank=True,
        null=True,
        help_text=_("Optional. Contact phone number")
    )
    
    # Profile information
    profile_image = models.ImageField(
        _("profile image"),
        upload_to="profile_images/",
        blank=True,
        null=True,
        help_text=_("Optional. User's profile picture")
    )
    
    # Account status and metadata
    is_verified = models.BooleanField(
        _("verified"),
        default=False,
        help_text=_("Designates whether this user has verified their email address.")
    )
    
    # Role-based access control
    ROLE_CHOICES = [
        ('owner', _('Business Owner')),
        ('manager', _('Business Manager')),
        ('staff', _('Staff Member')),
        ('viewer', _('Viewer')),
    ]
    
    role = models.CharField(
        _("role"),
        max_length=20,
        choices=ROLE_CHOICES,
        default='owner',
        help_text=_("User's role in the system")
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        _("created at"),
        auto_now_add=True,
        help_text=_("Date and time when the account was created")
    )
    
    updated_at = models.DateTimeField(
        _("updated at"),
        auto_now=True,
        help_text=_("Date and time when the account was last updated")
    )
    
    last_login_ip = models.GenericIPAddressField(
        _("last login IP"),
        blank=True,
        null=True,
        help_text=_("IP address of the user's last login")
    )
    
    # Password reset and account recovery
    password_reset_token = models.CharField(
        _("password reset token"),
        max_length=255,
        blank=True,
        null=True,
        help_text=_("Token for password reset functionality")
    )
    
    password_reset_expires_at = models.DateTimeField(
        _("password reset expires at"),
        blank=True,
        null=True,
        help_text=_("Expiration time for password reset token")
    )
    
    # Email verification
    email_verification_token = models.CharField(
        _("email verification token"),
        max_length=255,
        blank=True,
        null=True,
        help_text=_("Token for email verification")
    )
    
    email_verification_expires_at = models.DateTimeField(
        _("email verification expires at"),
        blank=True,
        null=True,
        help_text=_("Expiration time for email verification token")
    )
    
    # Account security
    failed_login_attempts = models.PositiveIntegerField(
        _("failed login attempts"),
        default=0,
        help_text=_("Number of consecutive failed login attempts")
    )
    
    account_locked_until = models.DateTimeField(
        _("account locked until"),
        blank=True,
        null=True,
        help_text=_("Account lock expiration time")
    )
    
    # Two-factor authentication (for future implementation)
    two_factor_enabled = models.BooleanField(
        _("two-factor authentication enabled"),
        default=False,
        help_text=_("Whether two-factor authentication is enabled")
    )
    
    backup_codes = models.JSONField(
        _("backup codes"),
        default=list,
        blank=True,
        help_text=_("Backup codes for two-factor authentication")
    )
    
    # Preferences and settings
    preferences = models.JSONField(
        _("user preferences"),
        default=dict,
        blank=True,
        help_text=_("User's application preferences and settings")
    )
    
    # Business relationships - stored as reverse foreign keys
    # businesses (ManyToMany through BusinessMember)
    
    # Email as the username field
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name', 'last_name']
    
    # Use custom user manager
    objects = CustomUserManager()
    
    # Fix related_name conflicts with Django's built-in User model
    groups = models.ManyToManyField(
        Group,
        verbose_name=_("groups"),
        blank=True,
        help_text=_(
            "The groups this user belongs to. A user will get all permissions "
            "granted to each of their groups."
        ),
        related_name="custom_user_set",
        related_query_name="user",
    )
    
    user_permissions = models.ManyToManyField(
        Permission,
        verbose_name=_("user permissions"),
        blank=True,
        help_text=_("Specific permissions for this user."),
        related_name="custom_user_set",
        related_query_name="user",
    )
    
    class Meta:
        verbose_name = _("User")
        verbose_name_plural = _("Users")
        db_table = "auth_user"
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['email'], name='auth_user_email_idx'),
            models.Index(fields=['is_active'], name='auth_user_active_idx'),
            models.Index(fields=['created_at'], name='auth_user_created_idx'),
        ]
    
    def __str__(self):
        """String representation of the user."""
        return f"{self.get_full_name()} ({self.email})"
    
    def get_full_name(self):
        """Return the user's full name."""
        return f"{self.first_name} {self.last_name}".strip() or self.email
    
    def get_short_name(self):
        """Return the user's short name (first name)."""
        return self.first_name or self.email.split('@')[0]
    
    def save(self, *args, **kwargs):
        """Override save to handle username generation and email normalization."""
        # Normalize email
        if self.email:
            self.email = self.email.lower().strip()
        
        # Generate username from email if not provided
        if not self.username and self.email:
            base_username = self.email.split('@')[0]
            username = base_username
            counter = 1
            while User.objects.filter(username=username).exclude(pk=self.pk).exists():
                username = f"{base_username}{counter}"
                counter += 1
            self.username = username
        
        super().save(*args, **kwargs)
    
    @property
    def is_business_owner(self):
        """Check if user is a business owner."""
        return self.role == 'owner'
    
    @property
    def is_business_manager(self):
        """Check if user is a business manager or owner."""
        return self.role in ['owner', 'manager']
    
    @property
    def can_manage_businesses(self):
        """Check if user can manage businesses."""
        return self.role in ['owner', 'manager']
    
    @property
    def can_edit_menus(self):
        """Check if user can edit menus."""
        return self.role in ['owner', 'manager', 'staff']
    
    @property
    def can_view_analytics(self):
        """Check if user can view analytics."""
        return self.role in ['owner', 'manager']
    
    def get_businesses(self):
        """Get all businesses this user has access to."""
        from apps.businesses.models import BusinessMember
        return BusinessMember.objects.filter(user=self).select_related('business')
    
    def has_business_permission(self, business, permission):
        """Check if user has a specific permission for a business."""
        from apps.businesses.models import BusinessMember
        try:
            membership = BusinessMember.objects.get(user=self, business=business)
            return membership.has_permission(permission)
        except BusinessMember.DoesNotExist:
            return False
    
    def is_account_locked(self):
        """Check if the account is currently locked."""
        from django.utils import timezone
        return (
            self.account_locked_until and 
            self.account_locked_until > timezone.now()
        )
    
    def lock_account(self, lock_duration_minutes=15):
        """Lock the account for a specified duration."""
        from django.utils import timezone
        from datetime import timedelta
        
        self.account_locked_until = timezone.now() + timedelta(minutes=lock_duration_minutes)
        self.save(update_fields=['account_locked_until'])
    
    def unlock_account(self):
        """Unlock the account and reset failed login attempts."""
        self.account_locked_until = None
        self.failed_login_attempts = 0
        self.save(update_fields=['account_locked_until', 'failed_login_attempts'])
    
    def increment_failed_login_attempts(self):
        """Increment failed login attempts and lock account if threshold reached."""
        self.failed_login_attempts += 1
        
        # Lock account after 5 failed attempts
        if self.failed_login_attempts >= 5:
            self.lock_account()
        
        self.save(update_fields=['failed_login_attempts'])
    
    def reset_failed_login_attempts(self):
        """Reset failed login attempts counter."""
        if self.failed_login_attempts > 0:
            self.failed_login_attempts = 0
            self.save(update_fields=['failed_login_attempts'])


class UserSession(models.Model):
    """
    Model to track user sessions for security and analytics.
    """
    
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='sessions',
        help_text=_("User associated with this session")
    )
    
    session_key = models.CharField(
        _("session key"),
        max_length=40,
        unique=True,
        help_text=_("Django session key")
    )
    
    ip_address = models.GenericIPAddressField(
        _("IP address"),
        help_text=_("IP address from which the session was created")
    )
    
    user_agent = models.TextField(
        _("user agent"),
        help_text=_("Browser user agent string")
    )
    
    device_type = models.CharField(
        _("device type"),
        max_length=50,
        choices=[
            ('desktop', _('Desktop')),
            ('mobile', _('Mobile')),
            ('tablet', _('Tablet')),
            ('unknown', _('Unknown')),
        ],
        default='unknown',
        help_text=_("Type of device used for this session")
    )
    
    is_active = models.BooleanField(
        _("is active"),
        default=True,
        help_text=_("Whether this session is currently active")
    )
    
    created_at = models.DateTimeField(
        _("created at"),
        auto_now_add=True,
        help_text=_("When the session was created")
    )
    
    last_activity = models.DateTimeField(
        _("last activity"),
        auto_now=True,
        help_text=_("Last activity timestamp for this session")
    )
    
    expires_at = models.DateTimeField(
        _("expires at"),
        help_text=_("When the session expires")
    )
    
    class Meta:
        verbose_name = _("User Session")
        verbose_name_plural = _("User Sessions")
        db_table = "auth_user_session"
        ordering = ['-last_activity']
        indexes = [
            models.Index(fields=['user', 'is_active'], name='auth_session_user_active_idx'),
            models.Index(fields=['session_key'], name='auth_session_key_idx'),
            models.Index(fields=['expires_at'], name='auth_session_expires_idx'),
        ]
    
    def __str__(self):
        return f"{self.user.email} - {self.device_type} - {self.ip_address}"
    
    def is_expired(self):
        """Check if the session has expired."""
        from django.utils import timezone
        return self.expires_at <= timezone.now()
    
    def extend_session(self, extension_hours=24):
        """Extend the session by the specified number of hours."""
        from django.utils import timezone
        from datetime import timedelta
        
        self.expires_at = timezone.now() + timedelta(hours=extension_hours)
        self.save(update_fields=['expires_at'])
    
    def terminate_session(self):
        """Mark the session as inactive."""
        self.is_active = False
        self.save(update_fields=['is_active'])


class PasswordResetRequest(models.Model):
    """
    Model to track password reset requests for security auditing.
    """
    
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='password_reset_requests',
        help_text=_("User who requested the password reset")
    )
    
    token = models.CharField(
        _("reset token"),
        max_length=255,
        unique=True,
        help_text=_("Unique token for password reset")
    )
    
    ip_address = models.GenericIPAddressField(
        _("IP address"),
        help_text=_("IP address from which the reset was requested")
    )
    
    user_agent = models.TextField(
        _("user agent"),
        help_text=_("Browser user agent string")
    )
    
    is_used = models.BooleanField(
        _("is used"),
        default=False,
        help_text=_("Whether this reset token has been used")
    )
    
    created_at = models.DateTimeField(
        _("created at"),
        auto_now_add=True,
        help_text=_("When the reset was requested")
    )
    
    expires_at = models.DateTimeField(
        _("expires at"),
        help_text=_("When the reset token expires")
    )
    
    used_at = models.DateTimeField(
        _("used at"),
        blank=True,
        null=True,
        help_text=_("When the reset token was used")
    )
    
    class Meta:
        verbose_name = _("Password Reset Request")
        verbose_name_plural = _("Password Reset Requests")
        db_table = "auth_password_reset"
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['token'], name='auth_reset_token_idx'),
            models.Index(fields=['user', 'is_used'], name='auth_reset_user_used_idx'),
            models.Index(fields=['expires_at'], name='auth_reset_expires_idx'),
        ]
    
    def __str__(self):
        return f"Password reset for {self.user.email} at {self.created_at}"
    
    def is_expired(self):
        """Check if the reset token has expired."""
        from django.utils import timezone
        return self.expires_at <= timezone.now()
    
    def mark_as_used(self):
        """Mark the reset token as used."""
        from django.utils import timezone
        self.is_used = True
        self.used_at = timezone.now()
        self.save(update_fields=['is_used', 'used_at'])