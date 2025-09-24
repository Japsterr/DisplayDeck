"""
Role-based permissions system for DisplayDeck.

This module provides a centralized permission system for managing access control
across different business contexts and user roles.
"""

from rest_framework import permissions
from django.contrib.auth import get_user_model
from typing import Dict, List, Optional, Union

User = get_user_model()


class BusinessRole:
    """Constants for business member roles."""
    OWNER = 'owner'
    MANAGER = 'manager' 
    STAFF = 'staff'
    VIEWER = 'viewer'
    
    ALL_ROLES = [OWNER, MANAGER, STAFF, VIEWER]
    
    # Role hierarchy (higher index = more permissions)
    HIERARCHY = [VIEWER, STAFF, MANAGER, OWNER]
    
    @classmethod
    def get_role_level(cls, role: str) -> int:
        """Get the hierarchy level of a role (higher = more permissions)."""
        try:
            return cls.HIERARCHY.index(role)
        except ValueError:
            return -1
    
    @classmethod
    def has_higher_or_equal_role(cls, user_role: str, required_role: str) -> bool:
        """Check if user role has equal or higher permissions than required role."""
        return cls.get_role_level(user_role) >= cls.get_role_level(required_role)


class BusinessPermissions:
    """
    Permission definitions for business operations.
    Maps business actions to required permissions and roles.
    """
    
    # Core business management permissions
    MANAGE_BUSINESS = 'manage_business'
    MANAGE_MEMBERS = 'manage_members'
    MANAGE_MENUS = 'manage_menus'
    MANAGE_DISPLAYS = 'manage_displays'
    VIEW_ANALYTICS = 'view_analytics'
    MANAGE_ORDERS = 'manage_orders'
    
    # Menu-specific permissions
    CREATE_MENUS = 'create_menus'
    EDIT_MENUS = 'edit_menus'
    DELETE_MENUS = 'delete_menus'
    PUBLISH_MENUS = 'publish_menus'
    
    # Display-specific permissions
    PAIR_DISPLAYS = 'pair_displays'
    ASSIGN_CONTENT = 'assign_content'
    MONITOR_DISPLAYS = 'monitor_displays'
    
    # All permissions list
    ALL_PERMISSIONS = [
        MANAGE_BUSINESS, MANAGE_MEMBERS, MANAGE_MENUS, MANAGE_DISPLAYS,
        VIEW_ANALYTICS, MANAGE_ORDERS, CREATE_MENUS, EDIT_MENUS,
        DELETE_MENUS, PUBLISH_MENUS, PAIR_DISPLAYS, ASSIGN_CONTENT,
        MONITOR_DISPLAYS
    ]
    
    # Role-based permission mappings
    ROLE_PERMISSIONS = {
        BusinessRole.OWNER: ALL_PERMISSIONS,
        BusinessRole.MANAGER: [
            MANAGE_MENUS, MANAGE_DISPLAYS, VIEW_ANALYTICS, MANAGE_ORDERS,
            CREATE_MENUS, EDIT_MENUS, DELETE_MENUS, PUBLISH_MENUS,
            PAIR_DISPLAYS, ASSIGN_CONTENT, MONITOR_DISPLAYS, MANAGE_MEMBERS
        ],
        BusinessRole.STAFF: [
            EDIT_MENUS, VIEW_ANALYTICS, MANAGE_ORDERS,
            ASSIGN_CONTENT, MONITOR_DISPLAYS
        ],
        BusinessRole.VIEWER: [
            VIEW_ANALYTICS, MONITOR_DISPLAYS
        ]
    }
    
    # Action-based permission requirements
    ACTION_PERMISSIONS = {
        # Business operations
        'retrieve': [],  # No specific permission needed
        'list': [],      # No specific permission needed
        'create': [],    # Creating new business is always allowed
        'update': [MANAGE_BUSINESS],
        'partial_update': [MANAGE_BUSINESS],
        'destroy': [MANAGE_BUSINESS],
        'transfer_ownership': [MANAGE_BUSINESS],
        
        # Business analytics and stats
        'stats': [VIEW_ANALYTICS],
        'analytics': [VIEW_ANALYTICS],
        
        # Member management
        'members': [MANAGE_MEMBERS],
        'add_member': [MANAGE_MEMBERS],
        'remove_member': [MANAGE_MEMBERS],
        'update_member': [MANAGE_MEMBERS],
        'invite': [MANAGE_MEMBERS],
        'cancel_invitation': [MANAGE_MEMBERS],
        
        # Menu operations
        'menus': [VIEW_ANALYTICS],
        'create_menu': [CREATE_MENUS],
        'update_menu': [EDIT_MENUS],
        'delete_menu': [DELETE_MENUS],
        'publish_menu': [PUBLISH_MENUS],
        
        # Display operations
        'displays': [MONITOR_DISPLAYS],
        'pair_display': [PAIR_DISPLAYS],
        'assign_menu': [ASSIGN_CONTENT],
        'display_status': [MONITOR_DISPLAYS],
    }
    
    @classmethod
    def get_permissions_for_role(cls, role: str) -> List[str]:
        """Get all permissions available to a specific role."""
        return cls.ROLE_PERMISSIONS.get(role, [])
    
    @classmethod
    def has_permission(cls, role: str, permission: str) -> bool:
        """Check if a role has a specific permission."""
        return permission in cls.get_permissions_for_role(role)
    
    @classmethod
    def get_required_permissions(cls, action: str) -> List[str]:
        """Get required permissions for a specific action."""
        return cls.ACTION_PERMISSIONS.get(action, [])


class BaseBusinessPermission(permissions.BasePermission):
    """
    Base permission class for business-related operations.
    
    Provides common functionality for checking business membership
    and role-based permissions.
    """
    
    def has_permission(self, request, view):
        """Check if user is authenticated."""
        return request.user and request.user.is_authenticated
    
    def has_object_permission(self, request, view, obj):
        """Check if user has permission for specific business object."""
        business = self.get_business_from_object(obj)
        if not business:
            return False
        
        membership = self.get_user_membership(request.user, business)
        if not membership or not membership.is_active:
            return False
        
        # Get required permissions for this action
        required_permissions = BusinessPermissions.get_required_permissions(
            getattr(view, 'action', 'retrieve')
        )
        
        # If no specific permissions required, allow access
        if not required_permissions:
            return True
        
        # Owner and manager roles can do most things
        if membership.role in [BusinessRole.OWNER, BusinessRole.MANAGER]:
            # Owners can always do everything
            if membership.role == BusinessRole.OWNER:
                return True
            
            # Managers can do everything except certain business management tasks
            restricted_for_managers = [BusinessPermissions.MANAGE_BUSINESS]
            if any(perm in restricted_for_managers for perm in required_permissions):
                return False
            return True
        
        # Check specific permissions for staff and viewer roles
        return all(
            BusinessPermissions.has_permission(membership.role, perm)
            for perm in required_permissions
        )
    
    def get_business_from_object(self, obj):
        """Extract business object from the given object."""
        if hasattr(obj, '__class__') and obj.__class__.__name__ == 'Business':
            return obj
        elif hasattr(obj, 'business'):
            return obj.business
        elif hasattr(obj, 'menu') and hasattr(obj.menu, 'business'):
            return obj.menu.business
        elif hasattr(obj, 'display') and hasattr(obj.display, 'business'):
            return obj.display.business
        return None
    
    def get_user_membership(self, user, business):
        """Get user's membership in the business."""
        try:
            from apps.businesses.models import BusinessMember
            return BusinessMember.objects.get(
                business=business,
                user=user,
                is_active=True
            )
        except BusinessMember.DoesNotExist:
            return None


class BusinessPermission(BaseBusinessPermission):
    """
    Permission class for business operations.
    
    This is the main permission class for business-related endpoints.
    """
    pass


class MenuPermission(BaseBusinessPermission):
    """
    Permission class for menu operations.
    
    Handles permissions for menu-related endpoints with menu-specific logic.
    """
    
    def has_object_permission(self, request, view, obj):
        """Check permissions with menu-specific logic."""
        # Get base permission check
        has_base_permission = super().has_object_permission(request, view, obj)
        if not has_base_permission:
            return False
        
        # Additional menu-specific checks can go here
        # For example, checking if menu is published, scheduling constraints, etc.
        
        return True


class DisplayPermission(BaseBusinessPermission):
    """
    Permission class for display operations.
    
    Handles permissions for display-related endpoints with display-specific logic.
    """
    
    def has_object_permission(self, request, view, obj):
        """Check permissions with display-specific logic."""
        # Get base permission check
        has_base_permission = super().has_object_permission(request, view, obj)
        if not has_base_permission:
            return False
        
        # Additional display-specific checks can go here
        # For example, checking display status, pairing state, etc.
        
        return True


class IsBusinessOwner(BaseBusinessPermission):
    """Permission that only allows business owners."""
    
    def has_object_permission(self, request, view, obj):
        business = self.get_business_from_object(obj)
        if not business:
            return False
        
        return business.owner == request.user


class IsBusinessOwnerOrManager(BaseBusinessPermission):
    """Permission that allows business owners and managers."""
    
    def has_object_permission(self, request, view, obj):
        business = self.get_business_from_object(obj)
        if not business:
            return False
        
        membership = self.get_user_membership(request.user, business)
        if not membership or not membership.is_active:
            return False
        
        return membership.role in [BusinessRole.OWNER, BusinessRole.MANAGER]


class CanManageMembers(BaseBusinessPermission):
    """Permission specifically for member management operations."""
    
    def has_object_permission(self, request, view, obj):
        business = self.get_business_from_object(obj)
        if not business:
            return False
        
        membership = self.get_user_membership(request.user, business)
        if not membership or not membership.is_active:
            return False
        
        return BusinessPermissions.has_permission(
            membership.role, 
            BusinessPermissions.MANAGE_MEMBERS
        )


def check_business_permission(user, business, permission: str) -> bool:
    """
    Utility function to check if a user has a specific permission for a business.
    
    Args:
        user: The user to check permissions for
        business: The business object
        permission: The permission string to check
        
    Returns:
        bool: True if user has the permission, False otherwise
    """
    if not user or not user.is_authenticated:
        return False
    
    try:
        from apps.businesses.models import BusinessMember
        membership = BusinessMember.objects.get(
            business=business,
            user=user,
            is_active=True
        )
        
        return BusinessPermissions.has_permission(membership.role, permission)
        
    except BusinessMember.DoesNotExist:
        return False


def get_user_business_role(user, business) -> Optional[str]:
    """
    Get the user's role in a specific business.
    
    Args:
        user: The user to check
        business: The business object
        
    Returns:
        str: The user's role or None if not a member
    """
    if not user or not user.is_authenticated:
        return None
    
    try:
        from apps.businesses.models import BusinessMember
        membership = BusinessMember.objects.get(
            business=business,
            user=user,
            is_active=True
        )
        
        return membership.role
        
    except BusinessMember.DoesNotExist:
        return None


def get_user_permissions_for_business(user, business) -> List[str]:
    """
    Get all permissions a user has for a specific business.
    
    Args:
        user: The user to check
        business: The business object
        
    Returns:
        List[str]: List of permission strings
    """
    role = get_user_business_role(user, business)
    if not role:
        return []
    
    return BusinessPermissions.get_permissions_for_role(role)