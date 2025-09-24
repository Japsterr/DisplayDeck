"""
WebSocket consumers for DisplayDeck real-time communication.

Handles WebSocket connections for display devices, admin dashboard,
and real-time updates for menu synchronization and status monitoring.
"""

import json
import asyncio
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.utils import timezone
from asgiref.sync import sync_to_async

from apps.displays.models import Display, DisplaySession
from apps.businesses.models import Business, BusinessMember
from apps.menus.models import Menu
from apps.authentication.models import User
from common.permissions import BusinessPermissions, check_business_permission

logger = logging.getLogger(__name__)
User = get_user_model()


class DisplayConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer for display devices.
    
    Handles real-time communication with digital display devices including:
    - Device authentication and pairing
    - Menu synchronization
    - Status updates and health monitoring
    - Remote commands and control
    """
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.display_id = None
        self.display = None
        self.business_id = None
        self.display_group = None
        self.authenticated = False
        self.heartbeat_task = None
    
    async def connect(self):
        """Handle WebSocket connection from display device."""
        # Extract display ID from URL
        self.display_id = self.scope['url_route']['kwargs']['display_id']
        
        # Get display and validate
        self.display = await self.get_display()
        if not self.display:
            await self.close(code=4004)  # Display not found
            return
        
        self.business_id = str(self.display.business.id)
        self.display_group = f"display_{self.display_id}"
        
        # Accept connection (authentication happens after connect)
        await self.accept()
        
        # Send authentication challenge
        await self.send_json({
            'type': 'auth_challenge',
            'display_id': self.display_id,
            'business_name': self.display.business.name,
            'timestamp': datetime.now().isoformat()
        })
        
        logger.info(f"Display {self.display_id} connected, awaiting authentication")
    
    async def disconnect(self, close_code):
        """Handle WebSocket disconnection."""
        if self.authenticated and self.display:
            # Update display status
            await self.update_display_status('offline')
            
            # End current session
            await self.end_display_session()
            
            # Leave channel groups
            await self.channel_layer.group_discard(
                self.display_group,
                self.channel_name
            )
            
            # Notify admin dashboard
            await self.notify_admins('display_disconnected', {
                'display_id': self.display_id,
                'display_name': self.display.name,
                'timestamp': datetime.now().isoformat()
            })
            
            logger.info(f"Display {self.display_id} disconnected (code: {close_code})")
        
        # Cancel heartbeat task
        if self.heartbeat_task:
            self.heartbeat_task.cancel()
    
    async def receive(self, text_data):
        """Handle messages from display device."""
        try:
            message = json.loads(text_data)
            message_type = message.get('type')
            
            if message_type == 'authenticate':
                await self.handle_authentication(message)
            elif not self.authenticated:
                await self.send_error('Authentication required')
                return
            elif message_type == 'heartbeat':
                await self.handle_heartbeat(message)
            elif message_type == 'status_update':
                await self.handle_status_update(message)
            elif message_type == 'error_report':
                await self.handle_error_report(message)
            elif message_type == 'menu_request':
                await self.handle_menu_request(message)
            elif message_type == 'performance_metrics':
                await self.handle_performance_metrics(message)
            else:
                await self.send_error(f'Unknown message type: {message_type}')
                
        except json.JSONDecodeError:
            await self.send_error('Invalid JSON message')
        except Exception as e:
            logger.error(f"Error handling message from display {self.display_id}: {e}")
            await self.send_error('Internal server error')
    
    async def handle_authentication(self, message: Dict[str, Any]):
        """Handle display device authentication."""
        device_token = message.get('device_token')
        
        if not device_token:
            await self.send_error('Device token required')
            return
        
        # Validate device token
        if await self.validate_device_token(device_token):
            self.authenticated = True
            
            # Update display status
            await self.update_display_status('online')
            
            # Start new session
            await self.start_display_session()
            
            # Join channel groups
            await self.channel_layer.group_add(
                self.display_group,
                self.channel_name
            )
            
            # Join business group for broadcasts
            business_group = f"business_{self.business_id}_displays"
            await self.channel_layer.group_add(
                business_group,
                self.channel_name
            )
            
            # Start heartbeat monitoring
            self.heartbeat_task = asyncio.create_task(self.heartbeat_monitor())
            
            # Send authentication success
            await self.send_json({
                'type': 'auth_success',
                'display_name': self.display.name,
                'business_name': self.display.business.name,
                'current_menu_id': str(self.display.current_menu_id) if self.display.current_menu else None,
                'timestamp': datetime.now().isoformat()
            })
            
            # Request current menu if assigned
            if self.display.current_menu:
                await self.send_menu_data(self.display.current_menu)
            
            # Notify admin dashboard
            await self.notify_admins('display_connected', {
                'display_id': self.display_id,
                'display_name': self.display.name,
                'location': self.display.location,
                'timestamp': datetime.now().isoformat()
            })
            
            logger.info(f"Display {self.display_id} authenticated successfully")
        else:
            await self.send_error('Invalid device token')
            await self.close(code=4003)  # Authentication failed
    
    async def handle_heartbeat(self, message: Dict[str, Any]):
        """Handle heartbeat from display device."""
        await self.update_display_heartbeat()
        
        # Send heartbeat response
        await self.send_json({
            'type': 'heartbeat_ack',
            'timestamp': datetime.now().isoformat()
        })
    
    async def handle_status_update(self, message: Dict[str, Any]):
        """Handle status update from display device."""
        status = message.get('status')
        performance = message.get('performance', {})
        
        if status:
            await self.update_display_status(status)
        
        if performance:
            await self.update_performance_metrics(performance)
        
        # Notify admins of status change
        await self.notify_admins('display_status_update', {
            'display_id': self.display_id,
            'display_name': self.display.name,
            'status': status,
            'performance': performance,
            'timestamp': datetime.now().isoformat()
        })
    
    async def handle_error_report(self, message: Dict[str, Any]):
        """Handle error report from display device."""
        error = message.get('error')
        error_type = message.get('error_type', 'general')
        
        if error:
            await self.log_display_error(error, error_type)
            
            # Notify admins of error
            await self.notify_admins('display_error', {
                'display_id': self.display_id,
                'display_name': self.display.name,
                'error': error,
                'error_type': error_type,
                'timestamp': datetime.now().isoformat()
            })
    
    async def handle_menu_request(self, message: Dict[str, Any]):
        """Handle menu data request from display."""
        menu_id = message.get('menu_id')
        
        if menu_id:
            menu = await self.get_menu(menu_id)
            if menu:
                await self.send_menu_data(menu)
            else:
                await self.send_error(f'Menu {menu_id} not found')
        elif self.display.current_menu:
            await self.send_menu_data(self.display.current_menu)
        else:
            await self.send_error('No menu assigned to this display')
    
    async def handle_performance_metrics(self, message: Dict[str, Any]):
        """Handle performance metrics from display."""
        metrics = message.get('metrics', {})
        await self.update_performance_metrics(metrics)
    
    async def send_menu_data(self, menu):
        """Send menu data to display device."""
        menu_data = await self.serialize_menu(menu)
        
        await self.send_json({
            'type': 'menu_data',
            'menu': menu_data,
            'timestamp': datetime.now().isoformat()
        })
    
    async def send_remote_command(self, event):
        """Send remote command to display (called via channel layer)."""
        await self.send_json({
            'type': 'remote_command',
            'command': event['command'],
            'parameters': event.get('parameters', {}),
            'timestamp': datetime.now().isoformat()
        })
    
    async def menu_update(self, event):
        """Handle menu update notification (called via channel layer)."""
        menu_id = event['menu_id']
        
        if str(self.display.current_menu_id) == menu_id:
            menu = await self.get_menu(menu_id)
            if menu:
                await self.send_menu_data(menu)
    
    async def send_error(self, error_message: str):
        """Send error message to display."""
        await self.send_json({
            'type': 'error',
            'message': error_message,
            'timestamp': datetime.now().isoformat()
        })
    
    async def send_json(self, data: Dict[str, Any]):
        """Send JSON data to display."""
        await self.send(text_data=json.dumps(data))
    
    async def heartbeat_monitor(self):
        """Monitor heartbeat and disconnect inactive displays."""
        while True:
            try:
                await asyncio.sleep(300)  # 5 minutes
                
                # Check if display is still active
                last_heartbeat = await self.get_last_heartbeat()
                if last_heartbeat and (timezone.now() - last_heartbeat).total_seconds() > 300:
                    logger.warning(f"Display {self.display_id} heartbeat timeout")
                    await self.close(code=4008)  # Heartbeat timeout
                    break
                    
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Error in heartbeat monitor for display {self.display_id}: {e}")
    
    async def notify_admins(self, event_type: str, data: Dict[str, Any]):
        """Notify admin dashboard of display events."""
        admin_group = f"business_{self.business_id}_admins"
        
        await self.channel_layer.group_send(
            admin_group,
            {
                'type': 'display_event',
                'event_type': event_type,
                'data': data
            }
        )
    
    # Database operations (sync_to_async wrapped)
    
    @database_sync_to_async
    def get_display(self) -> Optional[Display]:
        """Get display object from database."""
        try:
            return Display.objects.select_related('business', 'current_menu').get(id=self.display_id)
        except Display.DoesNotExist:
            return None
    
    @database_sync_to_async
    def validate_device_token(self, token: str) -> bool:
        """Validate device token against display."""
        return self.display and self.display.device_token == token
    
    @database_sync_to_async
    def update_display_status(self, status: str):
        """Update display status in database."""
        if self.display:
            self.display.status = status
            self.display.last_seen_at = timezone.now()
            self.display.save(update_fields=['status', 'last_seen_at'])
    
    @database_sync_to_async
    def update_display_heartbeat(self):
        """Update display heartbeat timestamp."""
        if self.display:
            self.display.last_heartbeat_at = timezone.now()
            self.display.connection_count += 1
            self.display.save(update_fields=['last_heartbeat_at', 'connection_count'])
    
    @database_sync_to_async
    def update_performance_metrics(self, metrics: Dict[str, Any]):
        """Update display performance metrics."""
        if self.display:
            current_metrics = self.display.performance_metrics or {}
            
            # Merge metrics
            for key, value in metrics.items():
                if key in current_metrics and isinstance(value, (int, float)):
                    # Average with existing value
                    current_metrics[key] = (current_metrics[key] + value) / 2
                else:
                    current_metrics[key] = value
            
            current_metrics['last_updated'] = timezone.now().isoformat()
            
            self.display.performance_metrics = current_metrics
            self.display.save(update_fields=['performance_metrics'])
    
    @database_sync_to_async
    def log_display_error(self, error: str, error_type: str):
        """Log display error to database."""
        if self.display:
            self.display.last_error = f"[{error_type}] {error}"
            self.display.last_error_at = timezone.now()
            self.display.save(update_fields=['last_error', 'last_error_at'])
    
    @database_sync_to_async
    def start_display_session(self):
        """Start new display session."""
        if self.display:
            # End any existing session
            existing_sessions = DisplaySession.objects.filter(
                display=self.display,
                ended_at__isnull=True
            )
            for session in existing_sessions:
                session.ended_at = timezone.now()
                session.total_uptime_seconds = (session.ended_at - session.started_at).total_seconds()
                session.save()
            
            # Create new session
            DisplaySession.objects.create(
                display=self.display,
                started_at=timezone.now(),
                started_by=self.display.paired_by
            )
    
    @database_sync_to_async
    def end_display_session(self):
        """End current display session."""
        if self.display:
            session = DisplaySession.objects.filter(
                display=self.display,
                ended_at__isnull=True
            ).first()
            
            if session:
                session.ended_at = timezone.now()
                session.total_uptime_seconds = (session.ended_at - session.started_at).total_seconds()
                session.save()
    
    @database_sync_to_async
    def get_menu(self, menu_id: str):
        """Get menu object from database."""
        try:
            return Menu.objects.prefetch_related('categories__items').get(id=menu_id)
        except Menu.DoesNotExist:
            return None
    
    @database_sync_to_async
    def get_last_heartbeat(self):
        """Get last heartbeat timestamp."""
        if self.display:
            return self.display.last_heartbeat_at
        return None
    
    @database_sync_to_async
    def serialize_menu(self, menu) -> Dict[str, Any]:
        """Serialize menu data for display."""
        # This would normally use DRF serializers
        # For now, return basic structure
        return {
            'id': str(menu.id),
            'name': menu.name,
            'description': menu.description,
            'version': menu.version,
            'categories': [
                {
                    'id': str(category.id),
                    'name': category.name,
                    'description': category.description,
                    'display_order': category.display_order,
                    'items': [
                        {
                            'id': str(item.id),
                            'name': item.name,
                            'description': item.description,
                            'price': float(item.price),
                            'display_order': item.display_order,
                            'is_available': item.is_available,
                            'image_url': item.image.url if item.image else None
                        }
                        for item in category.items.filter(is_active=True).order_by('display_order')
                    ]
                }
                for category in menu.categories.filter(is_active=True).order_by('display_order')
            ]
        }


class AdminDashboardConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer for admin dashboard.
    
    Handles real-time updates for business administrators including:
    - Display status monitoring
    - Menu update notifications
    - Business analytics updates
    - System notifications
    """
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.user = None
        self.business_id = None
        self.business = None
        self.admin_group = None
    
    async def connect(self):
        """Handle WebSocket connection from admin dashboard."""
        # Get user from scope (set by auth middleware)
        self.user = self.scope.get('user')
        
        if not self.user or isinstance(self.user, AnonymousUser):
            await self.close(code=4001)  # Unauthorized
            return
        
        # Get business ID from URL
        self.business_id = self.scope['url_route']['kwargs']['business_id']
        
        # Validate business access
        if not await self.validate_business_access():
            await self.close(code=4003)  # Forbidden
            return
        
        self.admin_group = f"business_{self.business_id}_admins"
        
        # Accept connection and join group
        await self.accept()
        await self.channel_layer.group_add(
            self.admin_group,
            self.channel_name
        )
        
        # Send connection confirmation
        await self.send_json({
            'type': 'connected',
            'business_name': self.business.name,
            'user_name': f"{self.user.first_name} {self.user.last_name}".strip() or self.user.email,
            'timestamp': datetime.now().isoformat()
        })
        
        # Send initial dashboard data
        await self.send_dashboard_data()
        
        logger.info(f"Admin {self.user.email} connected to business {self.business_id} dashboard")
    
    async def disconnect(self, close_code):
        """Handle WebSocket disconnection."""
        if self.admin_group:
            await self.channel_layer.group_discard(
                self.admin_group,
                self.channel_name
            )
        
        logger.info(f"Admin {self.user.email if self.user else 'Unknown'} disconnected (code: {close_code})")
    
    async def receive(self, text_data):
        """Handle messages from admin dashboard."""
        try:
            message = json.loads(text_data)
            message_type = message.get('type')
            
            if message_type == 'get_dashboard_data':
                await self.send_dashboard_data()
            elif message_type == 'send_display_command':
                await self.handle_display_command(message)
            elif message_type == 'get_display_status':
                await self.handle_display_status_request(message)
            elif message_type == 'refresh_menu':
                await self.handle_menu_refresh(message)
            else:
                await self.send_error(f'Unknown message type: {message_type}')
                
        except json.JSONDecodeError:
            await self.send_error('Invalid JSON message')
        except Exception as e:
            logger.error(f"Error handling admin message: {e}")
            await self.send_error('Internal server error')
    
    async def handle_display_command(self, message: Dict[str, Any]):
        """Handle remote display command from admin."""
        display_id = message.get('display_id')
        command = message.get('command')
        parameters = message.get('parameters', {})
        
        if not display_id or not command:
            await self.send_error('Display ID and command required')
            return
        
        # Check permissions
        if not await self.check_display_permission(display_id):
            await self.send_error('Permission denied')
            return
        
        # Send command to display
        display_group = f"display_{display_id}"
        await self.channel_layer.group_send(
            display_group,
            {
                'type': 'send_remote_command',
                'command': command,
                'parameters': parameters
            }
        )
        
        await self.send_json({
            'type': 'command_sent',
            'display_id': display_id,
            'command': command,
            'timestamp': datetime.now().isoformat()
        })
    
    async def handle_display_status_request(self, message: Dict[str, Any]):
        """Handle display status request from admin."""
        display_id = message.get('display_id')
        
        if display_id:
            status = await self.get_display_status(display_id)
            await self.send_json({
                'type': 'display_status',
                'display_id': display_id,
                'status': status,
                'timestamp': datetime.now().isoformat()
            })
    
    async def handle_menu_refresh(self, message: Dict[str, Any]):
        """Handle menu refresh request from admin."""
        menu_id = message.get('menu_id')
        
        if not menu_id:
            await self.send_error('Menu ID required')
            return
        
        # Notify all displays with this menu
        business_displays_group = f"business_{self.business_id}_displays"
        await self.channel_layer.group_send(
            business_displays_group,
            {
                'type': 'menu_update',
                'menu_id': menu_id
            }
        )
        
        await self.send_json({
            'type': 'menu_refreshed',
            'menu_id': menu_id,
            'timestamp': datetime.now().isoformat()
        })
    
    async def display_event(self, event):
        """Handle display event notification (called via channel layer)."""
        await self.send_json({
            'type': 'display_event',
            'event_type': event['event_type'],
            'data': event['data']
        })
    
    async def business_notification(self, event):
        """Handle business notification (called via channel layer)."""
        await self.send_json({
            'type': 'notification',
            'notification_type': event['notification_type'],
            'data': event['data']
        })
    
    async def send_dashboard_data(self):
        """Send initial dashboard data to admin."""
        dashboard_data = await self.get_dashboard_data()
        
        await self.send_json({
            'type': 'dashboard_data',
            'data': dashboard_data,
            'timestamp': datetime.now().isoformat()
        })
    
    async def send_error(self, error_message: str):
        """Send error message to admin."""
        await self.send_json({
            'type': 'error',
            'message': error_message,
            'timestamp': datetime.now().isoformat()
        })
    
    async def send_json(self, data: Dict[str, Any]):
        """Send JSON data to admin."""
        await self.send(text_data=json.dumps(data))
    
    # Database operations
    
    @database_sync_to_async
    def validate_business_access(self) -> bool:
        """Validate user access to business."""
        try:
            membership = BusinessMember.objects.get(
                business_id=self.business_id,
                user=self.user,
                is_active=True
            )
            self.business = membership.business
            return True
        except BusinessMember.DoesNotExist:
            return False
    
    @database_sync_to_async
    def check_display_permission(self, display_id: str) -> bool:
        """Check if user has permission to control display."""
        try:
            display = Display.objects.get(id=display_id)
            return display.business_id == self.business.id and check_business_permission(
                self.user, self.business, BusinessPermissions.MANAGE_DISPLAYS
            )
        except Display.DoesNotExist:
            return False
    
    @database_sync_to_async
    def get_display_status(self, display_id: str) -> Dict[str, Any]:
        """Get current display status."""
        try:
            display = Display.objects.get(id=display_id, business=self.business)
            return {
                'id': str(display.id),
                'name': display.name,
                'status': display.status,
                'location': display.location,
                'last_seen': display.last_seen_at.isoformat() if display.last_seen_at else None,
                'current_menu': display.current_menu.name if display.current_menu else None
            }
        except Display.DoesNotExist:
            return {}
    
    @database_sync_to_async
    def get_dashboard_data(self) -> Dict[str, Any]:
        """Get dashboard data for business."""
        displays = Display.objects.filter(business=self.business, is_active=True)
        
        online_count = displays.filter(status='online').count()
        offline_count = displays.filter(status='offline').count()
        error_count = displays.exclude(last_error__isnull=True, last_error='').count()
        
        return {
            'business_name': self.business.name,
            'display_summary': {
                'total': displays.count(),
                'online': online_count,
                'offline': offline_count,
                'errors': error_count
            },
            'displays': [
                {
                    'id': str(display.id),
                    'name': display.name,
                    'location': display.location,
                    'status': display.status,
                    'last_seen': display.last_seen_at.isoformat() if display.last_seen_at else None,
                    'current_menu': display.current_menu.name if display.current_menu else None,
                    'has_error': bool(display.last_error)
                }
                for display in displays
            ]
        }


# WebSocket URL routing will be added to core/routing.py