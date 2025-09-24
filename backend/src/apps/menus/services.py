"""
Menu services for DisplayDeck.

Provides business logic for menu versioning, publishing, and synchronization.
Handles complex operations that go beyond simple CRUD.
"""

import json
import hashlib
from decimal import Decimal
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple
from django.db import transaction
from django.utils import timezone as django_timezone
from django.contrib.auth import get_user_model
from django.core.cache import cache

from .models import Menu, MenuItem, MenuCategory
from apps.businesses.models import Business

User = get_user_model()


class MenuVersionService:
    """
    Service for handling menu versioning and change tracking.
    
    Provides semantic versioning, change detection, and rollback capabilities.
    """
    
    @staticmethod
    def generate_menu_hash(menu: Menu) -> str:
        """
        Generate a hash of the menu structure for change detection.
        
        Args:
            menu: The menu to hash
            
        Returns:
            SHA-256 hash of menu structure
        """
        # Collect menu data in deterministic order
        menu_data = {
            'name': menu.name,
            'description': menu.description,
            'menu_type': menu.menu_type,
            'theme_color': menu.theme_color,
            'layout': menu.layout,
            'categories': []
        }
        
        # Add categories and items
        categories = menu.get_categories().order_by('sort_order', 'name')
        for category in categories:
            cat_data = {
                'name': category.name,
                'sort_order': category.sort_order,
                'items': []
            }
            
            items = category.menu_items.filter(is_active=True).order_by('sort_order', 'name')
            for item in items:
                item_data = {
                    'name': item.name,
                    'price': str(item.price),
                    'sort_order': item.sort_order,
                    'item_type': item.item_type
                }
                cat_data['items'].append(item_data)
            
            menu_data['categories'].append(cat_data)
        
        # Add uncategorized items
        uncategorized = menu.menu_items.filter(category__isnull=True, is_active=True).order_by('sort_order', 'name')
        menu_data['uncategorized'] = [
            {
                'name': item.name,
                'price': str(item.price),
                'sort_order': item.sort_order,
                'item_type': item.item_type
            }
            for item in uncategorized
        ]
        
        # Generate hash
        menu_json = json.dumps(menu_data, sort_keys=True, separators=(',', ':'))
        return hashlib.sha256(menu_json.encode()).hexdigest()
    
    @staticmethod
    def increment_version(current_version: str, change_type: str = 'patch') -> str:
        """
        Increment version number based on change type.
        
        Args:
            current_version: Current version string (e.g., "1.2.3")
            change_type: Type of change ('major', 'minor', 'patch')
            
        Returns:
            New version string
        """
        try:
            major, minor, patch = map(int, current_version.split('.'))
        except (ValueError, AttributeError):
            return '1.0.0'
        
        if change_type == 'major':
            return f"{major + 1}.0.0"
        elif change_type == 'minor':
            return f"{major}.{minor + 1}.0"
        else:  # patch
            return f"{major}.{minor}.{patch + 1}"
    
    @staticmethod
    def detect_change_type(old_menu: Menu, new_menu_data: Dict) -> str:
        """
        Detect the type of change between menu versions.
        
        Args:
            old_menu: Previous menu version
            new_menu_data: New menu data
            
        Returns:
            Change type: 'major', 'minor', or 'patch'
        """
        # Major changes: Layout, menu type, or structural changes
        major_fields = ['layout', 'menu_type']
        for field in major_fields:
            if getattr(old_menu, field) != new_menu_data.get(field, getattr(old_menu, field)):
                return 'major'
        
        # Check for structural changes (categories added/removed)
        current_categories = set(old_menu.get_categories().values_list('name', flat=True))
        # This would need to be calculated from new_menu_data in real implementation
        # For now, assume minor change if name or theme changes
        
        minor_fields = ['name', 'theme_color']
        for field in minor_fields:
            if getattr(old_menu, field) != new_menu_data.get(field, getattr(old_menu, field)):
                return 'minor'
        
        # Everything else is a patch change
        return 'patch'
    
    @staticmethod
    @transaction.atomic
    def create_menu_snapshot(menu: Menu, user: Optional[User] = None) -> Dict:
        """
        Create a snapshot of the menu for versioning.
        
        Args:
            menu: Menu to snapshot
            user: User creating the snapshot
            
        Returns:
            Dictionary containing snapshot data
        """
        snapshot = {
            'menu_id': str(menu.id),
            'version': menu.version,
            'created_at': django_timezone.now().isoformat(),
            'created_by': user.id if user else None,
            'hash': MenuVersionService.generate_menu_hash(menu),
            'menu_data': {
                'name': menu.name,
                'description': menu.description,
                'menu_type': menu.menu_type,
                'theme_color': menu.theme_color,
                'layout': menu.layout,
                'background_image': menu.background_image.url if menu.background_image else None,
                'available_from': menu.available_from.isoformat() if menu.available_from else None,
                'available_until': menu.available_until.isoformat() if menu.available_until else None,
                'available_days': menu.available_days,
                'is_active': menu.is_active,
                'is_default': menu.is_default,
            },
            'categories': [],
            'items': []
        }
        
        # Snapshot categories
        categories = menu.get_categories()
        for category in categories:
            cat_snapshot = {
                'id': str(category.id),
                'name': category.name,
                'slug': category.slug,
                'description': category.description,
                'parent_id': str(category.parent.id) if category.parent else None,
                'sort_order': category.sort_order,
                'color': category.color,
                'icon': category.icon,
                'is_active': category.is_active,
                'is_featured': category.is_featured,
            }
            snapshot['categories'].append(cat_snapshot)
        
        # Snapshot items
        items = menu.menu_items.all()
        for item in items:
            item_snapshot = {
                'id': str(item.id),
                'name': item.name,
                'slug': item.slug,
                'description': item.description,
                'short_description': item.short_description,
                'price': str(item.price),
                'compare_at_price': str(item.compare_at_price) if item.compare_at_price else None,
                'cost_price': str(item.cost_price) if item.cost_price else None,
                'item_type': item.item_type,
                'category_id': str(item.category.id) if item.category else None,
                'calories': item.calories,
                'prep_time_minutes': item.prep_time_minutes,
                'dietary_info': item.dietary_info,
                'tags': item.tags,
                'image': item.image.url if item.image else None,
                'is_active': item.is_active,
                'is_featured': item.is_featured,
                'is_popular': item.is_popular,
                'sort_order': item.sort_order,
                'track_inventory': item.track_inventory,
                'inventory_count': item.inventory_count,
                'customization_options': item.customization_options,
            }
            snapshot['items'].append(item_snapshot)
        
        # Store snapshot in cache with 30-day expiration
        cache_key = f"menu_snapshot:{menu.id}:{menu.version}"
        cache.set(cache_key, snapshot, timeout=30 * 24 * 60 * 60)
        
        return snapshot


class MenuPublishingService:
    """
    Service for handling menu publishing and distribution to displays.
    
    Manages the process of making menu changes live across all displays.
    """
    
    @staticmethod
    @transaction.atomic
    def publish_menu(menu: Menu, user: Optional[User] = None, force: bool = False) -> Dict:
        """
        Publish a menu to all associated displays.
        
        Args:
            menu: Menu to publish
            user: User performing the publish
            force: Force publish even if no changes detected
            
        Returns:
            Dictionary with publish results
        """
        now = django_timezone.now()
        
        # Create snapshot before publishing
        snapshot = MenuVersionService.create_menu_snapshot(menu, user)
        
        # Check if there are actual changes to publish
        if not force and menu.published_at:
            last_published_hash = cache.get(f"menu_hash_published:{menu.id}")
            current_hash = snapshot['hash']
            
            if last_published_hash == current_hash:
                return {
                    'success': False,
                    'message': 'No changes detected since last publish',
                    'published_at': menu.published_at
                }
        
        # Update menu publish status
        menu.published_at = now
        menu.last_updated_by = user
        menu.save(update_fields=['published_at', 'last_updated_by'])
        
        # Cache the published hash
        cache.set(f"menu_hash_published:{menu.id}", snapshot['hash'], timeout=365 * 24 * 60 * 60)
        
        # Get associated displays (will be implemented in display module)
        display_count = 0  # Placeholder until displays are implemented
        
        # Prepare broadcast data
        broadcast_data = {
            'action': 'menu_published',
            'menu_id': str(menu.id),
            'business_id': str(menu.business.id),
            'version': menu.version,
            'published_at': now.isoformat(),
            'hash': snapshot['hash']
        }
        
        # This is where we'd send WebSocket broadcasts to displays
        # Will be implemented in the WebSocket module
        
        return {
            'success': True,
            'message': f'Menu published successfully to {display_count} displays',
            'published_at': now,
            'version': menu.version,
            'hash': snapshot['hash'],
            'displays_notified': display_count
        }
    
    @staticmethod
    def get_publish_preview(menu: Menu) -> Dict:
        """
        Get a preview of what would be published.
        
        Args:
            menu: Menu to preview
            
        Returns:
            Preview data including changes and affected displays
        """
        # Generate current hash
        current_hash = MenuVersionService.generate_menu_hash(menu)
        
        # Get last published hash
        last_published_hash = cache.get(f"menu_hash_published:{menu.id}")
        
        has_changes = last_published_hash != current_hash
        
        # Count associated displays (placeholder)
        display_count = 0
        
        # Get menu statistics
        stats = {
            'total_items': menu.menu_items.filter(is_active=True).count(),
            'total_categories': menu.get_categories().filter(is_active=True).count(),
            'featured_items': menu.menu_items.filter(is_active=True, is_featured=True).count(),
            'out_of_stock': menu.menu_items.filter(
                is_active=True, 
                track_inventory=True, 
                inventory_count=0
            ).count()
        }
        
        return {
            'has_changes': has_changes,
            'current_hash': current_hash,
            'last_published_hash': last_published_hash,
            'last_published_at': menu.published_at.isoformat() if menu.published_at else None,
            'affected_displays': display_count,
            'menu_stats': stats,
            'estimated_sync_time': f"{display_count * 2}s" if display_count else "0s"
        }


class MenuSyncService:
    """
    Service for synchronizing menus across displays and handling offline scenarios.
    """
    
    @staticmethod
    def generate_sync_manifest(menu: Menu) -> Dict:
        """
        Generate a sync manifest for display clients.
        
        Args:
            menu: Menu to generate manifest for
            
        Returns:
            Sync manifest with versioning and checksums
        """
        snapshot = MenuVersionService.create_menu_snapshot(menu)
        
        # Generate manifest
        manifest = {
            'menu_id': str(menu.id),
            'business_id': str(menu.business.id),
            'version': menu.version,
            'hash': snapshot['hash'],
            'published_at': menu.published_at.isoformat() if menu.published_at else None,
            'last_modified': menu.updated_at.isoformat(),
            'sync_priority': 'high' if menu.is_default else 'normal',
            'display_settings': {
                'theme_color': menu.theme_color,
                'layout': menu.layout,
                'background_image': menu.background_image.url if menu.background_image else None
            },
            'content_checksums': {
                'categories': hashlib.md5(
                    json.dumps(snapshot['categories'], sort_keys=True).encode()
                ).hexdigest(),
                'items': hashlib.md5(
                    json.dumps(snapshot['items'], sort_keys=True).encode()
                ).hexdigest()
            },
            'availability': {
                'is_active': menu.is_active,
                'available_from': menu.available_from.isoformat() if menu.available_from else None,
                'available_until': menu.available_until.isoformat() if menu.available_until else None,
                'available_days': menu.available_days
            }
        }
        
        return manifest
    
    @staticmethod
    def check_sync_status(menu: Menu, client_version: str, client_hash: str) -> Dict:
        """
        Check if a client needs to sync with the latest menu version.
        
        Args:
            menu: Current menu
            client_version: Client's current version
            client_hash: Client's current content hash
            
        Returns:
            Sync status information
        """
        current_hash = MenuVersionService.generate_menu_hash(menu)
        needs_sync = client_hash != current_hash
        
        # Determine sync type
        sync_type = 'none'
        if needs_sync:
            try:
                client_major = int(client_version.split('.')[0])
                current_major = int(menu.version.split('.')[0])
                
                if client_major < current_major:
                    sync_type = 'full'
                elif client_version != menu.version:
                    sync_type = 'incremental'
                else:
                    sync_type = 'content'  # Same version, different content
            except (ValueError, IndexError):
                sync_type = 'full'
        
        return {
            'needs_sync': needs_sync,
            'sync_type': sync_type,
            'current_version': menu.version,
            'current_hash': current_hash,
            'client_version': client_version,
            'client_hash': client_hash,
            'last_published': menu.published_at.isoformat() if menu.published_at else None
        }
    
    @staticmethod
    def get_incremental_changes(menu: Menu, since_version: str) -> Dict:
        """
        Get incremental changes since a specific version.
        
        Args:
            menu: Current menu
            since_version: Version to compare against
            
        Returns:
            Dictionary of changes since the version
        """
        # This is a simplified implementation
        # In a real system, we'd store change logs between versions
        
        # For now, return full content if we can't determine incremental changes
        current_snapshot = MenuVersionService.create_menu_snapshot(menu)
        
        return {
            'since_version': since_version,
            'current_version': menu.version,
            'change_type': 'full',  # Would be 'incremental' if we had change tracking
            'changes': {
                'added_categories': [],
                'modified_categories': current_snapshot['categories'],
                'removed_categories': [],
                'added_items': [],
                'modified_items': current_snapshot['items'],
                'removed_items': [],
                'menu_settings': current_snapshot['menu_data']
            },
            'requires_full_reload': True  # Would be False for true incremental changes
        }


class MenuAnalyticsService:
    """
    Service for menu analytics and performance tracking.
    """
    
    @staticmethod
    def get_menu_performance_metrics(menu: Menu, days: int = 30) -> Dict:
        """
        Get performance metrics for a menu.
        
        Args:
            menu: Menu to analyze
            days: Number of days to analyze
            
        Returns:
            Performance metrics dictionary
        """
        # This would integrate with an analytics system
        # For now, return basic structural metrics
        
        items = menu.menu_items.filter(is_active=True)
        categories = menu.get_categories().filter(is_active=True)
        
        return {
            'structural_metrics': {
                'total_items': items.count(),
                'total_categories': categories.count(),
                'items_per_category': items.count() / max(categories.count(), 1),
                'featured_items_ratio': items.filter(is_featured=True).count() / max(items.count(), 1),
                'average_price': items.aggregate(avg_price=models.Avg('price'))['avg_price'] or 0,
                'price_distribution': {
                    'min': items.aggregate(min_price=models.Min('price'))['min_price'] or 0,
                    'max': items.aggregate(max_price=models.Max('price'))['max_price'] or 0,
                }
            },
            'availability_metrics': {
                'items_with_restrictions': items.exclude(
                    available_days=[], 
                    available_from__isnull=True, 
                    available_until__isnull=True
                ).count(),
                'inventory_tracked_items': items.filter(track_inventory=True).count(),
                'out_of_stock_items': items.filter(track_inventory=True, inventory_count=0).count(),
            },
            'content_quality': {
                'items_with_images': items.exclude(image='').count(),
                'items_with_descriptions': items.exclude(description='').count(),
                'items_with_dietary_info': items.exclude(dietary_info={}).count(),
            },
            'version_info': {
                'current_version': menu.version,
                'last_published': menu.published_at.isoformat() if menu.published_at else None,
                'last_updated': menu.updated_at.isoformat(),
            }
        }
    
    @staticmethod
    def suggest_menu_optimizations(menu: Menu) -> List[Dict]:
        """
        Suggest optimizations for menu structure and content.
        
        Args:
            menu: Menu to analyze
            
        Returns:
            List of optimization suggestions
        """
        suggestions = []
        items = menu.menu_items.filter(is_active=True)
        
        # Check for items without images
        items_without_images = items.filter(image='').count()
        if items_without_images > 0:
            suggestions.append({
                'type': 'content',
                'priority': 'medium',
                'title': 'Add images to menu items',
                'description': f'{items_without_images} items are missing images',
                'action': 'Add high-quality images to improve visual appeal'
            })
        
        # Check for items without descriptions
        items_without_descriptions = items.filter(description='').count()
        if items_without_descriptions > 0:
            suggestions.append({
                'type': 'content',
                'priority': 'low',
                'title': 'Add descriptions to menu items',
                'description': f'{items_without_descriptions} items are missing descriptions',
                'action': 'Add detailed descriptions to help customers make decisions'
            })
        
        # Check for unbalanced categories
        categories = menu.get_categories()
        if categories.exists():
            items_per_category = []
            for category in categories:
                item_count = category.menu_items.filter(is_active=True).count()
                items_per_category.append(item_count)
            
            if max(items_per_category) > 3 * min(items_per_category) and min(items_per_category) > 0:
                suggestions.append({
                    'type': 'structure',
                    'priority': 'low',
                    'title': 'Balance category sizes',
                    'description': 'Some categories have significantly more items than others',
                    'action': 'Consider redistributing items or creating subcategories'
                })
        
        # Check for pricing inconsistencies
        price_variance = items.aggregate(
            min_price=models.Min('price'),
            max_price=models.Max('price')
        )
        if price_variance['max_price'] and price_variance['min_price']:
            if price_variance['max_price'] > 5 * price_variance['min_price']:
                suggestions.append({
                    'type': 'pricing',
                    'priority': 'medium',
                    'title': 'Review pricing strategy',
                    'description': 'Large price variance detected across menu items',
                    'action': 'Consider organizing items by price tiers or reviewing pricing strategy'
                })
        
        return suggestions