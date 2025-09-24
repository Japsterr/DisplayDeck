# Business models for DisplayDeck - managing restaurants and their staff

import uuid
from django.db import models
from django.utils.translation import gettext_lazy as _
from django.core.validators import RegexValidator, MinValueValidator, MaxValueValidator
from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError


User = get_user_model()


class Business(models.Model):
    """
    Model representing a restaurant/fast food business.
    Each business can have multiple menus, displays, and staff members.
    """
    
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        help_text=_("Unique identifier for the business")
    )
    
    name = models.CharField(
        _("business name"),
        max_length=255,
        help_text=_("Name of the restaurant or business")
    )
    
    slug = models.SlugField(
        _("slug"),
        max_length=100,
        unique=True,
        help_text=_("URL-friendly identifier for the business")
    )
    
    description = models.TextField(
        _("description"),
        blank=True,
        help_text=_("Optional description of the business")
    )
    
    # Business type and category
    BUSINESS_TYPE_CHOICES = [
        ('fast_food', _('Fast Food')),
        ('restaurant', _('Restaurant')),
        ('cafe', _('Cafe')),
        ('bakery', _('Bakery')),
        ('bar', _('Bar')),
        ('food_truck', _('Food Truck')),
        ('other', _('Other')),
    ]
    
    business_type = models.CharField(
        _("business type"),
        max_length=20,
        choices=BUSINESS_TYPE_CHOICES,
        default='fast_food',
        help_text=_("Type of food service business")
    )
    
    # Contact information
    email = models.EmailField(
        _("business email"),
        blank=True,
        help_text=_("Primary contact email for the business")
    )
    
    phone_validator = RegexValidator(
        regex=r'^\+?1?\d{9,15}$',
        message=_("Phone number must be entered in the format: '+999999999'. Up to 15 digits allowed.")
    )
    
    phone_number = models.CharField(
        _("phone number"),
        validators=[phone_validator],
        max_length=17,
        blank=True,
        help_text=_("Primary contact phone number")
    )
    
    website = models.URLField(
        _("website"),
        blank=True,
        help_text=_("Business website URL")
    )
    
    # Address information
    address_line_1 = models.CharField(
        _("address line 1"),
        max_length=255,
        blank=True,
        help_text=_("Street address")
    )
    
    address_line_2 = models.CharField(
        _("address line 2"),
        max_length=255,
        blank=True,
        help_text=_("Apartment, suite, unit, building, floor, etc.")
    )
    
    city = models.CharField(
        _("city"),
        max_length=100,
        blank=True,
        help_text=_("City name")
    )
    
    state_province = models.CharField(
        _("state/province"),
        max_length=100,
        blank=True,
        help_text=_("State or province")
    )
    
    postal_code = models.CharField(
        _("postal code"),
        max_length=20,
        blank=True,
        help_text=_("ZIP or postal code")
    )
    
    country = models.CharField(
        _("country"),
        max_length=100,
        default='United States',
        help_text=_("Country name")
    )
    
    # Geographic coordinates for location-based features
    latitude = models.DecimalField(
        _("latitude"),
        max_digits=10,
        decimal_places=7,
        blank=True,
        null=True,
        validators=[MinValueValidator(-90), MaxValueValidator(90)],
        help_text=_("Latitude coordinate")
    )
    
    longitude = models.DecimalField(
        _("longitude"),
        max_digits=10,
        decimal_places=7,
        blank=True,
        null=True,
        validators=[MinValueValidator(-180), MaxValueValidator(180)],
        help_text=_("Longitude coordinate")
    )
    
    # Business hours (JSON field for flexibility)
    business_hours = models.JSONField(
        _("business hours"),
        default=dict,
        blank=True,
        help_text=_("Business operating hours for each day of the week")
    )
    
    # Branding and customization
    logo = models.ImageField(
        _("logo"),
        upload_to="business_logos/",
        blank=True,
        null=True,
        help_text=_("Business logo image")
    )
    
    banner_image = models.ImageField(
        _("banner image"),
        upload_to="business_banners/",
        blank=True,
        null=True,
        help_text=_("Banner image for displays and marketing")
    )
    
    primary_color = models.CharField(
        _("primary color"),
        max_length=7,
        default='#1f2937',
        validators=[RegexValidator(r'^#[0-9a-fA-F]{6}$')],
        help_text=_("Primary brand color in hex format (#RRGGBB)")
    )
    
    secondary_color = models.CharField(
        _("secondary color"),
        max_length=7,
        default='#374151',
        validators=[RegexValidator(r'^#[0-9a-fA-F]{6}$')],
        help_text=_("Secondary brand color in hex format (#RRGGBB)")
    )
    
    accent_color = models.CharField(
        _("accent color"),
        max_length=7,
        default='#3b82f6',
        validators=[RegexValidator(r'^#[0-9a-fA-F]{6}$')],
        help_text=_("Accent brand color in hex format (#RRGGBB)")
    )
    
    # Settings and preferences
    settings = models.JSONField(
        _("business settings"),
        default=dict,
        blank=True,
        help_text=_("Business-specific settings and preferences")
    )
    
    # Subscription and plan information
    PLAN_CHOICES = [
        ('free', _('Free Plan')),
        ('basic', _('Basic Plan')),
        ('professional', _('Professional Plan')),
        ('enterprise', _('Enterprise Plan')),
    ]
    
    plan = models.CharField(
        _("subscription plan"),
        max_length=20,
        choices=PLAN_CHOICES,
        default='free',
        help_text=_("Current subscription plan")
    )
    
    plan_expires_at = models.DateTimeField(
        _("plan expires at"),
        blank=True,
        null=True,
        help_text=_("When the current plan expires")
    )
    
    # Status and metadata
    is_active = models.BooleanField(
        _("is active"),
        default=True,
        help_text=_("Whether the business is currently active")
    )
    
    is_verified = models.BooleanField(
        _("is verified"),
        default=False,
        help_text=_("Whether the business has been verified")
    )
    
    created_at = models.DateTimeField(
        _("created at"),
        auto_now_add=True,
        help_text=_("Date and time when the business was created")
    )
    
    updated_at = models.DateTimeField(
        _("updated at"),
        auto_now=True,
        help_text=_("Date and time when the business was last updated")
    )
    
    # Owner (primary contact)
    owner = models.ForeignKey(
        User,
        on_delete=models.PROTECT,
        related_name='owned_businesses',
        help_text=_("Primary owner of the business")
    )
    
    # Staff members (many-to-many through BusinessMember)
    members = models.ManyToManyField(
        User,
        through='BusinessMember',
        through_fields=('business', 'user'),
        related_name='businesses',
        help_text=_("Staff members with access to this business")
    )
    
    class Meta:
        verbose_name = _("Business")
        verbose_name_plural = _("Businesses")
        db_table = "businesses_business"
        ordering = ['name']
        indexes = [
            models.Index(fields=['slug'], name='business_slug_idx'),
            models.Index(fields=['owner'], name='business_owner_idx'),
            models.Index(fields=['is_active'], name='business_active_idx'),
            models.Index(fields=['business_type'], name='business_type_idx'),
            models.Index(fields=['created_at'], name='business_created_idx'),
        ]
        constraints = [
            models.CheckConstraint(
                check=models.Q(latitude__gte=-90, latitude__lte=90),
                name='business_latitude_range'
            ),
            models.CheckConstraint(
                check=models.Q(longitude__gte=-180, longitude__lte=180),
                name='business_longitude_range'
            ),
        ]
    
    def __str__(self):
        return self.name
    
    def get_absolute_url(self):
        """Return the absolute URL for this business."""
        return f"/businesses/{self.slug}/"
    
    def get_full_address(self):
        """Return the complete formatted address."""
        address_parts = [
            self.address_line_1,
            self.address_line_2,
            self.city,
            self.state_province,
            self.postal_code,
            self.country
        ]
        return ', '.join(filter(None, address_parts))
    
    def save(self, *args, **kwargs):
        """Override save to generate slug if not provided."""
        if not self.slug:
            from django.utils.text import slugify
            base_slug = slugify(self.name)
            slug = base_slug
            counter = 1
            while Business.objects.filter(slug=slug).exclude(pk=self.pk).exists():
                slug = f"{base_slug}-{counter}"
                counter += 1
            self.slug = slug
        
        super().save(*args, **kwargs)
    
    def get_active_displays_count(self):
        """Get the number of active displays for this business."""
        return self.displays.filter(is_active=True).count()
    
    def get_total_menus_count(self):
        """Get the total number of menus for this business."""
        return self.menus.count()
    
    def has_reached_display_limit(self):
        """Check if the business has reached its display limit based on plan."""
        display_limits = {
            'free': 2,
            'basic': 10,
            'professional': 25,
            'enterprise': 100,
        }
        
        limit = display_limits.get(self.plan, 2)
        return self.get_active_displays_count() >= limit
    
    def has_reached_member_limit(self):
        """Check if the business has reached its member limit based on plan."""
        member_limits = {
            'free': 3,
            'basic': 10,
            'professional': 25,
            'enterprise': 100,
        }
        
        limit = member_limits.get(self.plan, 3)
        return self.members.count() >= limit
    
    def can_add_member(self, user):
        """Check if a user can be added as a member."""
        if self.has_reached_member_limit():
            return False
        return not self.members.filter(id=user.id).exists()
    
    def get_plan_display_name(self):
        """Get the human-readable plan name."""
        return dict(self.PLAN_CHOICES).get(self.plan, self.plan)


class BusinessMember(models.Model):
    """
    Through model for the relationship between Business and User.
    Defines roles and permissions for business staff members.
    """
    
    ROLE_CHOICES = [
        ('owner', _('Owner')),
        ('manager', _('Manager')),
        ('staff', _('Staff')),
        ('viewer', _('Viewer')),
    ]
    
    PERMISSION_CHOICES = [
        ('manage_business', _('Manage Business Settings')),
        ('manage_members', _('Manage Team Members')),
        ('manage_menus', _('Manage Menus')),
        ('manage_displays', _('Manage Displays')),
        ('view_analytics', _('View Analytics')),
        ('manage_orders', _('Manage Orders')),
    ]
    
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    
    business = models.ForeignKey(
        Business,
        on_delete=models.CASCADE,
        related_name='memberships',
        help_text=_("Business this membership belongs to")
    )
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='business_memberships',
        help_text=_("User who is a member of the business")
    )
    
    role = models.CharField(
        _("role"),
        max_length=20,
        choices=ROLE_CHOICES,
        default='staff',
        help_text=_("User's role in the business")
    )
    
    permissions = models.JSONField(
        _("permissions"),
        default=list,
        help_text=_("Specific permissions granted to this member")
    )
    
    # Status and metadata
    is_active = models.BooleanField(
        _("is active"),
        default=True,
        help_text=_("Whether this membership is currently active")
    )
    
    invited_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='business_invitations_sent',
        help_text=_("User who invited this member")
    )
    
    invited_at = models.DateTimeField(
        _("invited at"),
        blank=True,
        null=True,
        help_text=_("When the invitation was sent")
    )
    
    joined_at = models.DateTimeField(
        _("joined at"),
        auto_now_add=True,
        help_text=_("When the user joined the business")
    )
    
    updated_at = models.DateTimeField(
        _("updated at"),
        auto_now=True,
        help_text=_("When the membership was last updated")
    )
    
    # Invitation status
    INVITATION_STATUS_CHOICES = [
        ('pending', _('Pending')),
        ('accepted', _('Accepted')),
        ('declined', _('Declined')),
        ('expired', _('Expired')),
    ]
    
    invitation_status = models.CharField(
        _("invitation status"),
        max_length=20,
        choices=INVITATION_STATUS_CHOICES,
        default='accepted',
        help_text=_("Status of the business invitation")
    )
    
    invitation_token = models.CharField(
        _("invitation token"),
        max_length=255,
        blank=True,
        null=True,
        help_text=_("Token for invitation acceptance")
    )
    
    invitation_expires_at = models.DateTimeField(
        _("invitation expires at"),
        blank=True,
        null=True,
        help_text=_("When the invitation expires")
    )
    
    class Meta:
        verbose_name = _("Business Member")
        verbose_name_plural = _("Business Members")
        db_table = "businesses_member"
        unique_together = ['business', 'user']
        ordering = ['role', 'joined_at']
        indexes = [
            models.Index(fields=['business', 'role'], name='member_business_role_idx'),
            models.Index(fields=['user'], name='member_user_idx'),
            models.Index(fields=['is_active'], name='member_active_idx'),
            models.Index(fields=['invitation_token'], name='member_token_idx'),
        ]
    
    def __str__(self):
        return f"{self.user.get_full_name()} - {self.business.name} ({self.get_role_display()})"
    
    def clean(self):
        """Validate the membership."""
        super().clean()
        
        # Ensure business owner cannot be changed to a different role
        if self.business.owner == self.user and self.role != 'owner':
            raise ValidationError(_("Business owner must have the 'owner' role."))
        
        # Ensure only one owner per business
        if (self.role == 'owner' and 
            BusinessMember.objects.filter(business=self.business, role='owner')
            .exclude(pk=self.pk).exists()):
            raise ValidationError(_("A business can have only one owner."))
    
    def save(self, *args, **kwargs):
        """Override save to set default permissions based on role."""
        # Set default permissions based on role
        if not self.permissions:
            self.permissions = self.get_default_permissions_for_role()
        
        super().save(*args, **kwargs)
    
    def get_default_permissions_for_role(self):
        """Get default permissions for the user's role."""
        role_permissions = {
            'owner': [
                'manage_business',
                'manage_members',
                'manage_menus',
                'manage_displays',
                'view_analytics',
                'manage_orders',
            ],
            'manager': [
                'manage_menus',
                'manage_displays',
                'view_analytics',
                'manage_orders',
            ],
            'staff': [
                'manage_menus',
                'manage_displays',
                'manage_orders',
            ],
            'viewer': [
                'view_analytics',
            ],
        }
        return role_permissions.get(self.role, [])
    
    def has_permission(self, permission):
        """Check if the member has a specific permission."""
        return permission in self.permissions
    
    def add_permission(self, permission):
        """Add a permission to the member."""
        if permission not in self.permissions:
            self.permissions.append(permission)
            self.save(update_fields=['permissions'])
    
    def remove_permission(self, permission):
        """Remove a permission from the member."""
        if permission in self.permissions:
            self.permissions.remove(permission)
            self.save(update_fields=['permissions'])
    
    def is_owner(self):
        """Check if the member is the business owner."""
        return self.role == 'owner'
    
    def is_manager_or_above(self):
        """Check if the member is a manager or owner."""
        return self.role in ['owner', 'manager']
    
    def can_manage_other_members(self):
        """Check if the member can manage other team members."""
        return self.has_permission('manage_members')
    
    def can_manage_business_settings(self):
        """Check if the member can manage business settings."""
        return self.has_permission('manage_business')
    
    def get_permission_display_names(self):
        """Get human-readable names for the member's permissions."""
        permission_dict = dict(self.PERMISSION_CHOICES)
        return [permission_dict.get(perm, perm) for perm in self.permissions]


class BusinessInvitation(models.Model):
    """
    Model to track business invitations sent to new team members.
    """
    
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    
    business = models.ForeignKey(
        Business,
        on_delete=models.CASCADE,
        related_name='invitations',
        help_text=_("Business sending the invitation")
    )
    
    invited_by = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='sent_business_invitations',
        help_text=_("User who sent the invitation")
    )
    
    email = models.EmailField(
        _("invitee email"),
        help_text=_("Email address of the person being invited")
    )
    
    role = models.CharField(
        _("role"),
        max_length=20,
        choices=BusinessMember.ROLE_CHOICES,
        default='staff',
        help_text=_("Role to be assigned to the invited user")
    )
    
    permissions = models.JSONField(
        _("permissions"),
        default=list,
        help_text=_("Permissions to be granted to the invited user")
    )
    
    message = models.TextField(
        _("invitation message"),
        blank=True,
        help_text=_("Optional message to include with the invitation")
    )
    
    token = models.CharField(
        _("invitation token"),
        max_length=255,
        unique=True,
        help_text=_("Unique token for invitation acceptance")
    )
    
    # Status tracking
    STATUS_CHOICES = [
        ('pending', _('Pending')),
        ('accepted', _('Accepted')),
        ('declined', _('Declined')),
        ('expired', _('Expired')),
        ('cancelled', _('Cancelled')),
    ]
    
    status = models.CharField(
        _("status"),
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
        help_text=_("Current status of the invitation")
    )
    
    created_at = models.DateTimeField(
        _("created at"),
        auto_now_add=True,
        help_text=_("When the invitation was sent")
    )
    
    expires_at = models.DateTimeField(
        _("expires at"),
        help_text=_("When the invitation expires")
    )
    
    responded_at = models.DateTimeField(
        _("responded at"),
        blank=True,
        null=True,
        help_text=_("When the invitation was responded to")
    )
    
    accepted_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='accepted_business_invitations',
        help_text=_("User who accepted the invitation")
    )
    
    class Meta:
        verbose_name = _("Business Invitation")
        verbose_name_plural = _("Business Invitations")
        db_table = "businesses_invitation"
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['business', 'status'], name='invitation_business_status_idx'),
            models.Index(fields=['email'], name='invitation_email_idx'),
            models.Index(fields=['token'], name='invitation_token_idx'),
            models.Index(fields=['expires_at'], name='invitation_expires_idx'),
        ]
    
    def __str__(self):
        return f"Invitation to {self.email} for {self.business.name}"
    
    def is_expired(self):
        """Check if the invitation has expired."""
        from django.utils import timezone
        return self.expires_at <= timezone.now()
    
    def can_be_accepted(self):
        """Check if the invitation can still be accepted."""
        return self.status == 'pending' and not self.is_expired()
    
    def accept(self, user):
        """Accept the invitation and create business membership."""
        if not self.can_be_accepted():
            raise ValidationError(_("This invitation can no longer be accepted."))
        
        from django.utils import timezone
        
        # Create or update business membership
        membership, created = BusinessMember.objects.get_or_create(
            business=self.business,
            user=user,
            defaults={
                'role': self.role,
                'permissions': self.permissions,
                'invited_by': self.invited_by,
                'invited_at': self.created_at,
                'invitation_status': 'accepted',
            }
        )
        
        # Update invitation status
        self.status = 'accepted'
        self.responded_at = timezone.now()
        self.accepted_by = user
        self.save(update_fields=['status', 'responded_at', 'accepted_by'])
        
        return membership
    
    def decline(self):
        """Decline the invitation."""
        from django.utils import timezone
        
        self.status = 'declined'
        self.responded_at = timezone.now()
        self.save(update_fields=['status', 'responded_at'])
    
    def cancel(self):
        """Cancel the invitation (only by the inviter or business owner)."""
        self.status = 'cancelled'
        self.save(update_fields=['status'])
    
    def save(self, *args, **kwargs):
        """Override save to generate token and set default permissions."""
        if not self.token:
            import secrets
            self.token = secrets.token_urlsafe(32)
        
        if not self.permissions:
            membership = BusinessMember(role=self.role)
            self.permissions = membership.get_default_permissions_for_role()
        
        super().save(*args, **kwargs)