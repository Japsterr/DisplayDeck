"""
CRITICAL: Display API Contract Tests

These tests MUST FAIL until the display API endpoints are implemented.
They define the exact API behavior from our OpenAPI specification.

API Endpoints tested:
- GET /api/businesses/{id}/displays - List business displays
- POST /api/businesses/{id}/displays - Create new display
- GET /api/displays/{id} - Get display details
- PATCH /api/displays/{id} - Update display
- DELETE /api/displays/{id} - Remove display
- POST /api/displays/{id}/pair - Pair device with display
- POST /api/displays/{id}/command - Send command to display
- GET /api/displays/{id}/status - Get display status
- GET /api/displays/{id}/qr-code - Generate pairing QR code
"""

import pytest
import json
from datetime import datetime, timedelta
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken

User = get_user_model()


class TestDisplayAPIList(APITestCase):
    """Test display list API - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )
        self.manager = User.objects.create_user(
            email='manager@example.com',
            password='SecurePass123!'
        )

    def test_list_business_displays_as_owner(self):
        """GET /api/businesses/{id}/displays should return business displays"""
        # This MUST FAIL until display list endpoint is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        # Create displays
        display1 = Display.objects.create(
            name='Main Counter Display',
            location='Front Counter',
            display_type='android_tv',
            screen_resolution='1920x1080',
            orientation='landscape',
            business=business,
            created_by=self.owner,
            is_active=True
        )
        
        display2 = Display.objects.create(
            name='Drive Thru Display',
            location='Drive Through',
            display_type='web_browser',
            screen_resolution='1366x768',
            orientation='landscape',
            business=business,
            created_by=self.owner,
            is_active=True
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/businesses/{business.id}/displays')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 2)
        
        # Check display data structure
        display_data = next(d for d in response.data['results'] if d['name'] == 'Main Counter Display')
        self.assertIn('id', display_data)
        self.assertIn('name', display_data)
        self.assertIn('location', display_data)
        self.assertIn('display_type', display_data)
        self.assertIn('screen_resolution', display_data)
        self.assertIn('orientation', display_data)
        self.assertIn('is_active', display_data)
        self.assertIn('is_online', display_data)
        self.assertIn('last_heartbeat', display_data)
        self.assertIn('pairing_token', display_data)
        self.assertIn('device_id', display_data)
        self.assertIn('created_at', display_data)

    def test_list_business_displays_with_status_filter(self):
        """GET /api/businesses/{id}/displays should support status filtering"""
        # This MUST FAIL until filtering is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        Display.objects.create(
            name='Active Display',
            business=business,
            created_by=self.owner,
            is_active=True
        )
        
        Display.objects.create(
            name='Inactive Display',
            business=business,
            created_by=self.owner,
            is_active=False
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        # Filter for active displays only
        response = self.client.get(f'/api/businesses/{business.id}/displays?is_active=true')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 1)
        self.assertEqual(response.data['results'][0]['name'], 'Active Display')
        self.assertTrue(response.data['results'][0]['is_active'])

    def test_list_business_displays_unauthorized(self):
        """GET /api/businesses/{id}/displays without access should return 403"""
        # This MUST FAIL until access control is implemented
        
        from apps.businesses.models import Business
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        other_user = User.objects.create_user(
            email='other@example.com',
            password='SecurePass123!'
        )
        
        refresh = RefreshToken.for_user(other_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/businesses/{business.id}/displays')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_list_business_displays_with_location_search(self):
        """GET /api/businesses/{id}/displays should support location search"""
        # This MUST FAIL until search functionality is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        Display.objects.create(
            name='Counter Display',
            location='Front Counter Area',
            business=business,
            created_by=self.owner
        )
        
        Display.objects.create(
            name='Kitchen Display',
            location='Main Kitchen',
            business=business,
            created_by=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/businesses/{business.id}/displays?search=counter')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 1)
        self.assertEqual(response.data['results'][0]['name'], 'Counter Display')


class TestDisplayAPICreate(APITestCase):
    """Test display creation API - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )

    def test_create_display_valid_data(self):
        """POST /api/businesses/{id}/displays with valid data should return 201"""
        # This MUST FAIL until display creation endpoint is implemented
        
        from apps.businesses.models import Business
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'New Display',
            'location': 'Main Entrance',
            'display_type': 'android_tv',
            'screen_resolution': '1920x1080',
            'orientation': 'landscape'
        }
        
        response = self.client.post(f'/api/businesses/{business.id}/displays', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['name'], 'New Display')
        self.assertEqual(response.data['location'], 'Main Entrance')
        self.assertEqual(response.data['display_type'], 'android_tv')
        self.assertEqual(response.data['screen_resolution'], '1920x1080')
        self.assertEqual(response.data['business']['id'], business.id)
        self.assertEqual(response.data['created_by']['id'], self.owner.id)
        self.assertTrue(response.data['is_active'])
        self.assertIn('pairing_token', response.data)
        self.assertIn('device_id', response.data)
        self.assertIn('id', response.data)
        self.assertIn('created_at', response.data)
        
        # Pairing token should be 8 characters
        self.assertEqual(len(response.data['pairing_token']), 8)

    def test_create_display_duplicate_name(self):
        """POST /api/businesses/{id}/displays with duplicate name should return 400"""
        # This MUST FAIL until name uniqueness validation is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        # Create existing display
        Display.objects.create(
            name='Existing Display',
            business=business,
            created_by=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'Existing Display',  # Duplicate name
            'location': 'Different Location',
            'display_type': 'android_tv'
        }
        
        response = self.client.post(f'/api/businesses/{business.id}/displays', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('name', response.data)
        self.assertIn('already exists', str(response.data['name']))

    def test_create_display_invalid_resolution(self):
        """POST /api/businesses/{id}/displays with invalid resolution should return 400"""
        # This MUST FAIL until resolution validation is implemented
        
        from apps.businesses.models import Business
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'Invalid Display',
            'display_type': 'android_tv',
            'screen_resolution': 'invalid-resolution'
        }
        
        response = self.client.post(f'/api/businesses/{business.id}/displays', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('screen_resolution', response.data)

    def test_create_display_invalid_type(self):
        """POST /api/businesses/{id}/displays with invalid type should return 400"""
        # This MUST FAIL until display type validation is implemented
        
        from apps.businesses.models import Business
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'Invalid Display',
            'display_type': 'invalid_type',
            'screen_resolution': '1920x1080'
        }
        
        response = self.client.post(f'/api/businesses/{business.id}/displays', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('display_type', response.data)

    def test_create_display_insufficient_permissions(self):
        """POST /api/businesses/{id}/displays as staff should return 403"""
        # This MUST FAIL until permission checking is implemented
        
        from apps.businesses.models import Business, BusinessMember
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        staff_user = User.objects.create_user(
            email='staff@example.com',
            password='SecurePass123!'
        )
        
        BusinessMember.objects.create(
            business=business,
            user=staff_user,
            role='staff',  # Staff can't create displays
            is_active=True
        )
        
        refresh = RefreshToken.for_user(staff_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'Unauthorized Display',
            'display_type': 'android_tv'
        }
        
        response = self.client.post(f'/api/businesses/{business.id}/displays', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class TestDisplayAPIRetrieve(APITestCase):
    """Test display retrieve API - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )

    def test_get_display_detailed_info(self):
        """GET /api/displays/{id} should return complete display info"""
        # This MUST FAIL until display retrieve endpoint is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display, DisplaySession
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        display = Display.objects.create(
            name='Test Display',
            location='Main Counter',
            display_type='android_tv',
            screen_resolution='1920x1080',
            orientation='landscape',
            business=business,
            created_by=self.owner,
            is_active=True
        )
        
        # Create active session
        session = DisplaySession.objects.create(
            display=display,
            device_id='android-tv-12345',
            is_active=True,
            last_heartbeat=datetime.now()
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/displays/{display.id}')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['id'], display.id)
        self.assertEqual(response.data['name'], 'Test Display')
        self.assertEqual(response.data['location'], 'Main Counter')
        
        # Should include session information
        self.assertIn('current_session', response.data)
        self.assertEqual(response.data['current_session']['device_id'], 'android-tv-12345')
        self.assertTrue(response.data['current_session']['is_active'])
        
        # Should include status information
        self.assertIn('is_online', response.data)
        self.assertIn('last_heartbeat', response.data)
        self.assertIn('system_info', response.data)

    def test_get_display_unauthorized(self):
        """GET /api/displays/{id} without access should return 403"""
        # This MUST FAIL until access control is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        display = Display.objects.create(
            name='Private Display',
            business=business,
            created_by=self.owner
        )
        
        other_user = User.objects.create_user(
            email='other@example.com',
            password='SecurePass123!'
        )
        
        refresh = RefreshToken.for_user(other_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/displays/{display.id}')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_get_display_not_found(self):
        """GET /api/displays/{id} with invalid ID should return 404"""
        # This MUST FAIL until error handling is implemented
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get('/api/displays/99999')
        
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)


class TestDisplayPairingAPI(APITestCase):
    """Test display pairing API - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )

    def test_generate_pairing_qr_code(self):
        """GET /api/displays/{id}/qr-code should generate pairing QR code"""
        # This MUST FAIL until QR code generation endpoint is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        display = Display.objects.create(
            name='Test Display',
            business=business,
            created_by=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/displays/{display.id}/qr-code')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('qr_code_data', response.data)
        self.assertIn('pairing_url', response.data)
        self.assertIn('expires_at', response.data)
        
        # QR code data should contain pairing information
        qr_data = response.data['qr_code_data']
        self.assertIn('pairing_token', qr_data)
        self.assertIn('business_id', qr_data)
        self.assertIn('display_id', qr_data)
        self.assertIn('api_endpoint', qr_data)

    def test_pair_device_with_valid_token(self):
        """POST /api/displays/{id}/pair with valid token should return 200"""
        # This MUST FAIL until pairing endpoint is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        display = Display.objects.create(
            name='Test Display',
            business=business,
            created_by=self.owner
        )
        
        # No authentication required for pairing (uses pairing token)
        data = {
            'pairing_token': display.pairing_token,
            'device_info': {
                'device_id': 'android-tv-12345',
                'device_name': 'Samsung Smart TV',
                'platform': 'Android TV',
                'platform_version': '11.0',
                'app_version': '1.0.0',
                'screen_resolution': '1920x1080',
                'capabilities': ['websocket', 'offline_mode']
            }
        }
        
        response = self.client.post(f'/api/displays/{display.id}/pair', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('session_token', response.data)
        self.assertIn('websocket_url', response.data)
        self.assertIn('display_config', response.data)
        self.assertIn('paired_at', response.data)
        
        # Should create active session
        self.assertTrue(response.data['session_active'])

    def test_pair_device_with_invalid_token(self):
        """POST /api/displays/{id}/pair with invalid token should return 400"""
        # This MUST FAIL until token validation is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        display = Display.objects.create(
            name='Test Display',
            business=business,
            created_by=self.owner
        )
        
        data = {
            'pairing_token': 'INVALID1',
            'device_info': {
                'device_id': 'android-tv-12345',
                'device_name': 'Samsung Smart TV'
            }
        }
        
        response = self.client.post(f'/api/displays/{display.id}/pair', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('pairing_token', response.data)

    def test_regenerate_pairing_token(self):
        """POST /api/displays/{id}/regenerate-token should create new token"""
        # This MUST FAIL until token regeneration endpoint is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        display = Display.objects.create(
            name='Test Display',
            business=business,
            created_by=self.owner
        )
        
        old_token = display.pairing_token
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.post(f'/api/displays/{display.id}/regenerate-token', format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('pairing_token', response.data)
        self.assertNotEqual(response.data['pairing_token'], old_token)
        self.assertEqual(len(response.data['pairing_token']), 8)


class TestDisplayCommandAPI(APITestCase):
    """Test display command API - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )

    def test_send_display_command(self):
        """POST /api/displays/{id}/command should send command to display"""
        # This MUST FAIL until command endpoint is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display, DisplaySession
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        display = Display.objects.create(
            name='Test Display',
            business=business,
            created_by=self.owner
        )
        
        # Create active session
        DisplaySession.objects.create(
            display=display,
            device_id='android-tv-12345',
            is_active=True
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'command_type': 'refresh_menu',
            'parameters': {
                'force': True,
                'clear_cache': True
            }
        }
        
        response = self.client.post(f'/api/displays/{display.id}/command', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('command_id', response.data)
        self.assertIn('status', response.data)
        self.assertEqual(response.data['command_type'], 'refresh_menu')
        self.assertEqual(response.data['status'], 'pending')
        self.assertTrue(response.data['parameters']['force'])

    def test_get_display_status(self):
        """GET /api/displays/{id}/status should return current status"""
        # This MUST FAIL until status endpoint is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display, DisplaySession
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        display = Display.objects.create(
            name='Test Display',
            business=business,
            created_by=self.owner
        )
        
        session = DisplaySession.objects.create(
            display=display,
            device_id='android-tv-12345',
            is_active=True,
            last_heartbeat=datetime.now(),
            system_info={
                'memory_usage': 65.2,
                'cpu_usage': 23.1,
                'uptime': 86400
            }
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/displays/{display.id}/status')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('is_online', response.data)
        self.assertIn('last_heartbeat', response.data)
        self.assertIn('system_info', response.data)
        self.assertIn('current_menu', response.data)
        self.assertIn('uptime_seconds', response.data)
        
        # System info should be included
        self.assertEqual(response.data['system_info']['memory_usage'], 65.2)
        self.assertEqual(response.data['system_info']['cpu_usage'], 23.1)

    def test_bulk_display_command(self):
        """POST /api/businesses/{id}/displays/bulk-command should send to multiple displays"""
        # This MUST FAIL until bulk command endpoint is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display, DisplaySession
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        # Create multiple displays
        display1 = Display.objects.create(
            name='Display 1',
            business=business,
            created_by=self.owner
        )
        
        display2 = Display.objects.create(
            name='Display 2',
            business=business,
            created_by=self.owner
        )
        
        # Create sessions
        DisplaySession.objects.create(
            display=display1,
            device_id='device-1',
            is_active=True
        )
        
        DisplaySession.objects.create(
            display=display2,
            device_id='device-2',
            is_active=True
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'display_ids': [display1.id, display2.id],
            'command_type': 'emergency_message',
            'parameters': {
                'message': 'Store closing early today',
                'duration': 300
            }
        }
        
        response = self.client.post(f'/api/businesses/{business.id}/displays/bulk-command', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('commands', response.data)
        self.assertEqual(len(response.data['commands']), 2)
        
        # Each command should have unique ID
        command_ids = [cmd['command_id'] for cmd in response.data['commands']]
        self.assertEqual(len(set(command_ids)), 2)

    def test_display_restart_command(self):
        """POST /api/displays/{id}/restart should restart display"""
        # This MUST FAIL until restart endpoint is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display, DisplaySession
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        display = Display.objects.create(
            name='Test Display',
            business=business,
            created_by=self.owner
        )
        
        DisplaySession.objects.create(
            display=display,
            device_id='android-tv-12345',
            is_active=True
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'reason': 'System update required',
            'scheduled_for': (datetime.now() + timedelta(minutes=5)).isoformat()
        }
        
        response = self.client.post(f'/api/displays/{display.id}/restart', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['command_type'], 'restart')
        self.assertEqual(response.data['parameters']['reason'], 'System update required')
        self.assertIn('scheduled_for', response.data['parameters'])


# These tests MUST all FAIL initially - they define our display API contracts
if __name__ == '__main__':
    pytest.main([__file__, '-v'])