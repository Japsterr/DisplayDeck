"""
Multi-screen coordination service with WebSocket broadcasting.

This service manages coordination between multiple display screens within a business,
enabling synchronized menu updates, coordinated promotions, and centralized display management.
"""

import logging
import json
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from django.core.cache import cache
from django.db import transaction
from django.utils import timezone
from apps.displays.models import DisplayDevice, DisplayGroup
from apps.businesses.models import BusinessAccount
from apps.menus.models import Menu
from apps.websockets.consumers import DisplayConsumer

logger = logging.getLogger(__name__)


class MultiScreenCoordinator:
    """Service for coordinating multiple display screens"""
    
    def __init__(self):
        self.channel_layer = get_channel_layer()
        
    def broadcast_to_business_displays(self, business_id: int, message: Dict[str, Any]):
        """Broadcast message to all displays in a business"""
        
        try:
            # Get all active displays for the business
            displays = DisplayDevice.objects.filter(
                business_id=business_id,
                is_active=True,
                is_online=True
            )
            
            if not displays.exists():
                logger.debug(f"No active displays found for business {business_id}")
                return
            
            # Add timestamp and business context
            message.update({
                'timestamp': datetime.now().isoformat(),
                'business_id': business_id,
                'message_id': self._generate_message_id()
            })
            
            # Broadcast to each display
            for display in displays:
                self._send_to_display(display, message)
                
            logger.info(f"Broadcasted message to {displays.count()} displays for business {business_id}")
            
        except Exception as e:
            logger.error(f"Error broadcasting to business displays: {str(e)}")
    
    def broadcast_to_display_group(self, group_id: int, message: Dict[str, Any]):
        """Broadcast message to all displays in a specific group"""
        
        try:
            # Get display group with related displays
            try:
                group = DisplayGroup.objects.get(id=group_id, is_active=True)
            except DisplayGroup.DoesNotExist:
                logger.warning(f"Display group {group_id} not found")
                return
            
            # Get displays in the group
            displays = group.displays.filter(is_active=True, is_online=True)
            
            if not displays.exists():
                logger.debug(f"No active displays found in group {group_id}")
                return
            
            # Add group context to message
            message.update({
                'timestamp': datetime.now().isoformat(),
                'business_id': group.business_id,
                'group_id': group_id,
                'group_name': group.name,
                'message_id': self._generate_message_id()
            })
            
            # Broadcast to each display in group
            for display in displays:
                self._send_to_display(display, message)
                
            logger.info(f"Broadcasted message to {displays.count()} displays in group '{group.name}'")
            
        except Exception as e:
            logger.error(f"Error broadcasting to display group: {str(e)}")
    
    def send_synchronized_menu_update(self, business_id: int, menu_id: int, update_type: str = 'update'):
        """Send synchronized menu update to all business displays"""
        
        try:
            # Get menu data
            try:
                from apps.menus.serializers import MenuDisplaySerializer
                from apps.menus.models import Menu
                
                menu = Menu.objects.get(id=menu_id, business_id=business_id)
                menu_data = MenuDisplaySerializer(menu).data
                
            except Menu.DoesNotExist:
                logger.warning(f"Menu {menu_id} not found for business {business_id}")
                return
            
            # Create synchronized update message
            message = {
                'type': 'menu_update',
                'action': update_type,
                'menu_id': menu_id,
                'menu_data': menu_data,
                'sync_required': True,
                'coordination': {
                    'sync_delay_ms': 1000,  # 1 second delay for synchronization
                    'requires_ack': True
                }
            }
            
            # Broadcast to all business displays
            self.broadcast_to_business_displays(business_id, message)
            
            # Log coordination event
            self._log_coordination_event(business_id, 'menu_update', {
                'menu_id': menu_id,
                'update_type': update_type,
                'displays_count': DisplayDevice.objects.filter(
                    business_id=business_id, 
                    is_active=True,
                    is_online=True
                ).count()
            })
            
        except Exception as e:
            logger.error(f"Error sending synchronized menu update: {str(e)}")
    
    def coordinate_promotional_display(self, business_id: int, promotion_data: Dict[str, Any], 
                                     duration_minutes: int = 5):
        """Coordinate promotional content display across screens"""
        
        try:
            # Add promotion scheduling
            start_time = datetime.now() + timedelta(seconds=5)  # 5 second delay
            end_time = start_time + timedelta(minutes=duration_minutes)
            
            promotion_message = {
                'type': 'promotion',
                'action': 'display',
                'promotion_data': promotion_data,
                'scheduling': {
                    'start_time': start_time.isoformat(),
                    'end_time': end_time.isoformat(),
                    'duration_minutes': duration_minutes
                },
                'coordination': {
                    'synchronized': True,
                    'requires_ack': True
                }
            }
            
            # Broadcast to all business displays
            self.broadcast_to_business_displays(business_id, promotion_message)
            
            # Schedule promotion end message
            self._schedule_promotion_end(business_id, promotion_data.get('id'), end_time)
            
            logger.info(f"Coordinated promotion display for business {business_id}, duration: {duration_minutes}min")
            
        except Exception as e:
            logger.error(f"Error coordinating promotional display: {str(e)}")
    
    def sync_display_settings(self, business_id: int, settings: Dict[str, Any]):
        """Synchronize display settings across all business screens"""
        
        try:
            settings_message = {
                'type': 'settings_update',
                'action': 'sync',
                'settings': settings,
                'coordination': {
                    'apply_immediately': True,
                    'requires_ack': True
                }
            }
            
            self.broadcast_to_business_displays(business_id, settings_message)
            
            logger.info(f"Synchronized display settings for business {business_id}")
            
        except Exception as e:
            logger.error(f"Error synchronizing display settings: {str(e)}")
    
    def handle_display_health_update(self, display_id: int, health_data: Dict[str, Any]):
        """Handle health update from a display and coordinate if needed"""
        
        try:
            # Get display
            try:
                display = DisplayDevice.objects.get(id=display_id)
            except DisplayDevice.DoesNotExist:
                logger.warning(f"Display {display_id} not found")
                return
            
            # Update display health status
            display.last_seen = timezone.now()
            display.health_status = health_data
            display.save(update_fields=['last_seen', 'health_status'])
            
            # Check if health issue requires coordination
            if self._requires_health_coordination(health_data):
                self._coordinate_health_response(display, health_data)
            
            # Notify admin about health status
            self._notify_admin_health_status(display, health_data)
            
        except Exception as e:
            logger.error(f"Error handling display health update: {str(e)}")
    
    def coordinate_content_rotation(self, group_id: int, rotation_schedule: List[Dict[str, Any]]):
        """Coordinate content rotation across displays in a group"""
        
        try:
            rotation_message = {
                'type': 'content_rotation',
                'action': 'start',
                'schedule': rotation_schedule,
                'coordination': {
                    'synchronized': True,
                    'rotation_interval_seconds': 30,
                    'requires_ack': True
                }
            }
            
            self.broadcast_to_display_group(group_id, rotation_message)
            
            logger.info(f"Started coordinated content rotation for group {group_id}")
            
        except Exception as e:
            logger.error(f"Error coordinating content rotation: {str(e)}")
    
    def handle_display_acknowledgment(self, display_id: int, message_id: str, ack_data: Dict[str, Any]):
        """Handle acknowledgment from display for coordinated messages"""
        
        try:
            # Store acknowledgment
            cache_key = f"display_ack_{message_id}_{display_id}"
            cache.set(cache_key, ack_data, 3600)  # Store for 1 hour
            
            # Check if all displays have acknowledged
            self._check_coordination_completion(message_id)
            
            logger.debug(f"Received acknowledgment from display {display_id} for message {message_id}")
            
        except Exception as e:
            logger.error(f"Error handling display acknowledgment: {str(e)}")
    
    def get_coordination_status(self, business_id: int) -> Dict[str, Any]:
        """Get current coordination status for a business"""
        
        try:
            # Get display status
            displays = DisplayDevice.objects.filter(business_id=business_id, is_active=True)
            online_displays = displays.filter(is_online=True)
            
            # Get recent coordination events
            cache_key = f"coordination_events_{business_id}"
            recent_events = cache.get(cache_key, [])
            
            return {
                'business_id': business_id,
                'total_displays': displays.count(),
                'online_displays': online_displays.count(),
                'offline_displays': displays.count() - online_displays.count(),
                'recent_events': recent_events[:10],  # Last 10 events
                'last_update': datetime.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error getting coordination status: {str(e)}")
            return {}
    
    def _send_to_display(self, display: DisplayDevice, message: Dict[str, Any]):
        """Send message to a specific display via WebSocket"""
        
        try:
            # Add display-specific context
            message['display_id'] = display.id
            message['display_name'] = display.name
            
            # Send via channel layer
            group_name = f"display_{display.id}"
            
            if self.channel_layer:
                async_to_sync(self.channel_layer.group_send)(
                    group_name,
                    {
                        'type': 'display_message',
                        'message': message
                    }
                )
            
            logger.debug(f"Sent message to display {display.id}: {message['type']}")
            
        except Exception as e:
            logger.warning(f"Error sending message to display {display.id}: {str(e)}")
    
    def _generate_message_id(self) -> str:
        """Generate unique message ID for coordination tracking"""
        import uuid
        return f"coord_{int(datetime.now().timestamp())}_{str(uuid.uuid4())[:8]}"
    
    def _log_coordination_event(self, business_id: int, event_type: str, event_data: Dict[str, Any]):
        """Log coordination event for tracking"""
        
        try:
            event = {
                'timestamp': datetime.now().isoformat(),
                'business_id': business_id,
                'event_type': event_type,
                'data': event_data
            }
            
            # Store in cache for recent events
            cache_key = f"coordination_events_{business_id}"
            events = cache.get(cache_key, [])
            events.insert(0, event)
            events = events[:50]  # Keep last 50 events
            cache.set(cache_key, events, 86400)  # Store for 24 hours
            
        except Exception as e:
            logger.error(f"Error logging coordination event: {str(e)}")
    
    def _requires_health_coordination(self, health_data: Dict[str, Any]) -> bool:
        """Check if health data requires coordination response"""
        
        # Check for critical health issues
        battery_level = health_data.get('battery_level', 100)
        memory_usage = health_data.get('memory_usage_percent', 0)
        connection_quality = health_data.get('connection_quality', 'good')
        
        return (
            battery_level < 20 or
            memory_usage > 90 or
            connection_quality in ['poor', 'critical']
        )
    
    def _coordinate_health_response(self, display: DisplayDevice, health_data: Dict[str, Any]):
        """Coordinate response to health issues"""
        
        try:
            response_message = {
                'type': 'health_response',
                'action': 'optimize',
                'recommendations': self._get_health_recommendations(health_data),
                'coordination': {
                    'priority': 'high',
                    'requires_ack': True
                }
            }
            
            self._send_to_display(display, response_message)
            
            # Notify other displays in the same business about potential issues
            if health_data.get('connection_quality') == 'critical':
                self._notify_sibling_displays(display, 'connection_degraded')
                
        except Exception as e:
            logger.error(f"Error coordinating health response: {str(e)}")
    
    def _get_health_recommendations(self, health_data: Dict[str, Any]) -> List[str]:
        """Get health optimization recommendations"""
        
        recommendations = []
        
        battery_level = health_data.get('battery_level', 100)
        memory_usage = health_data.get('memory_usage_percent', 0)
        connection_quality = health_data.get('connection_quality', 'good')
        
        if battery_level < 20:
            recommendations.append('enable_power_saving_mode')
            
        if memory_usage > 90:
            recommendations.extend(['clear_cache', 'restart_if_critical'])
            
        if connection_quality in ['poor', 'critical']:
            recommendations.extend(['reduce_update_frequency', 'enable_offline_mode'])
        
        return recommendations
    
    def _notify_sibling_displays(self, display: DisplayDevice, notification_type: str):
        """Notify other displays in the same business about issues"""
        
        try:
            sibling_displays = DisplayDevice.objects.filter(
                business=display.business,
                is_active=True,
                is_online=True
            ).exclude(id=display.id)
            
            notification_message = {
                'type': 'sibling_notification',
                'notification_type': notification_type,
                'source_display': {
                    'id': display.id,
                    'name': display.name
                },
                'coordination': {
                    'informational': True
                }
            }
            
            for sibling in sibling_displays:
                self._send_to_display(sibling, notification_message)
                
        except Exception as e:
            logger.error(f"Error notifying sibling displays: {str(e)}")
    
    def _notify_admin_health_status(self, display: DisplayDevice, health_data: Dict[str, Any]):
        """Notify admin users about display health status"""
        
        try:
            # Send to admin WebSocket group
            admin_message = {
                'type': 'display_health_update',
                'display': {
                    'id': display.id,
                    'name': display.name,
                    'business_id': display.business_id
                },
                'health_data': health_data,
                'timestamp': datetime.now().isoformat()
            }
            
            group_name = f"admin_{display.business_id}"
            
            if self.channel_layer:
                async_to_sync(self.channel_layer.group_send)(
                    group_name,
                    {
                        'type': 'admin_message',
                        'message': admin_message
                    }
                )
                
        except Exception as e:
            logger.error(f"Error notifying admin about health status: {str(e)}")
    
    def _schedule_promotion_end(self, business_id: int, promotion_id: str, end_time: datetime):
        """Schedule promotion end message"""
        
        # In a real implementation, you would use a task queue like Celery
        # For now, we'll use a simple cache-based approach
        cache_key = f"scheduled_promotion_end_{business_id}_{promotion_id}"
        cache.set(cache_key, {
            'business_id': business_id,
            'promotion_id': promotion_id,
            'end_time': end_time.isoformat()
        }, int((end_time - datetime.now()).total_seconds()) + 60)
    
    def _check_coordination_completion(self, message_id: str):
        """Check if all displays have acknowledged a coordinated message"""
        
        try:
            # Get all acknowledgments for this message
            cache_pattern = f"display_ack_{message_id}_*"
            # In a real implementation, you would use Redis SCAN or similar
            # For now, we'll skip the completion check
            pass
            
        except Exception as e:
            logger.error(f"Error checking coordination completion: {str(e)}")


# Global coordinator instance
coordinator = MultiScreenCoordinator()


def broadcast_menu_update(business_id: int, menu_id: int, update_type: str = 'update'):
    """Convenience function for broadcasting menu updates"""
    coordinator.send_synchronized_menu_update(business_id, menu_id, update_type)


def broadcast_to_business(business_id: int, message: Dict[str, Any]):
    """Convenience function for broadcasting to business displays"""
    coordinator.broadcast_to_business_displays(business_id, message)


def coordinate_promotion(business_id: int, promotion_data: Dict[str, Any], duration_minutes: int = 5):
    """Convenience function for coordinating promotions"""
    coordinator.coordinate_promotional_display(business_id, promotion_data, duration_minutes)