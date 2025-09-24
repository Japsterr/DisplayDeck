"""
CRITICAL: Business API Contract Tests

These tests MUST FAIL until the business API endpoints are implemented.
They define the exact API behavior from our OpenAPI specification.

API Endpoints tested:
- GET /api/businesses - List user's businesses
- POST /api/businesses - Create new business
- GET /api/businesses/{id} - Get business details
- PATCH /api/businesses/{id} - Update business
- DELETE /api/businesses/{id} - Soft delete business
- GET /api/businesses/{id}/members - List business members
- POST /api/businesses/{id}/invite - Invite user to business
- POST /api/businesses/{id}/members/{user_id}/role - Change member role
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


class TestBusinessAPIList(APITestCase):
    """Test business list API - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.url = '/api/businesses'
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )
        self.manager = User.objects.create_user(
            email='manager@example.com',
            password='SecurePass123!'
        )

    def test_list_businesses_authenticated_owner(self):
        """GET /api/businesses should return user's businesses"""
        # This MUST FAIL until business list endpoint is implemented
        
        from apps.businesses.models import Business
        
        # Create businesses for owner
        business1 = Business.objects.create(
            name='Restaurant A',
            slug='restaurant-a',
            owner=self.owner
        )
        
        business2 = Business.objects.create(
            name='Restaurant B',
            slug='restaurant-b',
            owner=self.owner
        )
        
        # Authenticate as owner
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 2)
        self.assertIn('count', response.data)
        self.assertIn('next', response.data)
        self.assertIn('previous', response.data)
        
        # Check business data structure
        business_data = response.data['results'][0]
        self.assertIn('id', business_data)
        self.assertIn('name', business_data)
        self.assertIn('slug', business_data)
        self.assertIn('description', business_data)
        self.assertIn('phone', business_data)
        self.assertIn('email', business_data)
        self.assertIn('address', business_data)
        self.assertIn('timezone', business_data)
        self.assertIn('is_active', business_data)
        self.assertIn('created_at', business_data)

    def test_list_businesses_with_member_access(self):
        """GET /api/businesses should include businesses where user is member"""
        # This MUST FAIL until business membership is implemented
        
        from apps.businesses.models import Business, BusinessMember
        
        # Owner's business
        business1 = Business.objects.create(
            name='Owner Business',
            slug='owner-business',
            owner=self.owner
        )
        
        # Add manager as member
        BusinessMember.objects.create(
            business=business1,
            user=self.manager,
            role='manager',
            is_active=True
        )
        
        # Authenticate as manager
        refresh = RefreshToken.for_user(self.manager)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 1)
        
        # Should include role information
        business_data = response.data['results'][0]
        self.assertEqual(business_data['name'], 'Owner Business')
        self.assertIn('user_role', business_data)
        self.assertEqual(business_data['user_role'], 'manager')

    def test_list_businesses_unauthenticated(self):
        """GET /api/businesses without authentication should return 401"""
        # This MUST FAIL until authentication requirement is implemented
        
        response = self.client.get(self.url)
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_list_businesses_pagination(self):
        """GET /api/businesses should support pagination"""
        # This MUST FAIL until pagination is implemented
        
        from apps.businesses.models import Business
        
        # Create 15 businesses
        for i in range(15):
            Business.objects.create(
                name=f'Restaurant {i}',
                slug=f'restaurant-{i}',
                owner=self.owner
            )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        # Get first page
        response = self.client.get(f'{self.url}?page=1&page_size=10')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 10)
        self.assertEqual(response.data['count'], 15)
        self.assertIsNotNone(response.data['next'])
        self.assertIsNone(response.data['previous'])

    def test_list_businesses_search_filter(self):
        """GET /api/businesses should support search filtering"""
        # This MUST FAIL until search filtering is implemented
        
        from apps.businesses.models import Business
        
        Business.objects.create(
            name='McDonald\'s Downtown',
            slug='mcdonalds-downtown',
            owner=self.owner
        )
        
        Business.objects.create(
            name='Burger King Uptown',
            slug='burger-king-uptown',
            owner=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        # Search for McDonald's
        response = self.client.get(f'{self.url}?search=McDonald')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 1)
        self.assertEqual(response.data['results'][0]['name'], 'McDonald\'s Downtown')


class TestBusinessAPICreate(APITestCase):
    """Test business creation API - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.url = '/api/businesses'
        self.user = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )

    def test_create_business_valid_data(self):
        """POST /api/businesses with valid data should return 201"""
        # This MUST FAIL until business creation endpoint is implemented
        
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'New Restaurant',
            'slug': 'new-restaurant',
            'description': 'A new restaurant in town',
            'phone': '+1234567890',
            'email': 'contact@newrestaurant.com',
            'address': '123 Main St, City, State 12345',
            'timezone': 'America/New_York',
            'business_type': 'restaurant'
        }
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['name'], 'New Restaurant')
        self.assertEqual(response.data['slug'], 'new-restaurant')
        self.assertEqual(response.data['owner']['id'], self.user.id)
        self.assertTrue(response.data['is_active'])
        self.assertIn('id', response.data)
        self.assertIn('created_at', response.data)

    def test_create_business_duplicate_slug(self):
        """POST /api/businesses with duplicate slug should return 400"""
        # This MUST FAIL until slug uniqueness validation is implemented
        
        from apps.businesses.models import Business
        
        # Create existing business
        Business.objects.create(
            name='Existing Restaurant',
            slug='existing-restaurant',
            owner=self.user
        )
        
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'Another Restaurant',
            'slug': 'existing-restaurant',  # Duplicate slug
            'description': 'Another restaurant'
        }
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('slug', response.data)
        self.assertIn('already exists', str(response.data['slug']))

    def test_create_business_invalid_email(self):
        """POST /api/businesses with invalid email should return 400"""
        # This MUST FAIL until email validation is implemented
        
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'New Restaurant',
            'slug': 'new-restaurant',
            'email': 'invalid-email'
        }
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('email', response.data)

    def test_create_business_invalid_timezone(self):
        """POST /api/businesses with invalid timezone should return 400"""
        # This MUST FAIL until timezone validation is implemented
        
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'New Restaurant',
            'slug': 'new-restaurant',
            'timezone': 'Invalid/Timezone'
        }
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('timezone', response.data)

    def test_create_business_missing_required_fields(self):
        """POST /api/businesses with missing required fields should return 400"""
        # This MUST FAIL until field validation is implemented
        
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'description': 'Restaurant without name or slug'
        }
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('name', response.data)
        self.assertIn('slug', response.data)

    def test_create_business_unauthenticated(self):
        """POST /api/businesses without authentication should return 401"""
        # This MUST FAIL until authentication requirement is implemented
        
        data = {
            'name': 'New Restaurant',
            'slug': 'new-restaurant'
        }
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_create_business_auto_slug_generation(self):
        """POST /api/businesses without slug should auto-generate from name"""
        # This MUST FAIL until auto-slug generation is implemented
        
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'McDonald\'s Downtown Location!',
            'description': 'Restaurant without explicit slug'
        }
        
        response = self.client.post(self.url, data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['slug'], 'mcdonalds-downtown-location')


class TestBusinessAPIRetrieve(APITestCase):
    """Test business retrieve API - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )
        self.other_user = User.objects.create_user(
            email='other@example.com',
            password='SecurePass123!'
        )

    def test_get_business_by_id_owner(self):
        """GET /api/businesses/{id} as owner should return 200"""
        # This MUST FAIL until business retrieve endpoint is implemented
        
        from apps.businesses.models import Business
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            description='A test restaurant',
            phone='+1234567890',
            email='contact@test.com',
            address='123 Main St',
            timezone='America/New_York',
            owner=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/businesses/{business.id}')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['id'], business.id)
        self.assertEqual(response.data['name'], 'Test Restaurant')
        self.assertEqual(response.data['slug'], 'test-restaurant')
        self.assertEqual(response.data['phone'], '+1234567890')
        self.assertEqual(response.data['user_role'], 'owner')
        
        # Should include detailed information for owner
        self.assertIn('email', response.data)
        self.assertIn('address', response.data)
        self.assertIn('timezone', response.data)

    def test_get_business_by_id_member(self):
        """GET /api/businesses/{id} as member should return 200 with limited data"""
        # This MUST FAIL until member access control is implemented
        
        from apps.businesses.models import Business, BusinessMember
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        # Add other_user as manager
        BusinessMember.objects.create(
            business=business,
            user=self.other_user,
            role='manager',
            is_active=True
        )
        
        refresh = RefreshToken.for_user(self.other_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/businesses/{business.id}')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['id'], business.id)
        self.assertEqual(response.data['user_role'], 'manager')

    def test_get_business_by_id_unauthorized(self):
        """GET /api/businesses/{id} without access should return 403"""
        # This MUST FAIL until access control is implemented
        
        from apps.businesses.models import Business
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        refresh = RefreshToken.for_user(self.other_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/businesses/{business.id}')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_get_business_by_id_not_found(self):
        """GET /api/businesses/{id} with invalid ID should return 404"""
        # This MUST FAIL until error handling is implemented
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get('/api/businesses/99999')
        
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_get_business_by_slug(self):
        """GET /api/businesses/{slug} should work with slug"""
        # This MUST FAIL until slug lookup is implemented
        
        from apps.businesses.models import Business
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get('/api/businesses/test-restaurant')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['slug'], 'test-restaurant')


class TestBusinessAPIUpdate(APITestCase):
    """Test business update API - MUST FAIL initially"""

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

    def test_update_business_as_owner(self):
        """PATCH /api/businesses/{id} as owner should return 200"""
        # This MUST FAIL until business update endpoint is implemented
        
        from apps.businesses.models import Business
        
        business = Business.objects.create(
            name='Old Name',
            slug='old-slug',
            description='Old description',
            owner=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'Updated Name',
            'description': 'Updated description',
            'phone': '+1234567890'
        }
        
        response = self.client.patch(f'/api/businesses/{business.id}', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['name'], 'Updated Name')
        self.assertEqual(response.data['description'], 'Updated description')
        self.assertEqual(response.data['phone'], '+1234567890')
        
        # Database should be updated
        business.refresh_from_db()
        self.assertEqual(business.name, 'Updated Name')

    def test_update_business_slug_uniqueness(self):
        """PATCH /api/businesses/{id} with duplicate slug should return 400"""
        # This MUST FAIL until slug validation is implemented
        
        from apps.businesses.models import Business
        
        business1 = Business.objects.create(
            name='Business 1',
            slug='business-1',
            owner=self.owner
        )
        
        business2 = Business.objects.create(
            name='Business 2',
            slug='business-2',
            owner=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        # Try to update business2 slug to business1's slug
        data = {
            'slug': 'business-1'
        }
        
        response = self.client.patch(f'/api/businesses/{business2.id}', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('slug', response.data)

    def test_update_business_as_manager_forbidden_fields(self):
        """PATCH /api/businesses/{id} as manager with restricted fields should return 403"""
        # This MUST FAIL until role-based field restrictions are implemented
        
        from apps.businesses.models import Business, BusinessMember
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        BusinessMember.objects.create(
            business=business,
            user=self.manager,
            role='manager',
            is_active=True
        )
        
        refresh = RefreshToken.for_user(self.manager)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        # Try to update owner-only fields
        data = {
            'slug': 'new-slug',  # Owner only
            'business_type': 'cafe'  # Owner only
        }
        
        response = self.client.patch(f'/api/businesses/{business.id}', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn('permission', str(response.data['detail']).lower())

    def test_update_business_as_unauthorized_user(self):
        """PATCH /api/businesses/{id} without access should return 403"""
        # This MUST FAIL until access control is implemented
        
        from apps.businesses.models import Business
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        # Different user without access
        other_user = User.objects.create_user(
            email='other@example.com',
            password='SecurePass123!'
        )
        
        refresh = RefreshToken.for_user(other_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'Hacked Name'
        }
        
        response = self.client.patch(f'/api/businesses/{business.id}', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class TestBusinessAPIMemberManagement(APITestCase):
    """Test business member management API - MUST FAIL initially"""

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

    def test_list_business_members(self):
        """GET /api/businesses/{id}/members should return member list"""
        # This MUST FAIL until member list endpoint is implemented
        
        from apps.businesses.models import Business, BusinessMember
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        # Add member
        BusinessMember.objects.create(
            business=business,
            user=self.manager,
            role='manager',
            is_active=True
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/businesses/{business.id}/members')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 2)  # Owner + manager
        
        # Check member data structure
        member_data = next(m for m in response.data['results'] if m['role'] == 'manager')
        self.assertEqual(member_data['user']['email'], 'manager@example.com')
        self.assertEqual(member_data['role'], 'manager')
        self.assertTrue(member_data['is_active'])
        self.assertIn('joined_at', member_data)

    def test_invite_user_to_business(self):
        """POST /api/businesses/{id}/invite should send invitation"""
        # This MUST FAIL until invitation endpoint is implemented
        
        from apps.businesses.models import Business
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'email': 'newmember@example.com',
            'role': 'staff',
            'message': 'Join our team!'
        }
        
        response = self.client.post(f'/api/businesses/{business.id}/invite', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['email'], 'newmember@example.com')
        self.assertEqual(response.data['role'], 'staff')
        self.assertIn('invitation_token', response.data)
        self.assertIn('expires_at', response.data)

    def test_change_member_role(self):
        """POST /api/businesses/{id}/members/{user_id}/role should update role"""
        # This MUST FAIL until role change endpoint is implemented
        
        from apps.businesses.models import Business, BusinessMember
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        member = BusinessMember.objects.create(
            business=business,
            user=self.manager,
            role='staff',
            is_active=True
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'role': 'manager'
        }
        
        response = self.client.post(
            f'/api/businesses/{business.id}/members/{self.manager.id}/role',
            data,
            format='json'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['role'], 'manager')
        
        # Database should be updated
        member.refresh_from_db()
        self.assertEqual(member.role, 'manager')

    def test_remove_member_from_business(self):
        """DELETE /api/businesses/{id}/members/{user_id} should deactivate member"""
        # This MUST FAIL until member removal endpoint is implemented
        
        from apps.businesses.models import Business, BusinessMember
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        member = BusinessMember.objects.create(
            business=business,
            user=self.manager,
            role='manager',
            is_active=True
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.delete(f'/api/businesses/{business.id}/members/{self.manager.id}')
        
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        
        # Member should be deactivated
        member.refresh_from_db()
        self.assertFalse(member.is_active)
        self.assertIsNotNone(member.removed_at)

    def test_member_management_permissions(self):
        """Member management should enforce proper permissions"""
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
            role='staff',
            is_active=True
        )
        
        # Staff member trying to invite others should fail
        refresh = RefreshToken.for_user(staff_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'email': 'newmember@example.com',
            'role': 'staff'
        }
        
        response = self.client.post(f'/api/businesses/{business.id}/invite', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


# These tests MUST all FAIL initially - they define our business API contracts
if __name__ == '__main__':
    pytest.main([__file__, '-v'])