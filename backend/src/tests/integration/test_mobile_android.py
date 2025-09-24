"""
CRITICAL: Mobile and Android Integration Contract Tests

These tests MUST FAIL until mobile apps and Android TV client are implemented.
They define exact mobile integration requirements from our specification.

Integration tests for:
- React Native mobile app API integration
- Android TV display client functionality
- QR code scanning and device pairing
- Offline synchronization capabilities
- Push notifications and real-time updates
- Cross-platform data consistency
"""

import pytest
import json
import asyncio
import base64
from datetime import datetime, timedelta
from django.test import TestCase, TransactionTestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from unittest.mock import patch, Mock, MagicMock
import qrcode
from io import BytesIO

User = get_user_model()


class TestMobileAppIntegrationContracts(APITestCase):
    """Test React Native mobile app integration - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.mobile_user = User.objects.create_user(
            email='mobile@example.com',
            password='SecurePass123!'
        )

    def test_mobile_authentication_flow(self):
        """Mobile app authentication and token management flow"""
        # This MUST FAIL until mobile authentication is implemented
        
        # Step 1: Mobile app registration with device info
        registration_data = {
            'email': 'mobile_new@example.com',
            'password': 'SecurePass123!',
            'password_confirm': 'SecurePass123!',
            'first_name': 'Mobile',
            'last_name': 'User',
            'device_info': {
                'platform': 'iOS',
                'platform_version': '15.0',
                'app_version': '1.0.0',
                'device_id': 'iOS-ABC123-DEF456',
                'device_name': 'John\'s iPhone',
                'push_token': 'mobile-push-token-12345'
            }
        }
        
        response = self.client.post('/api/mobile/auth/register', registration_data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('access_token', response.data)
        self.assertIn('refresh_token', response.data)
        self.assertIn('user', response.data)
        self.assertIn('device_registered', response.data)
        self.assertTrue(response.data['device_registered'])
        
        # Step 2: Mobile-specific login with device verification
        login_data = {
            'email': 'mobile_new@example.com',
            'password': 'SecurePass123!',
            'device_info': {
                'device_id': 'iOS-ABC123-DEF456',
                'push_token': 'mobile-push-token-12345'
            }
        }
        
        login_response = self.client.post('/api/mobile/auth/login', login_data, format='json')
        
        self.assertEqual(login_response.status_code, status.HTTP_200_OK)
        self.assertIn('device_verified', login_response.data)
        self.assertTrue(login_response.data['device_verified'])
        
        # Step 3: Token refresh with mobile context
        mobile_token = login_response.data['access_token']
        refresh_token = login_response.data['refresh_token']
        
        self.client.credentials(
            HTTP_AUTHORIZATION=f'Bearer {mobile_token}',
            HTTP_USER_AGENT='DisplayDeck-Mobile/1.0.0 (iOS 15.0)',
            HTTP_X_DEVICE_ID='iOS-ABC123-DEF456'
        )
        
        # Verify mobile context is maintained
        profile_response = self.client.get('/api/mobile/profile')
        self.assertEqual(profile_response.status_code, status.HTTP_200_OK)
        self.assertIn('mobile_settings', profile_response.data)
        self.assertIn('push_enabled', profile_response.data['mobile_settings'])

    def test_mobile_business_dashboard_api(self):
        """Mobile-optimized business dashboard API"""
        # This MUST FAIL until mobile dashboard API is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu, MenuItem
        from apps.displays.models import Display, DisplaySession
        
        # Setup test business with data
        business = Business.objects.create(
            name='Mobile Test Restaurant',
            slug='mobile-test-restaurant',
            owner=self.mobile_user
        )
        
        menu = Menu.objects.create(
            name='Mobile Menu',
            business=business,
            created_by=self.mobile_user,
            is_published=True
        )
        
        # Create menu items with different availability
        available_items = []
        unavailable_items = []
        
        for i in range(5):
            item = MenuItem.objects.create(
                menu=menu,
                name=f'Available Item {i}',
                price='9.99',
                is_available=True
            )
            available_items.append(item)
        
        for i in range(3):
            item = MenuItem.objects.create(
                menu=menu,
                name=f'Unavailable Item {i}',
                price='8.99',
                is_available=False
            )
            unavailable_items.append(item)
        
        # Create displays with different statuses
        online_display = Display.objects.create(
            name='Online Display',
            business=business,
            created_by=self.mobile_user
        )
        
        DisplaySession.objects.create(
            display=online_display,
            device_id='online-device-123',
            is_active=True,
            last_heartbeat=datetime.now()
        )
        
        offline_display = Display.objects.create(
            name='Offline Display',
            business=business,
            created_by=self.mobile_user
        )
        
        # Setup mobile authentication
        refresh = RefreshToken.for_user(self.mobile_user)
        self.client.credentials(
            HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}',
            HTTP_USER_AGENT='DisplayDeck-Mobile/1.0.0 (iOS 15.0)'
        )
        
        # Test mobile dashboard API
        dashboard_response = self.client.get('/api/mobile/dashboard')
        
        self.assertEqual(dashboard_response.status_code, status.HTTP_200_OK)
        
        dashboard_data = dashboard_response.data
        
        # Should include business summary
        self.assertIn('businesses', dashboard_data)
        self.assertEqual(len(dashboard_data['businesses']), 1)
        
        business_summary = dashboard_data['businesses'][0]
        self.assertEqual(business_summary['id'], business.id)
        self.assertIn('menu_stats', business_summary)
        self.assertIn('display_stats', business_summary)
        self.assertIn('recent_activity', business_summary)
        
        # Menu stats should be accurate
        menu_stats = business_summary['menu_stats']
        self.assertEqual(menu_stats['total_items'], 8)
        self.assertEqual(menu_stats['available_items'], 5)
        self.assertEqual(menu_stats['unavailable_items'], 3)
        
        # Display stats should be accurate
        display_stats = business_summary['display_stats']
        self.assertEqual(display_stats['total_displays'], 2)
        self.assertEqual(display_stats['online_displays'], 1)
        self.assertEqual(display_stats['offline_displays'], 1)

    def test_mobile_quick_actions_api(self):
        """Mobile quick actions for common operations"""
        # This MUST FAIL until mobile quick actions are implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu, MenuItem
        
        business = Business.objects.create(
            name='Quick Actions Restaurant',
            slug='quick-actions-restaurant',
            owner=self.mobile_user
        )
        
        menu = Menu.objects.create(
            name='Quick Menu',
            business=business,
            created_by=self.mobile_user
        )
        
        # Create items for quick actions
        items = []
        for i in range(10):
            item = MenuItem.objects.create(
                menu=menu,
                name=f'Quick Item {i}',
                price='9.99',
                is_available=True
            )
            items.append(item)
        
        refresh = RefreshToken.for_user(self.mobile_user)
        self.client.credentials(
            HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}',
            HTTP_USER_AGENT='DisplayDeck-Mobile/1.0.0 (iOS 15.0)'
        )
        
        # Test bulk availability toggle (common mobile action)
        quick_toggle_data = {
            'action': 'toggle_availability',
            'item_ids': [items[0].id, items[1].id, items[2].id],
            'reason': 'Out of stock - via mobile'
        }
        
        toggle_response = self.client.post(
            f'/api/mobile/businesses/{business.id}/quick-actions',
            quick_toggle_data,
            format='json'
        )
        
        self.assertEqual(toggle_response.status_code, status.HTTP_200_OK)
        self.assertEqual(toggle_response.data['action'], 'toggle_availability')
        self.assertEqual(toggle_response.data['affected_items'], 3)
        self.assertTrue(toggle_response.data['success'])
        
        # Test emergency close all items
        emergency_close_data = {
            'action': 'emergency_close_all',
            'reason': 'Kitchen emergency',
            'notify_displays': True
        }
        
        emergency_response = self.client.post(
            f'/api/mobile/businesses/{business.id}/quick-actions',
            emergency_close_data,
            format='json'
        )
        
        self.assertEqual(emergency_response.status_code, status.HTTP_200_OK)
        self.assertEqual(emergency_response.data['action'], 'emergency_close_all')
        self.assertEqual(emergency_response.data['affected_items'], 10)
        self.assertTrue(emergency_response.data['displays_notified'])

    def test_mobile_push_notification_integration(self):
        """Mobile push notification system integration"""
        # This MUST FAIL until push notifications are implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        
        business = Business.objects.create(
            name='Push Test Restaurant',
            slug='push-test-restaurant',
            owner=self.mobile_user
        )
        
        display = Display.objects.create(
            name='Push Test Display',
            business=business,
            created_by=self.mobile_user
        )
        
        refresh = RefreshToken.for_user(self.mobile_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        # Register device for push notifications
        push_registration_data = {
            'push_token': 'mobile-push-token-xyz789',
            'platform': 'iOS',
            'environment': 'production',
            'preferences': {
                'display_offline': True,
                'menu_published': True,
                'system_alerts': True,
                'marketing': False
            }
        }
        
        registration_response = self.client.post(
            '/api/mobile/push/register',
            push_registration_data,
            format='json'
        )
        
        self.assertEqual(registration_response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(registration_response.data['registered'])
        self.assertIn('device_id', registration_response.data)
        
        # Simulate display going offline (should trigger push notification)
        with patch('core.services.push_notification_service.send_push') as mock_push:
            mock_push.return_value = {'success': True, 'message_id': 'test-123'}
            
            # Simulate display offline event
            from core.signals import display_status_changed
            display_status_changed.send(
                sender=Display,
                display=display,
                old_status='online',
                new_status='offline',
                user=self.mobile_user
            )
            
            # Verify push notification was sent
            mock_push.assert_called_once()
            call_args = mock_push.call_args[1]
            
            self.assertEqual(call_args['user_id'], self.mobile_user.id)
            self.assertEqual(call_args['notification_type'], 'display_offline')
            self.assertIn('Push Test Display', call_args['message'])

    def test_mobile_offline_data_sync(self):
        """Mobile app offline data synchronization"""
        # This MUST FAIL until offline sync is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu, MenuItem
        
        business = Business.objects.create(
            name='Offline Sync Restaurant',
            slug='offline-sync-restaurant',
            owner=self.mobile_user
        )
        
        menu = Menu.objects.create(
            name='Sync Menu',
            business=business,
            created_by=self.mobile_user,
            version='1.0.0'
        )
        
        # Create menu items
        for i in range(5):
            MenuItem.objects.create(
                menu=menu,
                name=f'Sync Item {i}',
                price='9.99',
                is_available=True
            )
        
        refresh = RefreshToken.for_user(self.mobile_user)
        self.client.credentials(
            HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}',
            HTTP_USER_AGENT='DisplayDeck-Mobile/1.0.0 (iOS 15.0)'
        )
        
        # Get initial sync data
        sync_response = self.client.get(
            f'/api/mobile/businesses/{business.id}/sync',
            {'last_sync': '2024-01-01T00:00:00Z'}
        )
        
        self.assertEqual(sync_response.status_code, status.HTTP_200_OK)
        
        sync_data = sync_response.data
        self.assertIn('sync_timestamp', sync_data)
        self.assertIn('business_data', sync_data)
        self.assertIn('menu_data', sync_data)
        self.assertIn('changes_since_last_sync', sync_data)
        
        # Verify sync data completeness
        business_data = sync_data['business_data']
        self.assertEqual(business_data['id'], business.id)
        self.assertEqual(business_data['version'], menu.version)
        
        menu_data = sync_data['menu_data']
        self.assertEqual(len(menu_data['items']), 5)
        
        # Test incremental sync after changes
        # Make changes to menu
        menu_item = MenuItem.objects.filter(menu=menu).first()
        menu_item.is_available = False
        menu_item.save()
        
        # Get incremental sync
        incremental_sync = self.client.get(
            f'/api/mobile/businesses/{business.id}/sync',
            {'last_sync': sync_data['sync_timestamp']}
        )
        
        self.assertEqual(incremental_sync.status_code, status.HTTP_200_OK)
        
        # Should only include changes
        changes = incremental_sync.data['changes_since_last_sync']
        self.assertIn('item_updates', changes)
        self.assertEqual(len(changes['item_updates']), 1)
        self.assertEqual(changes['item_updates'][0]['id'], menu_item.id)
        self.assertFalse(changes['item_updates'][0]['is_available'])


class TestAndroidTVIntegrationContracts(APITestCase):
    """Test Android TV display client integration - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.business_owner = User.objects.create_user(
            email='android@example.com',
            password='SecurePass123!'
        )

    def test_android_tv_device_registration_flow(self):
        """Android TV device registration and initial setup"""
        # This MUST FAIL until Android TV integration is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        
        business = Business.objects.create(
            name='Android TV Restaurant',
            slug='android-tv-restaurant',
            owner=self.business_owner
        )
        
        display = Display.objects.create(
            name='Android TV Main Display',
            business=business,
            created_by=self.business_owner,
            display_type='android_tv',
            screen_resolution='1920x1080',
            orientation='landscape'
        )
        
        # Step 1: Android TV device boots and requests configuration
        device_info = {
            'device_id': 'android-tv-samsung-12345',
            'device_name': 'Samsung Smart TV - Kitchen',
            'platform': 'Android TV',
            'platform_version': '11.0',
            'app_version': '1.0.0',
            'hardware_info': {
                'manufacturer': 'Samsung',
                'model': 'QN55Q60A',
                'screen_resolution': '1920x1080',
                'memory_mb': 2048,
                'storage_gb': 8
            },
            'capabilities': [
                'websocket',
                'offline_mode',
                'video_playback',
                'touch_input',
                'voice_control'
            ]
        }
        
        # Initial device check-in (no authentication)
        checkin_response = self.client.post(
            '/api/android-tv/device/checkin',
            device_info,
            format='json'
        )
        
        self.assertEqual(checkin_response.status_code, status.HTTP_200_OK)
        self.assertIn('requires_pairing', checkin_response.data)
        self.assertTrue(checkin_response.data['requires_pairing'])
        self.assertIn('pairing_instructions', checkin_response.data)
        
        # Step 2: Device attempts pairing with display
        pairing_data = {
            'pairing_token': display.pairing_token,
            'device_info': device_info
        }
        
        pairing_response = self.client.post(
            f'/api/displays/{display.id}/pair',
            pairing_data,
            format='json'
        )
        
        self.assertEqual(pairing_response.status_code, status.HTTP_200_OK)
        self.assertIn('session_token', pairing_response.data)
        self.assertIn('display_config', pairing_response.data)
        self.assertIn('websocket_url', pairing_response.data)
        
        session_token = pairing_response.data['session_token']
        display_config = pairing_response.data['display_config']
        
        # Verify display configuration
        self.assertEqual(display_config['business']['name'], 'Android TV Restaurant')
        self.assertEqual(display_config['display']['name'], 'Android TV Main Display')
        self.assertIn('theme', display_config)
        self.assertIn('layout', display_config)
        self.assertIn('menu_data', display_config)
        
        # Step 3: Device authenticates for subsequent API calls
        self.client.credentials(HTTP_AUTHORIZATION=f'AndroidTV {session_token}')
        
        # Test authenticated Android TV API call
        status_update_data = {
            'status': 'online',
            'system_info': {
                'memory_usage': 45.2,
                'cpu_usage': 12.5,
                'uptime': 3600,
                'app_version': '1.0.0'
            },
            'display_info': {
                'current_menu_id': None,
                'last_update': datetime.now().isoformat()
            }
        }
        
        status_response = self.client.post(
            f'/api/android-tv/displays/{display.id}/status',
            status_update_data,
            format='json'
        )
        
        self.assertEqual(status_response.status_code, status.HTTP_200_OK)
        self.assertTrue(status_response.data['status_updated'])

    def test_android_tv_menu_loading_and_caching(self):
        """Android TV menu loading and offline caching"""
        # This MUST FAIL until Android TV menu system is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display, DisplaySession
        from apps.menus.models import Menu, MenuItem, Category
        
        business = Business.objects.create(
            name='Caching Test Restaurant',
            slug='caching-test-restaurant',
            owner=self.business_owner
        )
        
        display = Display.objects.create(
            name='Caching Test Display',
            business=business,
            created_by=self.business_owner,
            display_type='android_tv'
        )
        
        # Create session (simulating paired device)
        session = DisplaySession.objects.create(
            display=display,
            device_id='android-tv-caching-test',
            is_active=True,
            auth_token='android-session-token-123'
        )
        
        # Create menu with categories and items
        menu = Menu.objects.create(
            name='Caching Menu',
            business=business,
            created_by=self.business_owner,
            is_published=True,
            version='1.2.3'
        )
        
        # Create categories and items
        categories = []
        for i in range(3):
            category = Category.objects.create(
                menu=menu,
                name=f'Category {i}',
                display_order=i
            )
            categories.append(category)
            
            # Add items to category
            for j in range(5):
                MenuItem.objects.create(
                    menu=menu,
                    category=category,
                    name=f'Item {i}-{j}',
                    description=f'Description for item {i}-{j}',
                    price=f'{9.99 + (i * j * 0.5):.2f}',
                    is_available=True,
                    preparation_time=300 + (i * j * 30),
                    image_url=f'https://example.com/images/item-{i}-{j}.jpg'
                )
        
        # Authenticate as Android TV device
        self.client.credentials(HTTP_AUTHORIZATION=f'AndroidTV {session.auth_token}')
        
        # Step 1: Initial menu load
        menu_response = self.client.get(f'/api/android-tv/displays/{display.id}/menu')
        
        self.assertEqual(menu_response.status_code, status.HTTP_200_OK)
        
        menu_data = menu_response.data
        self.assertEqual(menu_data['menu']['name'], 'Caching Menu')
        self.assertEqual(menu_data['menu']['version'], '1.2.3')
        self.assertEqual(len(menu_data['categories']), 3)
        
        # Verify menu structure for Android TV
        first_category = menu_data['categories'][0]
        self.assertEqual(len(first_category['items']), 5)
        self.assertIn('android_display_config', first_category)
        
        first_item = first_category['items'][0]
        self.assertIn('display_name', first_item)
        self.assertIn('display_price', first_item)
        self.assertIn('display_description', first_item)
        self.assertIn('image_url', first_item)
        self.assertIn('android_layout_hints', first_item)
        
        # Step 2: Request offline cache package
        cache_request_data = {
            'cache_type': 'full_menu',
            'compression': 'gzip',
            'include_images': True,
            'image_quality': 'medium'
        }
        
        cache_response = self.client.post(
            f'/api/android-tv/displays/{display.id}/cache',
            cache_request_data,
            format='json'
        )
        
        self.assertEqual(cache_response.status_code, status.HTTP_200_OK)
        
        cache_data = cache_response.data
        self.assertIn('cache_package', cache_data)
        self.assertIn('cache_version', cache_data)
        self.assertIn('expires_at', cache_data)
        self.assertIn('image_urls', cache_data)
        
        # Cache version should match menu version
        self.assertEqual(cache_data['cache_version'], '1.2.3')
        
        # Should include image URLs for download
        self.assertEqual(len(cache_data['image_urls']), 15)  # 3 categories * 5 items

    def test_android_tv_real_time_updates(self):
        """Android TV real-time menu updates via WebSocket"""
        # This MUST FAIL until Android TV WebSocket integration is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display, DisplaySession
        from apps.menus.models import Menu, MenuItem
        
        business = Business.objects.create(
            name='WebSocket Test Restaurant',
            slug='websocket-test-restaurant',
            owner=self.business_owner
        )
        
        display = Display.objects.create(
            name='WebSocket Test Display',
            business=business,
            created_by=self.business_owner,
            display_type='android_tv'
        )
        
        session = DisplaySession.objects.create(
            display=display,
            device_id='android-tv-websocket-test',
            is_active=True,
            auth_token='android-websocket-token-123'
        )
        
        menu = Menu.objects.create(
            name='WebSocket Menu',
            business=business,
            created_by=self.business_owner
        )
        
        menu_item = MenuItem.objects.create(
            menu=menu,
            name='WebSocket Item',
            price='9.99',
            is_available=True
        )
        
        # Test WebSocket connection with Android TV authentication
        from channels.testing import WebsocketCommunicator
        from core.routing import application
        
        # Android TV specific WebSocket URL
        websocket_url = f"/ws/android-tv/{session.auth_token}/"
        communicator = WebsocketCommunicator(application, websocket_url)
        
        # Add Android TV headers
        communicator.scope['headers'].extend([
            (b'user-agent', b'DisplayDeckAndroidTV/1.0.0'),
            (b'x-device-type', b'android_tv'),
            (b'x-device-id', b'android-tv-websocket-test')
        ])
        
        # This would be tested with actual WebSocket in implementation
        # For now, verify the API structure exists
        self.client.credentials(HTTP_AUTHORIZATION=f'AndroidTV {session.auth_token}')
        
        websocket_config_response = self.client.get(
            f'/api/android-tv/displays/{display.id}/websocket-config'
        )
        
        self.assertEqual(websocket_config_response.status_code, status.HTTP_200_OK)
        
        ws_config = websocket_config_response.data
        self.assertIn('websocket_url', ws_config)
        self.assertIn('auth_token', ws_config)
        self.assertIn('heartbeat_interval', ws_config)
        self.assertIn('message_types', ws_config)
        
        # Verify Android TV specific message types
        message_types = ws_config['message_types']
        self.assertIn('menu_update', message_types)
        self.assertIn('item_availability', message_types)
        self.assertIn('display_command', message_types)
        self.assertIn('system_message', message_types)

    def test_android_tv_error_handling_and_recovery(self):
        """Android TV error handling and recovery mechanisms"""
        # This MUST FAIL until Android TV error handling is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display, DisplaySession
        
        business = Business.objects.create(
            name='Error Handling Restaurant',
            slug='error-handling-restaurant',
            owner=self.business_owner
        )
        
        display = Display.objects.create(
            name='Error Handling Display',
            business=business,
            created_by=self.business_owner,
            display_type='android_tv'
        )
        
        session = DisplaySession.objects.create(
            display=display,
            device_id='android-tv-error-test',
            is_active=True,
            auth_token='android-error-token-123'
        )
        
        self.client.credentials(HTTP_AUTHORIZATION=f'AndroidTV {session.auth_token}')
        
        # Test error reporting
        error_report_data = {
            'error_type': 'NETWORK_ERROR',
            'error_code': 'NET_001',
            'message': 'Failed to load menu images',
            'timestamp': datetime.now().isoformat(),
            'system_info': {
                'memory_usage': 85.5,
                'cpu_usage': 95.2,
                'network_status': 'disconnected',
                'app_version': '1.0.0'
            },
            'context': {
                'current_menu_id': 1,
                'failed_operation': 'image_download',
                'retry_count': 3
            },
            'stack_trace': 'NetworkException at line 142...',
            'severity': 'high'
        }
        
        error_response = self.client.post(
            f'/api/android-tv/displays/{display.id}/error',
            error_report_data,
            format='json'
        )
        
        self.assertEqual(error_response.status_code, status.HTTP_201_CREATED)
        self.assertIn('error_id', error_response.data)
        self.assertIn('recovery_actions', error_response.data)
        self.assertTrue(error_response.data['logged'])
        
        # Verify recovery actions
        recovery_actions = error_response.data['recovery_actions']
        self.assertIn('retry_operation', recovery_actions)
        self.assertIn('fallback_mode', recovery_actions)
        self.assertIn('notify_admin', recovery_actions)
        
        # Test recovery status update
        recovery_data = {
            'error_id': error_response.data['error_id'],
            'recovery_action': 'fallback_mode',
            'status': 'recovered',
            'resolution': 'Switched to cached menu data',
            'timestamp': datetime.now().isoformat()
        }
        
        recovery_response = self.client.post(
            f'/api/android-tv/displays/{display.id}/recovery',
            recovery_data,
            format='json'
        )
        
        self.assertEqual(recovery_response.status_code, status.HTTP_200_OK)
        self.assertTrue(recovery_response.data['recovery_logged'])

    def test_qr_code_pairing_integration(self):
        """QR code generation and scanning integration"""
        # This MUST FAIL until QR code pairing is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        
        business = Business.objects.create(
            name='QR Pairing Restaurant',
            slug='qr-pairing-restaurant',
            owner=self.business_owner
        )
        
        display = Display.objects.create(
            name='QR Pairing Display',
            business=business,
            created_by=self.business_owner,
            display_type='android_tv'
        )
        
        refresh = RefreshToken.for_user(self.business_owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        # Generate QR code for pairing
        qr_response = self.client.get(f'/api/displays/{display.id}/qr-code')
        
        self.assertEqual(qr_response.status_code, status.HTTP_200_OK)
        
        qr_data = qr_response.data
        self.assertIn('qr_code_data', qr_data)
        self.assertIn('pairing_url', qr_data)
        self.assertIn('expires_at', qr_data)
        self.assertIn('qr_code_image', qr_data)  # Base64 encoded QR code image
        
        # Verify QR code data structure
        pairing_data = qr_data['qr_code_data']
        self.assertEqual(pairing_data['business_id'], business.id)
        self.assertEqual(pairing_data['display_id'], display.id)
        self.assertEqual(pairing_data['pairing_token'], display.pairing_token)
        self.assertIn('api_endpoint', pairing_data)
        self.assertIn('websocket_endpoint', pairing_data)
        
        # Test QR code image generation
        qr_image_data = qr_data['qr_code_image']
        self.assertIsInstance(qr_image_data, str)
        self.assertTrue(qr_image_data.startswith('data:image/png;base64,'))
        
        # Decode and verify QR code image
        base64_data = qr_image_data.split(',')[1]
        image_bytes = base64.b64decode(base64_data)
        self.assertGreater(len(image_bytes), 1000)  # Should be substantial PNG data
        
        # Simulate Android TV scanning QR code
        # (In real implementation, Android TV app would decode QR and extract data)
        self.client.credentials()  # Remove auth for device pairing
        
        # Android TV device uses scanned data to pair
        android_pairing_data = {
            'pairing_token': pairing_data['pairing_token'],
            'device_info': {
                'device_id': 'android-tv-qr-scanned',
                'device_name': 'Android TV - QR Paired',
                'platform': 'Android TV',
                'platform_version': '11.0',
                'app_version': '1.0.0',
                'pairing_method': 'qr_code'
            }
        }
        
        pairing_response = self.client.post(
            f'/api/displays/{display.id}/pair',
            android_pairing_data,
            format='json'
        )
        
        self.assertEqual(pairing_response.status_code, status.HTTP_200_OK)
        self.assertIn('session_token', pairing_response.data)
        self.assertIn('pairing_method', pairing_response.data)
        self.assertEqual(pairing_response.data['pairing_method'], 'qr_code')


# These tests MUST all FAIL initially - they define our mobile integration contracts
if __name__ == '__main__':
    pytest.main([__file__, '-v'])