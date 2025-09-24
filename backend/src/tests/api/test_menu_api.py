"""
CRITICAL: Menu API Contract Tests

These tests MUST FAIL until the menu API endpoints are implemented.
They define the exact API behavior from our OpenAPI specification.

API Endpoints tested:
- GET /api/businesses/{id}/menus - List business menus
- POST /api/businesses/{id}/menus - Create new menu
- GET /api/menus/{id} - Get menu details
- PATCH /api/menus/{id} - Update menu
- DELETE /api/menus/{id} - Soft delete menu
- POST /api/menus/{id}/publish - Publish menu version
- POST /api/menus/{id}/items - Add menu item
- PATCH /api/menu-items/{id} - Update menu item
- DELETE /api/menu-items/{id} - Remove menu item
"""

import pytest
import json
from decimal import Decimal
from datetime import datetime, timedelta
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken

User = get_user_model()


class TestMenuAPIList(APITestCase):
    """Test menu list API - MUST FAIL initially"""

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

    def test_list_business_menus_as_owner(self):
        """GET /api/businesses/{id}/menus should return business menus"""
        # This MUST FAIL until menu list endpoint is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        # Create menus
        menu1 = Menu.objects.create(
            name='Main Menu',
            description='Our main dining menu',
            business=business,
            created_by=self.owner,
            is_published=True
        )
        
        menu2 = Menu.objects.create(
            name='Breakfast Menu',
            description='Early morning options',
            business=business,
            created_by=self.owner,
            is_published=False
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/businesses/{business.id}/menus')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 2)
        
        # Check menu data structure
        menu_data = next(m for m in response.data['results'] if m['name'] == 'Main Menu')
        self.assertIn('id', menu_data)
        self.assertIn('name', menu_data)
        self.assertIn('description', menu_data)
        self.assertIn('version', menu_data)
        self.assertIn('is_published', menu_data)
        self.assertIn('created_at', menu_data)
        self.assertIn('updated_at', menu_data)
        self.assertIn('item_count', menu_data)
        self.assertIn('category_count', menu_data)

    def test_list_business_menus_with_filtering(self):
        """GET /api/businesses/{id}/menus should support filtering"""
        # This MUST FAIL until filtering is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        Menu.objects.create(
            name='Published Menu',
            business=business,
            created_by=self.owner,
            is_published=True
        )
        
        Menu.objects.create(
            name='Draft Menu',
            business=business,
            created_by=self.owner,
            is_published=False
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        # Filter for published menus only
        response = self.client.get(f'/api/businesses/{business.id}/menus?is_published=true')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 1)
        self.assertEqual(response.data['results'][0]['name'], 'Published Menu')
        self.assertTrue(response.data['results'][0]['is_published'])

    def test_list_business_menus_unauthorized(self):
        """GET /api/businesses/{id}/menus without access should return 403"""
        # This MUST FAIL until access control is implemented
        
        from apps.businesses.models import Business
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        # Other user without access
        other_user = User.objects.create_user(
            email='other@example.com',
            password='SecurePass123!'
        )
        
        refresh = RefreshToken.for_user(other_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/businesses/{business.id}/menus')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_list_business_menus_with_search(self):
        """GET /api/businesses/{id}/menus should support search"""
        # This MUST FAIL until search functionality is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        Menu.objects.create(
            name='Breakfast Menu',
            description='Morning meals',
            business=business,
            created_by=self.owner
        )
        
        Menu.objects.create(
            name='Dinner Menu',
            description='Evening dining',
            business=business,
            created_by=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/businesses/{business.id}/menus?search=breakfast')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 1)
        self.assertEqual(response.data['results'][0]['name'], 'Breakfast Menu')


class TestMenuAPICreate(APITestCase):
    """Test menu creation API - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )

    def test_create_menu_valid_data(self):
        """POST /api/businesses/{id}/menus with valid data should return 201"""
        # This MUST FAIL until menu creation endpoint is implemented
        
        from apps.businesses.models import Business
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'New Menu',
            'description': 'A brand new menu',
            'is_active': True
        }
        
        response = self.client.post(f'/api/businesses/{business.id}/menus', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['name'], 'New Menu')
        self.assertEqual(response.data['description'], 'A brand new menu')
        self.assertEqual(response.data['business']['id'], business.id)
        self.assertEqual(response.data['created_by']['id'], self.owner.id)
        self.assertTrue(response.data['is_active'])
        self.assertFalse(response.data['is_published'])
        self.assertEqual(response.data['version'], '1.0.0')
        self.assertIn('id', response.data)
        self.assertIn('created_at', response.data)

    def test_create_menu_duplicate_name(self):
        """POST /api/businesses/{id}/menus with duplicate name should return 400"""
        # This MUST FAIL until name uniqueness validation is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        # Create existing menu
        Menu.objects.create(
            name='Existing Menu',
            business=business,
            created_by=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'Existing Menu',  # Duplicate name
            'description': 'Another menu with same name'
        }
        
        response = self.client.post(f'/api/businesses/{business.id}/menus', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('name', response.data)
        self.assertIn('already exists', str(response.data['name']))

    def test_create_menu_missing_required_fields(self):
        """POST /api/businesses/{id}/menus with missing fields should return 400"""
        # This MUST FAIL until field validation is implemented
        
        from apps.businesses.models import Business
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'description': 'Menu without name'
        }
        
        response = self.client.post(f'/api/businesses/{business.id}/menus', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('name', response.data)

    def test_create_menu_insufficient_permissions(self):
        """POST /api/businesses/{id}/menus as staff should return 403"""
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
            role='staff',  # Staff can't create menus
            is_active=True
        )
        
        refresh = RefreshToken.for_user(staff_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'Unauthorized Menu',
            'description': 'Should not be allowed'
        }
        
        response = self.client.post(f'/api/businesses/{business.id}/menus', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class TestMenuAPIRetrieve(APITestCase):
    """Test menu retrieve API - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )

    def test_get_menu_with_items_and_categories(self):
        """GET /api/menus/{id} should return complete menu with items"""
        # This MUST FAIL until menu retrieve endpoint is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu, Category, MenuItem
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        menu = Menu.objects.create(
            name='Main Menu',
            description='Our main dining menu',
            business=business,
            created_by=self.owner
        )
        
        # Create category
        category = Category.objects.create(
            menu=menu,
            name='Burgers',
            description='Delicious burgers',
            display_order=1
        )
        
        # Create menu item
        MenuItem.objects.create(
            menu=menu,
            category=category,
            name='Big Mac',
            description='Two all-beef patties...',
            price=Decimal('9.99'),
            is_available=True,
            preparation_time=300,
            calories=563,
            allergens=['gluten', 'sesame'],
            dietary_info=['high-protein']
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/menus/{menu.id}')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['id'], menu.id)
        self.assertEqual(response.data['name'], 'Main Menu')
        
        # Should include categories and items
        self.assertIn('categories', response.data)
        self.assertEqual(len(response.data['categories']), 1)
        
        category_data = response.data['categories'][0]
        self.assertEqual(category_data['name'], 'Burgers')
        self.assertEqual(category_data['display_order'], 1)
        self.assertIn('items', category_data)
        self.assertEqual(len(category_data['items']), 1)
        
        item_data = category_data['items'][0]
        self.assertEqual(item_data['name'], 'Big Mac')
        self.assertEqual(item_data['price'], '9.99')
        self.assertEqual(item_data['calories'], 563)
        self.assertIn('gluten', item_data['allergens'])

    def test_get_menu_unauthorized(self):
        """GET /api/menus/{id} without access should return 403"""
        # This MUST FAIL until access control is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        menu = Menu.objects.create(
            name='Private Menu',
            business=business,
            created_by=self.owner
        )
        
        other_user = User.objects.create_user(
            email='other@example.com',
            password='SecurePass123!'
        )
        
        refresh = RefreshToken.for_user(other_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get(f'/api/menus/{menu.id}')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_get_menu_not_found(self):
        """GET /api/menus/{id} with invalid ID should return 404"""
        # This MUST FAIL until error handling is implemented
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.get('/api/menus/99999')
        
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)


class TestMenuAPIUpdate(APITestCase):
    """Test menu update API - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )

    def test_update_menu_valid_data(self):
        """PATCH /api/menus/{id} with valid data should return 200"""
        # This MUST FAIL until menu update endpoint is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        menu = Menu.objects.create(
            name='Old Menu Name',
            description='Old description',
            business=business,
            created_by=self.owner,
            version='1.0.0'
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'Updated Menu Name',
            'description': 'Updated description',
            'is_active': False
        }
        
        response = self.client.patch(f'/api/menus/{menu.id}', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['name'], 'Updated Menu Name')
        self.assertEqual(response.data['description'], 'Updated description')
        self.assertFalse(response.data['is_active'])
        
        # Version should increment
        self.assertNotEqual(response.data['version'], '1.0.0')
        
        # Database should be updated
        menu.refresh_from_db()
        self.assertEqual(menu.name, 'Updated Menu Name')

    def test_update_menu_version_increment(self):
        """PATCH /api/menus/{id} should increment version automatically"""
        # This MUST FAIL until versioning is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        menu = Menu.objects.create(
            name='Test Menu',
            business=business,
            created_by=self.owner,
            version='1.2.3'
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'description': 'Minor update'
        }
        
        response = self.client.patch(f'/api/menus/{menu.id}', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Should increment patch version (1.2.3 -> 1.2.4)
        self.assertEqual(response.data['version'], '1.2.4')

    def test_update_menu_duplicate_name_validation(self):
        """PATCH /api/menus/{id} with duplicate name should return 400"""
        # This MUST FAIL until name validation is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        menu1 = Menu.objects.create(
            name='Menu One',
            business=business,
            created_by=self.owner
        )
        
        menu2 = Menu.objects.create(
            name='Menu Two',
            business=business,
            created_by=self.owner
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'Menu One'  # Duplicate name
        }
        
        response = self.client.patch(f'/api/menus/{menu2.id}', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('name', response.data)


class TestMenuItemAPI(APITestCase):
    """Test menu item API - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )

    def test_add_menu_item_valid_data(self):
        """POST /api/menus/{id}/items with valid data should return 201"""
        # This MUST FAIL until menu item creation endpoint is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu, Category
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        menu = Menu.objects.create(
            name='Test Menu',
            business=business,
            created_by=self.owner
        )
        
        category = Category.objects.create(
            menu=menu,
            name='Burgers',
            display_order=1
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'category_id': category.id,
            'name': 'Big Mac',
            'description': 'Two all-beef patties, special sauce...',
            'price': '9.99',
            'is_available': True,
            'preparation_time': 300,
            'calories': 563,
            'allergens': ['gluten', 'sesame', 'eggs'],
            'dietary_info': ['high-protein']
        }
        
        response = self.client.post(f'/api/menus/{menu.id}/items', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['name'], 'Big Mac')
        self.assertEqual(response.data['price'], '9.99')
        self.assertEqual(response.data['category']['id'], category.id)
        self.assertTrue(response.data['is_available'])
        self.assertEqual(response.data['preparation_time'], 300)
        self.assertEqual(response.data['calories'], 563)
        self.assertIn('gluten', response.data['allergens'])

    def test_update_menu_item(self):
        """PATCH /api/menu-items/{id} should update item"""
        # This MUST FAIL until menu item update endpoint is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu, Category, MenuItem
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        menu = Menu.objects.create(
            name='Test Menu',
            business=business,
            created_by=self.owner
        )
        
        category = Category.objects.create(
            menu=menu,
            name='Burgers',
            display_order=1
        )
        
        item = MenuItem.objects.create(
            menu=menu,
            category=category,
            name='Old Name',
            price=Decimal('8.99'),
            is_available=True
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'name': 'Updated Name',
            'price': '10.99',
            'is_available': False
        }
        
        response = self.client.patch(f'/api/menu-items/{item.id}', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['name'], 'Updated Name')
        self.assertEqual(response.data['price'], '10.99')
        self.assertFalse(response.data['is_available'])

    def test_menu_item_price_validation(self):
        """POST /api/menus/{id}/items with invalid price should return 400"""
        # This MUST FAIL until price validation is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu, Category
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        menu = Menu.objects.create(
            name='Test Menu',
            business=business,
            created_by=self.owner
        )
        
        category = Category.objects.create(
            menu=menu,
            name='Burgers',
            display_order=1
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'category_id': category.id,
            'name': 'Invalid Item',
            'price': '-5.00'  # Negative price
        }
        
        response = self.client.post(f'/api/menus/{menu.id}/items', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('price', response.data)

    def test_bulk_update_item_availability(self):
        """POST /api/menus/{id}/bulk-availability should update multiple items"""
        # This MUST FAIL until bulk operations are implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu, Category, MenuItem
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        menu = Menu.objects.create(
            name='Test Menu',
            business=business,
            created_by=self.owner
        )
        
        category = Category.objects.create(
            menu=menu,
            name='Burgers',
            display_order=1
        )
        
        # Create multiple items
        item1 = MenuItem.objects.create(
            menu=menu,
            category=category,
            name='Item 1',
            price=Decimal('9.99'),
            is_available=True
        )
        
        item2 = MenuItem.objects.create(
            menu=menu,
            category=category,
            name='Item 2',
            price=Decimal('8.99'),
            is_available=True
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        data = {
            'item_ids': [item1.id, item2.id],
            'is_available': False
        }
        
        response = self.client.post(f'/api/menus/{menu.id}/bulk-availability', data, format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['updated_count'], 2)


class TestMenuPublishAPI(APITestCase):
    """Test menu publishing API - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )

    def test_publish_menu_creates_version(self):
        """POST /api/menus/{id}/publish should create published version"""
        # This MUST FAIL until menu publishing is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu, MenuItem
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        menu = Menu.objects.create(
            name='Test Menu',
            business=business,
            created_by=self.owner,
            is_published=False
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.post(f'/api/menus/{menu.id}/publish', format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['is_published'])
        self.assertIn('published_version', response.data)
        self.assertIn('published_at', response.data)
        
        # Menu should be marked as published
        menu.refresh_from_db()
        self.assertTrue(menu.is_published)

    def test_unpublish_menu(self):
        """POST /api/menus/{id}/unpublish should unpublish menu"""
        # This MUST FAIL until unpublish functionality is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu
        
        business = Business.objects.create(
            name='Test Restaurant',
            slug='test-restaurant',
            owner=self.owner
        )
        
        menu = Menu.objects.create(
            name='Test Menu',
            business=business,
            created_by=self.owner,
            is_published=True
        )
        
        refresh = RefreshToken.for_user(self.owner)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
        
        response = self.client.post(f'/api/menus/{menu.id}/unpublish', format='json')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data['is_published'])
        
        menu.refresh_from_db()
        self.assertFalse(menu.is_published)


# These tests MUST all FAIL initially - they define our menu API contracts
if __name__ == '__main__':
    pytest.main([__file__, '-v'])