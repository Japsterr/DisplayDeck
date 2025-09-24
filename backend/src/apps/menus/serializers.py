"""
Menu serializers for DisplayDeck API.

Provides serialization for menu structures with category and item nesting.
Supports different levels of detail for various API endpoints.
"""

from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.db import models
from decimal import Decimal
from typing import Dict, List, Optional

from .models import Menu, MenuCategory, MenuItem
from common.permissions import BusinessPermissions, check_business_permission

User = get_user_model()


class MenuItemCompactSerializer(serializers.ModelSerializer):
    """
    Compact serializer for menu items - used in nested representations.
    
    Contains essential information without heavy nested data.
    """
    
    is_available = serializers.SerializerMethodField()
    discount_percentage = serializers.SerializerMethodField()
    profit_margin = serializers.SerializerMethodField()
    price_display = serializers.SerializerMethodField()
    
    class Meta:
        model = MenuItem
        fields = [
            'id', 'name', 'slug', 'short_description', 'price', 'compare_at_price',
            'price_display', 'discount_percentage', 'item_type', 'image', 
            'is_active', 'is_featured', 'is_popular', 'is_available',
            'calories', 'prep_time_minutes', 'tags', 'sort_order', 'profit_margin'
        ]
        read_only_fields = ['id', 'slug', 'is_available', 'discount_percentage', 
                           'profit_margin', 'price_display']
    
    def get_is_available(self, obj) -> bool:
        """Check if item is currently available."""
        return obj.is_available_now()
    
    def get_discount_percentage(self, obj) -> Optional[float]:
        """Get discount percentage if applicable."""
        return obj.get_discount_percentage()
    
    def get_profit_margin(self, obj) -> Optional[float]:
        """Get profit margin (only for users with analytics permission)."""
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return None
        
        # Check if user has analytics permission for this business
        if not check_business_permission(request.user, obj.menu.business, 
                                       BusinessPermissions.VIEW_ANALYTICS):
            return None
        
        return obj.get_profit_margin()
    
    def get_price_display(self, obj) -> str:
        """Format price for display."""
        return f"${obj.price:.2f}"


class MenuItemDetailSerializer(serializers.ModelSerializer):
    """
    Detailed serializer for menu items - used for full item information.
    
    Includes all item details, customization options, and availability info.
    """
    
    category_name = serializers.CharField(source='category.name', read_only=True)
    category_slug = serializers.CharField(source='category.slug', read_only=True)
    is_available = serializers.SerializerMethodField()
    discount_percentage = serializers.SerializerMethodField()
    profit_margin = serializers.SerializerMethodField()
    price_display = serializers.SerializerMethodField()
    is_low_stock = serializers.SerializerMethodField()
    is_out_of_stock = serializers.SerializerMethodField()
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True)
    last_updated_by_name = serializers.CharField(source='last_updated_by.get_full_name', read_only=True)
    
    class Meta:
        model = MenuItem
        fields = [
            'id', 'name', 'slug', 'description', 'short_description', 
            'price', 'compare_at_price', 'cost_price', 'price_display', 
            'discount_percentage', 'profit_margin',
            'item_type', 'calories', 'prep_time_minutes', 
            'dietary_info', 'tags', 'image', 'gallery_images',
            'is_active', 'is_featured', 'is_popular', 'is_available',
            'is_low_stock', 'is_out_of_stock',
            'sort_order', 'track_inventory', 'inventory_count', 'low_stock_threshold',
            'available_from', 'available_until', 'available_days',
            'customization_options', 'category_name', 'category_slug',
            'created_at', 'updated_at', 'created_by_name', 'last_updated_by_name'
        ]
        read_only_fields = [
            'id', 'slug', 'is_available', 'discount_percentage', 'profit_margin',
            'price_display', 'is_low_stock', 'is_out_of_stock',
            'category_name', 'category_slug', 'created_at', 'updated_at',
            'created_by_name', 'last_updated_by_name'
        ]
    
    def get_is_available(self, obj) -> bool:
        """Check if item is currently available."""
        return obj.is_available_now()
    
    def get_discount_percentage(self, obj) -> Optional[float]:
        """Get discount percentage if applicable."""
        return obj.get_discount_percentage()
    
    def get_profit_margin(self, obj) -> Optional[float]:
        """Get profit margin (only for users with analytics permission)."""
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return None
        
        # Check if user has analytics permission for this business
        if not check_business_permission(request.user, obj.menu.business, 
                                       BusinessPermissions.VIEW_ANALYTICS):
            return None
        
        return obj.get_profit_margin()
    
    def get_price_display(self, obj) -> str:
        """Format price for display."""
        return f"${obj.price:.2f}"
    
    def get_is_low_stock(self, obj) -> bool:
        """Check if item is low on stock."""
        return obj.is_low_stock()
    
    def get_is_out_of_stock(self, obj) -> bool:
        """Check if item is out of stock."""
        return obj.is_out_of_stock()


class MenuItemCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating menu items.
    
    Handles validation and creation of new menu items with business logic.
    """
    
    class Meta:
        model = MenuItem
        fields = [
            'name', 'description', 'short_description', 'category',
            'price', 'compare_at_price', 'cost_price', 'item_type',
            'calories', 'prep_time_minutes', 'dietary_info', 'tags',
            'image', 'gallery_images', 'is_active', 'is_featured', 'is_popular',
            'sort_order', 'track_inventory', 'inventory_count', 'low_stock_threshold',
            'available_from', 'available_until', 'available_days',
            'customization_options'
        ]
    
    def validate_category(self, value):
        """Validate that category belongs to the same business as the menu."""
        if value and hasattr(self, 'context') and 'menu' in self.context:
            menu = self.context['menu']
            if value.business != menu.business:
                raise serializers.ValidationError(
                    "Category must belong to the same business as the menu."
                )
        return value
    
    def validate_price(self, value):
        """Validate price is positive."""
        if value <= 0:
            raise serializers.ValidationError("Price must be greater than zero.")
        return value
    
    def validate_compare_at_price(self, value):
        """Validate compare at price is higher than regular price."""
        if value is not None and 'price' in self.initial_data:
            price = Decimal(str(self.initial_data['price']))
            if value <= price:
                raise serializers.ValidationError(
                    "Compare at price must be higher than the regular price."
                )
        return value
    
    def validate_inventory_count(self, value):
        """Validate inventory count is non-negative."""
        if value < 0:
            raise serializers.ValidationError("Inventory count cannot be negative.")
        return value
    
    def validate(self, attrs):
        """Cross-field validation."""
        # Validate availability times
        available_from = attrs.get('available_from')
        available_until = attrs.get('available_until')
        
        if available_from and available_until and available_from >= available_until:
            raise serializers.ValidationError({
                'available_until': "Available until time must be after available from time."
            })
        
        return attrs
    
    def create(self, validated_data):
        """Create menu item with proper context."""
        menu = self.context['menu']
        request = self.context.get('request')
        
        validated_data['menu'] = menu
        if request and request.user.is_authenticated:
            validated_data['created_by'] = request.user
            validated_data['last_updated_by'] = request.user
        
        return super().create(validated_data)


class MenuCategoryCompactSerializer(serializers.ModelSerializer):
    """
    Compact serializer for menu categories - used in nested representations.
    """
    
    is_available = serializers.SerializerMethodField()
    items_count = serializers.SerializerMethodField()
    path = serializers.SerializerMethodField()
    
    class Meta:
        model = MenuCategory
        fields = [
            'id', 'name', 'slug', 'description', 'image', 'icon', 'color',
            'sort_order', 'is_active', 'is_featured', 'is_available',
            'items_count', 'path'
        ]
        read_only_fields = ['id', 'slug', 'is_available', 'items_count', 'path']
    
    def get_is_available(self, obj) -> bool:
        """Check if category is currently available."""
        return obj.is_available_now()
    
    def get_items_count(self, obj) -> int:
        """Get count of active items in this category."""
        return obj.get_active_items_count()
    
    def get_path(self, obj) -> str:
        """Get full category path."""
        return obj.get_full_path()


class MenuCategoryWithItemsSerializer(serializers.ModelSerializer):
    """
    Category serializer that includes nested menu items.
    
    Used for displaying menu structure with categories and their items.
    """
    
    items = MenuItemCompactSerializer(source='menu_items', many=True, read_only=True)
    subcategories = serializers.SerializerMethodField()
    is_available = serializers.SerializerMethodField()
    items_count = serializers.SerializerMethodField()
    path = serializers.SerializerMethodField()
    level = serializers.SerializerMethodField()
    
    class Meta:
        model = MenuCategory
        fields = [
            'id', 'name', 'slug', 'description', 'image', 'icon', 'color',
            'sort_order', 'is_active', 'is_featured', 'is_available',
            'items_count', 'path', 'level', 'items', 'subcategories',
            'available_from', 'available_until', 'available_days'
        ]
        read_only_fields = [
            'id', 'slug', 'is_available', 'items_count', 'path', 'level',
            'items', 'subcategories'
        ]
    
    def get_subcategories(self, obj):
        """Get subcategories recursively."""
        subcategories = obj.subcategories.filter(is_active=True).order_by('sort_order', 'name')
        return MenuCategoryCompactSerializer(subcategories, many=True, context=self.context).data
    
    def get_is_available(self, obj) -> bool:
        """Check if category is currently available."""
        return obj.is_available_now()
    
    def get_items_count(self, obj) -> int:
        """Get count of active items in this category."""
        return obj.get_active_items_count()
    
    def get_path(self, obj) -> str:
        """Get full category path."""
        return obj.get_full_path()
    
    def get_level(self, obj) -> int:
        """Get category nesting level."""
        return obj.get_level()


class MenuCompactSerializer(serializers.ModelSerializer):
    """
    Compact serializer for menus - used in lists and references.
    """
    
    business_name = serializers.CharField(source='business.name', read_only=True)
    is_available = serializers.SerializerMethodField()
    categories_count = serializers.SerializerMethodField()
    last_updated_by_name = serializers.CharField(source='last_updated_by.get_full_name', read_only=True)
    
    class Meta:
        model = Menu
        fields = [
            'id', 'name', 'slug', 'description', 'menu_type', 'version',
            'layout', 'theme_color', 'is_active', 'is_default', 'is_available',
            'total_items', 'categories_count', 'business_name',
            'last_updated_by_name', 'created_at', 'updated_at', 'published_at'
        ]
        read_only_fields = [
            'id', 'slug', 'is_available', 'categories_count', 'total_items',
            'business_name', 'last_updated_by_name', 'created_at', 'updated_at',
            'published_at'
        ]
    
    def get_is_available(self, obj) -> bool:
        """Check if menu is currently available."""
        return obj.is_available_now()
    
    def get_categories_count(self, obj) -> int:
        """Get count of categories in this menu."""
        return obj.get_categories().count()


class MenuDetailSerializer(serializers.ModelSerializer):
    """
    Detailed serializer for menus with full information.
    
    Includes business details, statistics, and metadata.
    """
    
    business_name = serializers.CharField(source='business.name', read_only=True)
    business_id = serializers.UUIDField(source='business.id', read_only=True)
    is_available = serializers.SerializerMethodField()
    categories_count = serializers.SerializerMethodField()
    last_updated_by_name = serializers.CharField(source='last_updated_by.get_full_name', read_only=True)
    statistics = serializers.SerializerMethodField()
    
    class Meta:
        model = Menu
        fields = [
            'id', 'name', 'slug', 'description', 'menu_type', 'version', 'version_notes',
            'background_image', 'theme_color', 'layout', 
            'is_active', 'is_default', 'is_available',
            'available_from', 'available_until', 'available_days',
            'total_items', 'categories_count', 'statistics',
            'business_name', 'business_id', 'last_updated_by_name',
            'created_at', 'updated_at', 'published_at'
        ]
        read_only_fields = [
            'id', 'slug', 'is_available', 'categories_count', 'total_items',
            'statistics', 'business_name', 'business_id', 'last_updated_by_name',
            'created_at', 'updated_at', 'published_at'
        ]
    
    def get_is_available(self, obj) -> bool:
        """Check if menu is currently available."""
        return obj.is_available_now()
    
    def get_categories_count(self, obj) -> int:
        """Get count of categories in this menu."""
        return obj.get_categories().count()
    
    def get_statistics(self, obj) -> Dict:
        """Get menu statistics (only for users with analytics permission)."""
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return {}
        
        # Check if user has analytics permission for this business
        if not check_business_permission(request.user, obj.business, 
                                       BusinessPermissions.VIEW_ANALYTICS):
            return {}
        
        # Calculate statistics
        items = obj.menu_items.filter(is_active=True)
        categories = obj.get_categories()
        
        return {
            'total_items': items.count(),
            'featured_items': items.filter(is_featured=True).count(),
            'popular_items': items.filter(is_popular=True).count(),
            'out_of_stock_items': items.filter(track_inventory=True, inventory_count=0).count(),
            'low_stock_items': sum(1 for item in items if item.is_low_stock()),
            'total_categories': categories.count(),
            'active_categories': categories.filter(is_active=True).count(),
            'average_price': items.aggregate(avg_price=models.Avg('price'))['avg_price'] or 0,
            'price_range': {
                'min': items.aggregate(min_price=models.Min('price'))['min_price'] or 0,
                'max': items.aggregate(max_price=models.Max('price'))['max_price'] or 0,
            }
        }


class MenuWithCategoriesSerializer(serializers.ModelSerializer):
    """
    Menu serializer that includes full category and item structure.
    
    Used for displaying complete menu structure with nested categories and items.
    This is the main serializer for menu display endpoints.
    """
    
    categories = MenuCategoryWithItemsSerializer(source='get_categories', many=True, read_only=True)
    uncategorized_items = serializers.SerializerMethodField()
    business_name = serializers.CharField(source='business.name', read_only=True)
    is_available = serializers.SerializerMethodField()
    statistics = serializers.SerializerMethodField()
    
    class Meta:
        model = Menu
        fields = [
            'id', 'name', 'slug', 'description', 'menu_type', 'version',
            'background_image', 'theme_color', 'layout',
            'is_active', 'is_default', 'is_available',
            'available_from', 'available_until', 'available_days',
            'total_items', 'business_name', 'statistics',
            'categories', 'uncategorized_items',
            'created_at', 'updated_at', 'published_at'
        ]
        read_only_fields = [
            'id', 'slug', 'is_available', 'total_items', 'statistics',
            'business_name', 'categories', 'uncategorized_items',
            'created_at', 'updated_at', 'published_at'
        ]
    
    def get_uncategorized_items(self, obj):
        """Get items that don't belong to any category."""
        uncategorized_items = obj.menu_items.filter(
            category__isnull=True,
            is_active=True
        ).order_by('sort_order', 'name')
        
        return MenuItemCompactSerializer(
            uncategorized_items, 
            many=True, 
            context=self.context
        ).data
    
    def get_is_available(self, obj) -> bool:
        """Check if menu is currently available."""
        return obj.is_available_now()
    
    def get_statistics(self, obj) -> Dict:
        """Get basic menu statistics."""
        return {
            'total_items': obj.total_items,
            'total_categories': obj.get_categories().count(),
            'last_published': obj.published_at.isoformat() if obj.published_at else None
        }


class MenuCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating new menus.
    
    Handles validation and creation of menus with proper business context.
    """
    
    class Meta:
        model = Menu
        fields = [
            'name', 'description', 'menu_type', 'background_image', 
            'theme_color', 'layout', 'is_active', 'is_default',
            'available_from', 'available_until', 'available_days'
        ]
    
    def validate_name(self, value):
        """Validate menu name is unique within the business."""
        if hasattr(self, 'context') and 'business' in self.context:
            business = self.context['business']
            if Menu.objects.filter(business=business, name=value).exists():
                raise serializers.ValidationError(
                    f"Menu with name '{value}' already exists for this business."
                )
        return value
    
    def validate_theme_color(self, value):
        """Validate hex color format."""
        if value and not value.startswith('#'):
            value = f"#{value}"
        
        if value and len(value) != 7:
            raise serializers.ValidationError("Color must be in hex format (#RRGGBB)")
        
        return value
    
    def validate(self, attrs):
        """Cross-field validation."""
        # Validate availability times
        available_from = attrs.get('available_from')
        available_until = attrs.get('available_until')
        
        if available_from and available_until and available_from >= available_until:
            raise serializers.ValidationError({
                'available_until': "Available until time must be after available from time."
            })
        
        return attrs
    
    def create(self, validated_data):
        """Create menu with proper business context."""
        business = self.context['business']
        request = self.context.get('request')
        
        validated_data['business'] = business
        if request and request.user.is_authenticated:
            validated_data['last_updated_by'] = request.user
        
        return super().create(validated_data)


class MenuUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating existing menus.
    
    Handles partial updates and version tracking.
    """
    
    class Meta:
        model = Menu
        fields = [
            'name', 'description', 'menu_type', 'version_notes',
            'background_image', 'theme_color', 'layout', 
            'is_active', 'is_default',
            'available_from', 'available_until', 'available_days'
        ]
    
    def validate_name(self, value):
        """Validate menu name is unique within the business."""
        menu = self.instance
        if (menu and menu.business and 
            Menu.objects.filter(business=menu.business, name=value).exclude(pk=menu.pk).exists()):
            raise serializers.ValidationError(
                f"Menu with name '{value}' already exists for this business."
            )
        return value
    
    def validate_theme_color(self, value):
        """Validate hex color format."""
        if value and not value.startswith('#'):
            value = f"#{value}"
        
        if value and len(value) != 7:
            raise serializers.ValidationError("Color must be in hex format (#RRGGBB)")
        
        return value
    
    def update(self, instance, validated_data):
        """Update menu with version tracking."""
        request = self.context.get('request')
        
        # Track who updated the menu
        if request and request.user.is_authenticated:
            validated_data['last_updated_by'] = request.user
        
        # Auto-increment version for significant changes
        significant_fields = ['name', 'menu_type', 'layout', 'theme_color']
        if any(field in validated_data for field in significant_fields):
            # Simple version increment (could be enhanced with semantic versioning)
            current_version = instance.version or '1.0.0'
            try:
                major, minor, patch = map(int, current_version.split('.'))
                validated_data['version'] = f"{major}.{minor}.{patch + 1}"
            except (ValueError, AttributeError):
                validated_data['version'] = '1.0.1'
        
        return super().update(instance, validated_data)