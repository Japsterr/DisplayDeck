"""
Real-time notification system for DisplayDeck.

Handles system notifications, alerts, and real-time communication
between different components of the DisplayDeck system.
"""

import logging
from enum import Enum
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta
from dataclasses import dataclass
from django.utils import timezone
from django.core.cache import cache
from django.conf import settings

from apps.common.websocket_services import WebSocketService
from apps.displays.models import Display
from apps.businesses.models import Business
from apps.menus.models import Menu
from apps.authentication.models import User

logger = logging.getLogger(__name__)


class NotificationType(Enum):
    """Types of notifications in the system."""
    # Display notifications
    DISPLAY_ONLINE = "display_online"
    DISPLAY_OFFLINE = "display_offline"
    DISPLAY_ERROR = "display_error"
    DISPLAY_PAIRED = "display_paired"
    DISPLAY_UNPAIRED = "display_unpaired"
    DISPLAY_RESTART_REQUIRED = "display_restart_required"
    DISPLAY_UPDATE_AVAILABLE = "display_update_available"
    
    # Menu notifications
    MENU_PUBLISHED = "menu_published"
    MENU_UPDATED = "menu_updated"
    MENU_SYNC_FAILED = "menu_sync_failed"
    MENU_PRICE_CHANGED = "menu_price_changed"
    MENU_ITEM_OUT_OF_STOCK = "menu_item_out_of_stock"
    
    # System notifications
    SYSTEM_MAINTENANCE = "system_maintenance"
    SYSTEM_ERROR = "system_error"
    BACKUP_COMPLETED = "backup_completed"
    BACKUP_FAILED = "backup_failed"
    
    # Business notifications
    BUSINESS_ANALYTICS_READY = "business_analytics_ready"
    BUSINESS_QUOTA_WARNING = "business_quota_warning"
    BUSINESS_SUBSCRIPTION_EXPIRING = "business_subscription_expiring"
    
    # Security notifications
    SECURITY_LOGIN_FAILURE = "security_login_failure"
    SECURITY_SUSPICIOUS_ACTIVITY = "security_suspicious_activity"
    SECURITY_PASSWORD_RESET = "security_password_reset"


class NotificationPriority(Enum):
    """Priority levels for notifications."""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


@dataclass
class Notification:
    """Notification data structure."""
    id: str
    type: NotificationType
    priority: NotificationPriority
    title: str
    message: str
    data: Dict[str, Any]
    timestamp: datetime
    business_id: Optional[str] = None
    user_id: Optional[str] = None
    display_id: Optional[str] = None
    expires_at: Optional[datetime] = None
    read: bool = False
    acknowledged: bool = False


class NotificationService(WebSocketService):
    """
    Main service for handling real-time notifications.
    """
    
    NOTIFICATION_TTL = 86400  # 24 hours
    CRITICAL_NOTIFICATION_TTL = 604800  # 7 days
    
    @classmethod
    def create_notification(cls, 
                          notification_type: NotificationType,
                          title: str,
                          message: str,
                          priority: NotificationPriority = NotificationPriority.MEDIUM,
                          business_id: str = None,
                          user_id: str = None,
                          display_id: str = None,
                          data: Dict[str, Any] = None,
                          expires_at: datetime = None) -> Notification:
        """
        Create and send a new notification.
        
        Args:
            notification_type: Type of notification
            title: Notification title
            message: Notification message
            priority: Priority level
            business_id: Business this notification belongs to
            user_id: Specific user to notify
            display_id: Display this notification relates to
            data: Additional notification data
            expires_at: When notification expires
            
        Returns:
            Created notification
        """
        import uuid
        
        # Generate notification ID
        notification_id = str(uuid.uuid4())
        
        # Set expiry based on priority if not specified
        if not expires_at:
            if priority == NotificationPriority.CRITICAL:
                expires_at = timezone.now() + timedelta(seconds=cls.CRITICAL_NOTIFICATION_TTL)
            else:
                expires_at = timezone.now() + timedelta(seconds=cls.NOTIFICATION_TTL)
        
        # Create notification
        notification = Notification(
            id=notification_id,
            type=notification_type,
            priority=priority,
            title=title,
            message=message,
            data=data or {},
            timestamp=timezone.now(),
            business_id=business_id,
            user_id=user_id,
            display_id=display_id,
            expires_at=expires_at
        )
        
        # Store notification
        cls._store_notification(notification)
        
        # Send notification via WebSocket
        cls._send_notification(notification)
        
        # Send additional notifications based on priority
        if priority == NotificationPriority.CRITICAL:
            cls._handle_critical_notification(notification)
        
        logger.info(f"Notification created: {notification_type.value} for business {business_id}")
        
        return notification
    
    @classmethod
    def display_online_notification(cls, display: Display):
        """Send notification when display comes online."""
        cls.create_notification(
            NotificationType.DISPLAY_ONLINE,
            f"Display Online",
            f"Display '{display.name}' at {display.location} is now online.",
            priority=NotificationPriority.LOW,
            business_id=str(display.business_id),
            display_id=str(display.id),
            data={
                'display_name': display.name,
                'location': display.location,
                'status': display.status
            }
        )
    
    @classmethod
    def display_offline_notification(cls, display: Display, offline_duration: timedelta = None):
        """Send notification when display goes offline."""
        priority = NotificationPriority.MEDIUM
        if offline_duration and offline_duration.total_seconds() > 3600:  # More than 1 hour
            priority = NotificationPriority.HIGH
        
        message = f"Display '{display.name}' at {display.location} is offline."
        if offline_duration:
            hours = int(offline_duration.total_seconds() / 3600)
            if hours > 0:
                message += f" Offline for {hours} hours."
        
        cls.create_notification(
            NotificationType.DISPLAY_OFFLINE,
            f"Display Offline",
            message,
            priority=priority,
            business_id=str(display.business_id),
            display_id=str(display.id),
            data={
                'display_name': display.name,
                'location': display.location,
                'offline_duration_seconds': offline_duration.total_seconds() if offline_duration else 0
            }
        )
    
    @classmethod
    def display_error_notification(cls, display: Display, error: str, error_type: str = 'general'):
        """Send notification when display encounters an error."""
        priority = NotificationPriority.HIGH
        if 'critical' in error.lower() or 'failed' in error.lower():
            priority = NotificationPriority.CRITICAL
        
        cls.create_notification(
            NotificationType.DISPLAY_ERROR,
            f"Display Error",
            f"Display '{display.name}' encountered an error: {error}",
            priority=priority,
            business_id=str(display.business_id),
            display_id=str(display.id),
            data={
                'display_name': display.name,
                'location': display.location,
                'error': error,
                'error_type': error_type
            }
        )
    
    @classmethod
    def menu_published_notification(cls, menu: Menu, display_count: int):
        """Send notification when menu is published."""
        cls.create_notification(
            NotificationType.MENU_PUBLISHED,
            f"Menu Published",
            f"Menu '{menu.name}' has been published to {display_count} displays.",
            priority=NotificationPriority.LOW,
            business_id=str(menu.business_id),
            data={
                'menu_id': str(menu.id),
                'menu_name': menu.name,
                'version': menu.version,
                'display_count': display_count
            }
        )
    
    @classmethod
    def menu_sync_failed_notification(cls, menu: Menu, failed_displays: List[str], error: str):
        """Send notification when menu sync fails."""
        cls.create_notification(
            NotificationType.MENU_SYNC_FAILED,
            f"Menu Sync Failed",
            f"Failed to sync menu '{menu.name}' to {len(failed_displays)} displays: {error}",
            priority=NotificationPriority.HIGH,
            business_id=str(menu.business_id),
            data={
                'menu_id': str(menu.id),
                'menu_name': menu.name,
                'failed_displays': failed_displays,
                'error': error
            }
        )
    
    @classmethod
    def price_changed_notification(cls, menu: Menu, item_name: str, old_price: float, new_price: float):
        """Send notification for price changes."""
        cls.create_notification(
            NotificationType.MENU_PRICE_CHANGED,
            f"Price Updated",
            f"Price for '{item_name}' changed from ${old_price:.2f} to ${new_price:.2f}",
            priority=NotificationPriority.LOW,
            business_id=str(menu.business_id),
            data={
                'menu_id': str(menu.id),
                'menu_name': menu.name,
                'item_name': item_name,
                'old_price': old_price,
                'new_price': new_price
            }
        )
    
    @classmethod
    def system_maintenance_notification(cls, start_time: datetime, duration: int, message: str):
        """Send system maintenance notification."""
        cls.create_notification(
            NotificationType.SYSTEM_MAINTENANCE,
            f"Scheduled Maintenance",
            f"System maintenance scheduled for {start_time.strftime('%Y-%m-%d %H:%M')} UTC. Duration: {duration} minutes. {message}",
            priority=NotificationPriority.MEDIUM,
            data={
                'start_time': start_time.isoformat(),
                'duration_minutes': duration,
                'message': message
            }
        )
    
    @classmethod
    def security_login_failure_notification(cls, user: User, ip_address: str, attempt_count: int):
        """Send notification for failed login attempts."""
        priority = NotificationPriority.HIGH if attempt_count >= 5 else NotificationPriority.MEDIUM
        
        cls.create_notification(
            NotificationType.SECURITY_LOGIN_FAILURE,
            f"Failed Login Attempt",
            f"Failed login attempt for user {user.email} from IP {ip_address}. Attempt #{attempt_count}",
            priority=priority,
            user_id=str(user.id),
            data={
                'user_email': user.email,
                'ip_address': ip_address,
                'attempt_count': attempt_count
            }
        )
    
    @classmethod
    def get_notifications_for_business(cls, business_id: str, limit: int = 50, 
                                     include_read: bool = False) -> List[Dict[str, Any]]:
        """Get notifications for a business."""
        cache_key = f"notifications:business:{business_id}"
        
        # Try to get from cache first
        cached_notifications = cache.get(cache_key)
        if cached_notifications:
            notifications = cached_notifications
        else:
            notifications = []
        
        # Filter notifications
        filtered_notifications = []
        for notification_data in notifications:
            if not include_read and notification_data.get('read', False):
                continue
            
            # Check if expired
            expires_at = datetime.fromisoformat(notification_data.get('expires_at'))
            if timezone.now() > expires_at:
                continue
            
            filtered_notifications.append(notification_data)
        
        # Sort by timestamp (newest first) and limit
        filtered_notifications.sort(key=lambda x: x['timestamp'], reverse=True)
        return filtered_notifications[:limit]
    
    @classmethod
    def mark_notification_read(cls, notification_id: str, user_id: str = None):
        """Mark a notification as read."""
        # This would typically update the notification in database
        # For now, we'll update the cached version
        
        # Find and update notification in cache
        # Implementation would depend on storage strategy
        pass
    
    @classmethod
    def acknowledge_notification(cls, notification_id: str, user_id: str = None):
        """Acknowledge a notification (for critical notifications)."""
        # Similar to mark_read but for acknowledgment
        pass
    
    @classmethod
    def _store_notification(cls, notification: Notification):
        """Store notification for persistence."""
        # Store in cache with business/user keys
        if notification.business_id:
            business_cache_key = f"notifications:business:{notification.business_id}"
            business_notifications = cache.get(business_cache_key, [])
            
            business_notifications.append({
                'id': notification.id,
                'type': notification.type.value,
                'priority': notification.priority.value,
                'title': notification.title,
                'message': notification.message,
                'data': notification.data,
                'timestamp': notification.timestamp.isoformat(),
                'expires_at': notification.expires_at.isoformat() if notification.expires_at else None,
                'display_id': notification.display_id,
                'read': notification.read,
                'acknowledged': notification.acknowledged
            })
            
            # Keep only last 100 notifications per business
            if len(business_notifications) > 100:
                business_notifications = business_notifications[-100:]
            
            cache.set(business_cache_key, business_notifications, cls.NOTIFICATION_TTL)
        
        # Store individual notification
        cache.set(f"notification:{notification.id}", notification, cls.NOTIFICATION_TTL)
    
    @classmethod
    def _send_notification(cls, notification: Notification):
        """Send notification via WebSocket."""
        notification_data = {
            'type': 'notification',
            'notification_type': notification.type.value,
            'data': {
                'id': notification.id,
                'priority': notification.priority.value,
                'title': notification.title,
                'message': notification.message,
                'data': notification.data,
                'timestamp': notification.timestamp.isoformat(),
                'display_id': notification.display_id
            }
        }
        
        # Send to business admins
        if notification.business_id:
            business_group = f"business_{notification.business_id}_admins"
            cls.send_to_group(business_group, {
                'type': 'business_notification',
                **notification_data
            })
        
        # Send to specific user if specified
        if notification.user_id:
            user_group = f"user_{notification.user_id}_notifications"
            cls.send_to_group(user_group, notification_data)
    
    @classmethod
    def _handle_critical_notification(cls, notification: Notification):
        """Handle critical notifications with additional actions."""
        # For critical notifications, you might want to:
        # - Send email alerts
        # - Send SMS/push notifications
        # - Log to external monitoring systems
        # - Trigger automated responses
        
        logger.critical(f"Critical notification: {notification.title} - {notification.message}")
        
        # Example: Send to monitoring system
        # This would integrate with external services like PagerDuty, Slack, etc.
        cls._send_to_external_monitoring(notification)
    
    @classmethod
    def _send_to_external_monitoring(cls, notification: Notification):
        """Send critical notifications to external monitoring systems."""
        # Implementation would depend on the monitoring system
        # Examples: PagerDuty, Datadog, Slack webhooks, etc.
        
        if hasattr(settings, 'MONITORING_WEBHOOK_URL') and settings.MONITORING_WEBHOOK_URL:
            try:
                import requests
                
                payload = {
                    'severity': notification.priority.value,
                    'summary': notification.title,
                    'source': 'DisplayDeck',
                    'component': 'notification_service',
                    'details': {
                        'message': notification.message,
                        'type': notification.type.value,
                        'business_id': notification.business_id,
                        'display_id': notification.display_id,
                        'data': notification.data
                    }
                }
                
                requests.post(settings.MONITORING_WEBHOOK_URL, json=payload, timeout=10)
            except Exception as e:
                logger.error(f"Failed to send notification to monitoring system: {e}")


class AlertManager:
    """
    Manager for system alerts and automated responses.
    """
    
    @classmethod
    def check_display_health_alerts(cls):
        """Check for display health issues and create alerts."""
        from apps.displays.models import Display
        
        # Check for offline displays
        offline_threshold = timezone.now() - timedelta(minutes=10)
        offline_displays = Display.objects.filter(
            is_active=True,
            last_seen_at__lt=offline_threshold,
            status__in=['online', 'updating']  # Should be online but haven't been seen
        )
        
        for display in offline_displays:
            offline_duration = timezone.now() - display.last_seen_at
            NotificationService.display_offline_notification(display, offline_duration)
        
        # Check for displays with errors
        error_displays = Display.objects.filter(
            is_active=True,
            last_error__isnull=False
        ).exclude(last_error='')
        
        for display in error_displays:
            # Only send notification if error is recent (within last hour)
            if display.last_error_at and (timezone.now() - display.last_error_at).total_seconds() < 3600:
                NotificationService.display_error_notification(
                    display, display.last_error, 'system'
                )
    
    @classmethod
    def check_menu_sync_alerts(cls):
        """Check for menu synchronization issues."""
        # Implementation would check for failed menu syncs
        # and create appropriate notifications
        pass
    
    @classmethod
    def check_system_health_alerts(cls):
        """Check overall system health and create alerts."""
        # Implementation would check:
        # - Database connectivity
        # - Redis connectivity
        # - WebSocket service health
        # - External service availability
        pass


# Utility functions for common notification scenarios

def notify_display_paired(display: Display, user: User):
    """Convenience function for display pairing notification."""
    NotificationService.create_notification(
        NotificationType.DISPLAY_PAIRED,
        "Display Paired",
        f"Display '{display.name}' has been paired by {user.first_name} {user.last_name}",
        priority=NotificationPriority.LOW,
        business_id=str(display.business_id),
        display_id=str(display.id),
        data={
            'display_name': display.name,
            'location': display.location,
            'paired_by': f"{user.first_name} {user.last_name}".strip() or user.email
        }
    )


def notify_menu_item_out_of_stock(menu_item, user: User = None):
    """Convenience function for out of stock notification."""
    NotificationService.create_notification(
        NotificationType.MENU_ITEM_OUT_OF_STOCK,
        "Item Out of Stock",
        f"Menu item '{menu_item.name}' is now out of stock",
        priority=NotificationPriority.MEDIUM,
        business_id=str(menu_item.category.menu.business_id),
        data={
            'item_id': str(menu_item.id),
            'item_name': menu_item.name,
            'category_name': menu_item.category.name,
            'menu_name': menu_item.category.menu.name
        }
    )