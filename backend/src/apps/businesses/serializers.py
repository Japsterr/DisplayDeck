# Business serializers for DisplayDeck API

from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.utils.translation import gettext_lazy as _
from django.core.exceptions import ValidationError as DjangoValidationError
from decimal import Decimal

from .models import Business, BusinessMember, BusinessInvitation
from apps.authentication.serializers import UserListSerializer


User = get_user_model()


class BusinessSerializer(serializers.ModelSerializer):
    """
    Serializer for Business model with full business information.
    """
    owner_info = UserListSerializer(source='owner', read_only=True)
    member_count = serializers.SerializerMethodField()
    active_displays_count = serializers.SerializerMethodField()
    total_menus_count = serializers.SerializerMethodField()
    full_address = serializers.CharField(source='get_full_address', read_only=True)
    plan_display_name = serializers.CharField(source='get_plan_display_name', read_only=True)
    
    class Meta:
        model = Business
        fields = [
            # Basic information
            'id', 'name', 'slug', 'description', 'business_type',
            # Contact information
            'email', 'phone_number', 'website',
            # Address information
            'address_line_1', 'address_line_2', 'city', 'state_province',
            'postal_code', 'country', 'latitude', 'longitude', 'full_address',
            # Business hours and settings
            'business_hours', 'settings',
            # Branding
            'logo', 'banner_image', 'primary_color', 'secondary_color', 'accent_color',
            # Plan and status
            'plan', 'plan_display_name', 'plan_expires_at',
            'is_active', 'is_verified',
            # Relationships and counts
            'owner_info', 'member_count', 'active_displays_count', 'total_menus_count',
            # Timestamps
            'created_at', 'updated_at'
        ]
        read_only_fields = [
            'id', 'slug', 'owner_info', 'member_count', 'active_displays_count',
            'total_menus_count', 'full_address', 'plan_display_name',
            'is_verified', 'created_at', 'updated_at'
        ]
    
    def get_member_count(self, obj):
        """Get the total number of active members."""
        return obj.members.filter(business_memberships__is_active=True).count()
    
    def get_active_displays_count(self, obj):
        """Get the number of active displays."""
        return obj.get_active_displays_count()
    
    def get_total_menus_count(self, obj):
        """Get the total number of menus."""
        return obj.get_total_menus_count()
    
    def validate_phone_number(self, value):
        """Validate phone number format."""
        if value and not value.startswith('+'):
            # Add default country code if not provided
            value = f"+1{value}"
        return value
    
    def validate_latitude(self, value):
        """Validate latitude is within valid range."""
        if value is not None and not (-90 <= value <= 90):
            raise serializers.ValidationError(_("Latitude must be between -90 and 90 degrees."))
        return value
    
    def validate_longitude(self, value):
        """Validate longitude is within valid range."""
        if value is not None and not (-180 <= value <= 180):
            raise serializers.ValidationError(_("Longitude must be between -180 and 180 degrees."))
        return value
    
    def validate(self, attrs):
        """Validate business data."""
        # Ensure coordinates are both provided or both empty
        latitude = attrs.get('latitude')
        longitude = attrs.get('longitude')
        
        if (latitude is not None) != (longitude is not None):
            raise serializers.ValidationError({
                'coordinates': _("Both latitude and longitude must be provided together.")
            })
        
        return attrs
    
    def create(self, validated_data):
        """Create a new business with the current user as owner."""
        user = self.context['request'].user
        business = Business.objects.create(owner=user, **validated_data)
        
        # Create owner membership
        BusinessMember.objects.create(
            business=business,
            user=user,
            role='owner'
        )
        
        return business


class BusinessCreateSerializer(serializers.ModelSerializer):
    """
    Simplified serializer for creating a new business.
    """
    
    class Meta:
        model = Business
        fields = [
            'name', 'description', 'business_type',
            'email', 'phone_number', 'website',
            'address_line_1', 'address_line_2', 'city', 'state_province',
            'postal_code', 'country', 'latitude', 'longitude',
            'primary_color', 'secondary_color', 'accent_color'
        ]
    
    def validate_phone_number(self, value):
        """Validate and format phone number."""
        if value and not value.startswith('+'):
            value = f"+1{value}"
        return value
    
    def create(self, validated_data):
        """Create business and initial membership."""
        user = self.context['request'].user
        business = Business.objects.create(owner=user, **validated_data)
        
        # Create owner membership
        BusinessMember.objects.create(
            business=business,
            user=user,
            role='owner'
        )
        
        return business


class BusinessUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating business information.
    """
    
    class Meta:
        model = Business
        fields = [
            'name', 'description', 'business_type',
            'email', 'phone_number', 'website',
            'address_line_1', 'address_line_2', 'city', 'state_province',
            'postal_code', 'country', 'latitude', 'longitude',
            'business_hours', 'settings',
            'logo', 'banner_image',
            'primary_color', 'secondary_color', 'accent_color'
        ]
    
    def validate_phone_number(self, value):
        """Validate and format phone number."""
        if value and not value.startswith('+'):
            value = f"+1{value}"
        return value


class BusinessMemberSerializer(serializers.ModelSerializer):
    """
    Serializer for BusinessMember model.
    """
    user_info = UserListSerializer(source='user', read_only=True)
    business_info = serializers.SerializerMethodField()
    role_display = serializers.CharField(source='get_role_display', read_only=True)
    permission_display_names = serializers.CharField(source='get_permission_display_names', read_only=True)
    invited_by_info = UserListSerializer(source='invited_by', read_only=True)
    
    class Meta:
        model = BusinessMember
        fields = [
            'id', 'business_info', 'user_info', 'role', 'role_display',
            'permissions', 'permission_display_names', 'is_active',
            'invited_by_info', 'invited_at', 'joined_at', 'updated_at',
            'invitation_status'
        ]
        read_only_fields = [
            'id', 'business_info', 'user_info', 'role_display',
            'permission_display_names', 'invited_by_info',
            'invited_at', 'joined_at', 'updated_at'
        ]
    
    def get_business_info(self, obj):
        """Get minimal business information."""
        return {
            'id': obj.business.id,
            'name': obj.business.name,
            'slug': obj.business.slug
        }
    
    def validate_role(self, value):
        """Validate role changes."""
        if self.instance:
            # Prevent changing owner role
            if self.instance.business.owner == self.instance.user and value != 'owner':
                raise serializers.ValidationError(
                    _("Cannot change role for business owner.")
                )
        return value
    
    def validate_permissions(self, value):
        """Validate permissions list."""
        if not isinstance(value, list):
            raise serializers.ValidationError(_("Permissions must be a list."))
        
        valid_permissions = [choice[0] for choice in BusinessMember.PERMISSION_CHOICES]
        invalid_permissions = [perm for perm in value if perm not in valid_permissions]
        
        if invalid_permissions:
            raise serializers.ValidationError(
                _("Invalid permissions: {}").format(', '.join(invalid_permissions))
            )
        
        return value


class BusinessMemberUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating business member information.
    """
    
    class Meta:
        model = BusinessMember
        fields = ['role', 'permissions', 'is_active']
    
    def validate_role(self, value):
        """Validate role changes."""
        if self.instance:
            # Prevent changing owner role
            if self.instance.business.owner == self.instance.user and value != 'owner':
                raise serializers.ValidationError(
                    _("Cannot change role for business owner.")
                )
            
            # Ensure only one owner per business
            if value == 'owner' and self.instance.role != 'owner':
                if BusinessMember.objects.filter(
                    business=self.instance.business, 
                    role='owner'
                ).exclude(pk=self.instance.pk).exists():
                    raise serializers.ValidationError(
                        _("A business can have only one owner.")
                    )
        
        return value


class BusinessInvitationSerializer(serializers.ModelSerializer):
    """
    Serializer for BusinessInvitation model.
    """
    business_info = serializers.SerializerMethodField()
    invited_by_info = UserListSerializer(source='invited_by', read_only=True)
    accepted_by_info = UserListSerializer(source='accepted_by', read_only=True)
    role_display = serializers.CharField(source='get_role_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    can_be_accepted = serializers.BooleanField(source='can_be_accepted', read_only=True)
    is_expired = serializers.BooleanField(source='is_expired', read_only=True)
    
    class Meta:
        model = BusinessInvitation
        fields = [
            'id', 'business_info', 'invited_by_info', 'accepted_by_info',
            'email', 'role', 'role_display', 'permissions', 'message',
            'status', 'status_display', 'can_be_accepted', 'is_expired',
            'created_at', 'expires_at', 'responded_at'
        ]
        read_only_fields = [
            'id', 'business_info', 'invited_by_info', 'accepted_by_info',
            'role_display', 'status_display', 'can_be_accepted', 'is_expired',
            'created_at', 'expires_at', 'responded_at'
        ]
    
    def get_business_info(self, obj):
        """Get minimal business information."""
        return {
            'id': obj.business.id,
            'name': obj.business.name,
            'slug': obj.business.slug
        }


class BusinessInvitationCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating business invitations.
    """
    
    class Meta:
        model = BusinessInvitation
        fields = ['email', 'role', 'permissions', 'message']
    
    def validate_email(self, value):
        """Validate invitation email."""
        business = self.context.get('business')
        
        # Check if user is already a member
        if business and User.objects.filter(
            email__iexact=value,
            business_memberships__business=business,
            business_memberships__is_active=True
        ).exists():
            raise serializers.ValidationError(
                _("User with this email is already a member of this business.")
            )
        
        # Check for pending invitations
        if business and BusinessInvitation.objects.filter(
            business=business,
            email__iexact=value,
            status='pending'
        ).exists():
            raise serializers.ValidationError(
                _("An invitation has already been sent to this email address.")
            )
        
        return value.lower()
    
    def validate_role(self, value):
        """Validate invitation role."""
        if value == 'owner':
            raise serializers.ValidationError(
                _("Cannot invite someone as owner. Ownership must be transferred.")
            )
        return value
    
    def create(self, validated_data):
        """Create invitation with expiration."""
        from django.utils import timezone
        from datetime import timedelta
        import secrets
        
        business = self.context['business']
        invited_by = self.context['request'].user
        
        # Generate unique token
        token = secrets.token_urlsafe(32)
        
        # Create invitation
        invitation = BusinessInvitation.objects.create(
            business=business,
            invited_by=invited_by,
            token=token,
            expires_at=timezone.now() + timedelta(days=7),  # 7 days to accept
            **validated_data
        )
        
        # TODO: Send invitation email
        # This would be handled by a background task or signal
        
        return invitation


class BusinessStatsSerializer(serializers.Serializer):
    """
    Serializer for business statistics and analytics.
    """
    total_menus = serializers.IntegerField()
    total_menu_items = serializers.IntegerField()
    total_displays = serializers.IntegerField()
    active_displays = serializers.IntegerField()
    total_members = serializers.IntegerField()
    active_members = serializers.IntegerField()
    plan_info = serializers.DictField()
    usage_limits = serializers.DictField()


class BusinessListSerializer(serializers.ModelSerializer):
    """
    Lightweight serializer for business lists.
    """
    member_role = serializers.SerializerMethodField()
    member_permissions = serializers.SerializerMethodField()
    active_displays_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Business
        fields = [
            'id', 'name', 'slug', 'business_type', 'logo',
            'is_active', 'member_role', 'member_permissions',
            'active_displays_count', 'created_at'
        ]
    
    def get_member_role(self, obj):
        """Get current user's role in this business."""
        user = self.context['request'].user
        try:
            membership = BusinessMember.objects.get(
                business=obj,
                user=user,
                is_active=True
            )
            return membership.role
        except BusinessMember.DoesNotExist:
            return None
    
    def get_member_permissions(self, obj):
        """Get current user's permissions in this business."""
        user = self.context['request'].user
        try:
            membership = BusinessMember.objects.get(
                business=obj,
                user=user,
                is_active=True
            )
            return membership.permissions
        except BusinessMember.DoesNotExist:
            return []
    
    def get_active_displays_count(self, obj):
        """Get the number of active displays."""
        return obj.get_active_displays_count()


class BusinessTransferOwnershipSerializer(serializers.Serializer):
    """
    Serializer for transferring business ownership.
    """
    new_owner_email = serializers.EmailField()
    confirm_transfer = serializers.BooleanField(default=False)
    
    def validate_new_owner_email(self, value):
        """Validate new owner exists and is a member."""
        business = self.context.get('business')
        
        try:
            user = User.objects.get(email__iexact=value)
        except User.DoesNotExist:
            raise serializers.ValidationError(
                _("No user found with this email address.")
            )
        
        # Check if user is a member of the business
        if not BusinessMember.objects.filter(
            business=business,
            user=user,
            is_active=True
        ).exists():
            raise serializers.ValidationError(
                _("User must be an active member of the business.")
            )
        
        # Check if user is already the owner
        if business.owner == user:
            raise serializers.ValidationError(
                _("User is already the owner of this business.")
            )
        
        self.new_owner = user
        return value
    
    def validate_confirm_transfer(self, value):
        """Ensure transfer is confirmed."""
        if not value:
            raise serializers.ValidationError(
                _("You must confirm the ownership transfer.")
            )
        return value
    
    def save(self):
        """Transfer business ownership."""
        business = self.context['business']
        current_owner = business.owner
        new_owner = self.new_owner
        
        # Update business owner
        business.owner = new_owner
        business.save(update_fields=['owner'])
        
        # Update memberships
        # Set current owner to manager
        BusinessMember.objects.filter(
            business=business,
            user=current_owner
        ).update(role='manager')
        
        # Set new owner role
        BusinessMember.objects.filter(
            business=business,
            user=new_owner
        ).update(role='owner')
        
        return business