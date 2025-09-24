"""
WebSocket services for DisplayDeck real-time communication.

Provides services for real-time menu synchronization, display status updates,
and business notifications across WebSocket connections.
"""

import json
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from django.utils import timezone
from django.core.cache import cache
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver

from apps.displays.models import Display, DisplaySession
from apps.menus.models import Menu, MenuItem, MenuCategory
from apps.businesses.models import Business

logger = logging.getLogger(__name__)
channel_layer = get_channel_layer()


class WebSocketService:
    """Base service for WebSocket communication."""
    
    @staticmethod
    def send_to_group(group_name: str, message: Dict[str, Any]):
        """Send message to a WebSocket group."""
        if channel_layer:
            async_to_sync(channel_layer.group_send)(group_name, message)
    
    @staticmethod
    def send_to_channel(channel_name: str, message: Dict[str, Any]):
        """Send message to a specific WebSocket channel."""
        if channel_layer:
            async_to_sync(channel_layer.send)(channel_name, message)
    
    @staticmethod
    def get_timestamp():
        """Get current timestamp in ISO format."""
        return datetime.now().isoformat()


class MenuSyncService(WebSocketService):
    """
    Service for real-time menu synchronization.
    
    Handles menu updates and synchronization across display devices
    when menu content changes.
    """
    
    @classmethod
    def sync_menu_to_displays(cls, menu: Menu, change_type: str = 'update', changed_fields: List[str] = None):
        """
        Synchronize menu changes to all displays using this menu.
        
        Args:
            menu: Menu object that was changed
            change_type: Type of change ('update', 'delete', 'publish')
            changed_fields: List of fields that changed
        """
        try:
            # Get all displays using this menu
            displays = Display.objects.filter(
                current_menu=menu,
                is_active=True,
                status='online'
            )
            
            # Prepare menu data
            menu_data = cls._serialize_menu_for_sync(menu)
            
            # Send to each display
            for display in displays:
                cls._send_menu_update_to_display(
                    display, menu_data, change_type, changed_fields
                )
            
            # Notify admin dashboards
            cls._notify_admins_menu_sync(menu, change_type, len(displays))
            
            logger.info(f"Menu {menu.id} synchronized to {len(displays)} displays")
            
        except Exception as e:
            logger.error(f"Error synchronizing menu {menu.id}: {e}")
    
    @classmethod
    def sync_menu_item_update(cls, menu_item: MenuItem, change_type: str = 'update'):
        """Sync individual menu item updates."""
        menu = menu_item.category.menu
        
        # Get displays using this menu
        displays = Display.objects.filter(
            current_menu=menu,
            is_active=True,
            status='online'
        )
        
        # Send item update to displays
        for display in displays:
            cls._send_item_update_to_display(display, menu_item, change_type)
        
        # Update menu timestamp
        menu.updated_at = timezone.now()
        menu.save(update_fields=['updated_at'])
        
        logger.info(f"Menu item {menu_item.id} synchronized to {len(displays)} displays")
    
    @classmethod
    def sync_menu_category_update(cls, category: MenuCategory, change_type: str = 'update'):
        """Sync menu category updates."""
        menu = category.menu
        cls.sync_menu_to_displays(menu, 'category_update', ['categories'])
    
    @classmethod
    def sync_price_update(cls, menu_item: MenuItem, old_price: float, new_price: float):
        """Handle real-time price updates."""
        menu = menu_item.category.menu
        
        # Get displays using this menu
        displays = Display.objects.filter(
            current_menu=menu,
            is_active=True,
            status='online'
        )
        
        # Send price update to displays
        for display in displays:
            display_group = f"display_{display.id}"
            cls.send_to_group(display_group, {
                'type': 'price_update',
                'menu_id': str(menu.id),
                'item_id': str(menu_item.id),
                'old_price': float(old_price),
                'new_price': float(new_price),
                'timestamp': cls.get_timestamp()
            })
        
        # Notify admins of price change
        business_group = f"business_{menu.business_id}_admins"
        cls.send_to_group(business_group, {
            'type': 'business_notification',
            'notification_type': 'price_update',
            'data': {
                'menu_name': menu.name,
                'item_name': menu_item.name,
                'old_price': float(old_price),
                'new_price': float(new_price),
                'displays_updated': len(displays)
            }
        })
        
        logger.info(f"Price update for item {menu_item.id} sent to {len(displays)} displays")
    
    @classmethod
    def sync_availability_update(cls, menu_item: MenuItem, is_available: bool):
        """Handle real-time availability updates."""
        menu = menu_item.category.menu
        
        # Get displays using this menu
        displays = Display.objects.filter(
            current_menu=menu,
            is_active=True,
            status='online'
        )
        
        # Send availability update to displays
        for display in displays:
            display_group = f"display_{display.id}"
            cls.send_to_group(display_group, {
                'type': 'availability_update',
                'menu_id': str(menu.id),
                'item_id': str(menu_item.id),
                'is_available': is_available,
                'timestamp': cls.get_timestamp()
            })
        
        logger.info(f"Availability update for item {menu_item.id} sent to {len(displays)} displays")
    
    @classmethod
    def _serialize_menu_for_sync(cls, menu: Menu) -> Dict[str, Any]:
        """Serialize menu data for WebSocket transmission."""
        # This would normally use DRF serializers
        return {
            'id': str(menu.id),
            'name': menu.name,
            'description': menu.description,
            'version': menu.version,
            'is_published': menu.is_published,
            'updated_at': menu.updated_at.isoformat(),
            'categories': [
                {
                    'id': str(category.id),
                    'name': category.name,
                    'description': category.description,
                    'display_order': category.display_order,
                    'is_active': category.is_active,
                    'items': [
                        {
                            'id': str(item.id),
                            'name': item.name,
                            'description': item.description,
                            'price': float(item.price),
                            'display_order': item.display_order,
                            'is_available': item.is_available,
                            'is_active': item.is_active,
                            'image_url': item.image.url if item.image else None
                        }
                        for item in category.items.filter(is_active=True).order_by('display_order')
                    ]
                }
                for category in menu.categories.filter(is_active=True).order_by('display_order')
            ]
        }
    
    @classmethod
    def _send_menu_update_to_display(cls, display: Display, menu_data: Dict[str, Any], 
                                   change_type: str, changed_fields: List[str]):
        """Send menu update to a specific display."""
        display_group = f"display_{display.id}"
        
        cls.send_to_group(display_group, {
            'type': 'menu_update',
            'change_type': change_type,
            'changed_fields': changed_fields or [],
            'menu': menu_data,
            'timestamp': cls.get_timestamp()
        })
    
    @classmethod
    def _send_item_update_to_display(cls, display: Display, menu_item: MenuItem, change_type: str):
        """Send menu item update to a specific display."""
        display_group = f"display_{display.id}"
        
        item_data = {
            'id': str(menu_item.id),
            'name': menu_item.name,
            'description': menu_item.description,
            'price': float(menu_item.price),
            'is_available': menu_item.is_available,
            'is_active': menu_item.is_active,
            'category_id': str(menu_item.category_id)
        }
        
        cls.send_to_group(display_group, {
            'type': 'item_update',
            'change_type': change_type,
            'item': item_data,
            'menu_id': str(menu_item.category.menu_id),
            'timestamp': cls.get_timestamp()
        })
    
    @classmethod
    def _notify_admins_menu_sync(cls, menu: Menu, change_type: str, display_count: int):
        """Notify admin dashboards of menu synchronization."""
        business_group = f"business_{menu.business_id}_admins"
        
        cls.send_to_group(business_group, {
            'type': 'business_notification',
            'notification_type': 'menu_sync',
            'data': {
                'menu_id': str(menu.id),
                'menu_name': menu.name,
                'change_type': change_type,
                'displays_updated': display_count,
                'timestamp': cls.get_timestamp()
            }
        })


class DisplayStatusService(WebSocketService):
    """
    Service for real-time display status updates and monitoring.
    """
    
    @classmethod
    def notify_display_status_change(cls, display: Display, old_status: str, new_status: str):
        """Notify admins of display status changes."""
        business_group = f"business_{display.business_id}_admins"
        
        cls.send_to_group(business_group, {
            'type': 'display_event',
            'event_type': 'status_change',
            'data': {
                'display_id': str(display.id),
                'display_name': display.name,
                'location': display.location,
                'old_status': old_status,
                'new_status': new_status,
                'timestamp': cls.get_timestamp()
            }
        })
        
        # Log status change
        logger.info(f"Display {display.id} status changed: {old_status} -> {new_status}")
    
    @classmethod
    def notify_display_error(cls, display: Display, error: str, error_type: str = 'general'):
        """Notify admins of display errors."""
        business_group = f"business_{display.business_id}_admins"
        
        cls.send_to_group(business_group, {
            'type': 'display_event',
            'event_type': 'error',
            'data': {
                'display_id': str(display.id),
                'display_name': display.name,
                'location': display.location,
                'error': error,
                'error_type': error_type,
                'timestamp': cls.get_timestamp()
            }
        })
        
        logger.warning(f"Display {display.id} error: {error}")
    
    @classmethod
    def notify_display_connection_change(cls, display: Display, connected: bool):
        """Notify admins of display connection changes."""
        business_group = f"business_{display.business_id}_admins"
        
        event_type = 'connected' if connected else 'disconnected'
        
        cls.send_to_group(business_group, {
            'type': 'display_event',
            'event_type': event_type,
            'data': {
                'display_id': str(display.id),
                'display_name': display.name,
                'location': display.location,
                'connected': connected,
                'timestamp': cls.get_timestamp()
            }
        })
    
    @classmethod
    def broadcast_display_command(cls, display: Display, command: str, parameters: Dict[str, Any] = None):
        """Broadcast command to display device."""
        display_group = f"display_{display.id}"
        
        cls.send_to_group(display_group, {
            'type': 'send_remote_command',
            'command': command,
            'parameters': parameters or {},
            'timestamp': cls.get_timestamp()
        })
        
        logger.info(f"Command '{command}' sent to display {display.id}")
    
    @classmethod
    def broadcast_display_restart(cls, display: Display):
        """Broadcast restart command to display."""
        cls.broadcast_display_command(display, 'restart')
        
        # Update display status
        display.status = 'updating'
        display.save(update_fields=['status'])
    
    @classmethod
    def notify_performance_alert(cls, display: Display, alert_type: str, metrics: Dict[str, Any]):
        """Notify admins of display performance issues."""
        business_group = f"business_{display.business_id}_admins"
        
        cls.send_to_group(business_group, {
            'type': 'display_event',
            'event_type': 'performance_alert',
            'data': {
                'display_id': str(display.id),
                'display_name': display.name,
                'location': display.location,
                'alert_type': alert_type,
                'metrics': metrics,
                'timestamp': cls.get_timestamp()
            }
        })


class BusinessNotificationService(WebSocketService):
    """
    Service for business-wide notifications and updates.
    """
    
    @classmethod
    def notify_menu_published(cls, business: Business, menu: Menu):
        """Notify business admins of menu publication."""
        business_group = f"business_{business.id}_admins"
        
        cls.send_to_group(business_group, {
            'type': 'business_notification',
            'notification_type': 'menu_published',
            'data': {
                'menu_id': str(menu.id),
                'menu_name': menu.name,
                'version': menu.version,
                'timestamp': cls.get_timestamp()
            }
        })
    
    @classmethod
    def notify_display_paired(cls, business: Business, display: Display, user):
        """Notify business admins of new display pairing."""
        business_group = f"business_{business.id}_admins"
        
        cls.send_to_group(business_group, {
            'type': 'business_notification',
            'notification_type': 'display_paired',
            'data': {
                'display_id': str(display.id),
                'display_name': display.name,
                'location': display.location,
                'paired_by': f"{user.first_name} {user.last_name}".strip() or user.email,
                'timestamp': cls.get_timestamp()
            }
        })
    
    @classmethod
    def notify_analytics_update(cls, business: Business, analytics_type: str, data: Dict[str, Any]):
        """Notify business admins of analytics updates."""
        business_group = f"business_{business.id}_admins"
        
        cls.send_to_group(business_group, {
            'type': 'business_notification',
            'notification_type': 'analytics_update',
            'data': {
                'analytics_type': analytics_type,
                'data': data,
                'timestamp': cls.get_timestamp()
            }
        })


# Signal handlers for automatic WebSocket notifications

@receiver(post_save, sender=Menu)
def handle_menu_update(sender, instance, created, **kwargs):
    """Handle menu updates via signals."""
    if not created:  # Only for updates, not new creations
        MenuSyncService.sync_menu_to_displays(instance, 'update')


@receiver(post_save, sender=MenuItem)
def handle_menu_item_update(sender, instance, created, **kwargs):
    """Handle menu item updates via signals."""
    if not created:  # Only for updates
        MenuSyncService.sync_menu_item_update(instance, 'update')


@receiver(post_delete, sender=MenuItem)
def handle_menu_item_delete(sender, instance, **kwargs):
    """Handle menu item deletions via signals."""
    MenuSyncService.sync_menu_item_update(instance, 'delete')


@receiver(post_save, sender=Display)
def handle_display_update(sender, instance, created, **kwargs):
    """Handle display status updates via signals."""
    if not created and hasattr(instance, '_old_status'):
        # Check if status changed
        if instance._old_status != instance.status:
            DisplayStatusService.notify_display_status_change(
                instance, instance._old_status, instance.status
            )


# Cache utilities for WebSocket performance

class WebSocketCache:
    """Utilities for caching WebSocket data."""
    
    @staticmethod
    def cache_menu_data(menu: Menu, ttl: int = 300):
        """Cache serialized menu data."""
        cache_key = f"ws_menu_data:{menu.id}"
        menu_data = MenuSyncService._serialize_menu_for_sync(menu)
        cache.set(cache_key, menu_data, ttl)
        return menu_data
    
    @staticmethod
    def get_cached_menu_data(menu_id: str):
        """Get cached menu data."""
        cache_key = f"ws_menu_data:{menu_id}"
        return cache.get(cache_key)
    
    @staticmethod
    def invalidate_menu_cache(menu_id: str):
        """Invalidate cached menu data."""
        cache_key = f"ws_menu_data:{menu_id}"
        cache.delete(cache_key)
    
    @staticmethod
    def cache_display_status(display: Display, ttl: int = 60):
        """Cache display status data."""
        cache_key = f"ws_display_status:{display.id}"
        status_data = {
            'id': str(display.id),
            'name': display.name,
            'status': display.status,
            'last_seen': display.last_seen_at.isoformat() if display.last_seen_at else None,
            'location': display.location
        }
        cache.set(cache_key, status_data, ttl)
        return status_data
    
    @staticmethod
    def get_cached_display_status(display_id: str):
        """Get cached display status."""
        cache_key = f"ws_display_status:{display_id}"
        return cache.get(cache_key)