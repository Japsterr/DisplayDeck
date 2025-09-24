"""
CRITICAL: Menu Management API Contract Tests

These tests MUST FAIL until the menu management endpoints are implemented.
They define the exact API contracts from our specification.

Requirements tested:
- FR-007: Menu Creation & Management
- FR-008: Menu Categories
- FR-009: Menu Items  
- FR-010: Item Availability Control
- FR-011: Pricing Management
- FR-012: Menu Publishing
"""

import pytest
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from django.contrib.auth import get_user_model
from decimal import Decimal

User = get_user_model()


class TestMenuManagementEndpoints(APITestCase):
    """Test menu management API endpoints - MUST FAIL initially"""

    def setUp(self):
        self.menus_url = reverse('menus:menu-list')
        self.menu_detail_url = lambda pk: reverse('menus:menu-detail', kwargs={'pk': pk})
        self.menu_categories_url = lambda pk: reverse('menus:menu-categories', kwargs={'menu_pk': pk})
        self.menu_items_url = lambda pk: reverse('menus:menu-items', kwargs={'menu_pk': pk})
        self.menu_publish_url = lambda pk: reverse('menus:menu-publish', kwargs={'pk': pk})
        
        # Create user and business
        self.user = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )
        self.business_id = 1  # Mock business ID
        
        # Valid menu data
        self.valid_menu_data = {
            'name': 'Main Menu',
            'description': 'Our primary menu with all items',
            'business': self.business_id,
            'is_active': True
        }
        
        # Valid category data
        self.valid_category_data = {
            'name': 'Burgers',
            'description': 'Delicious burgers',
            'display_order': 1
        }
        
        # Valid item data
        self.valid_item_data = {
            'name': 'Classic Burger',
            'description': 'Beef patty with lettuce, tomato, and pickles',
            'price': '9.99',
            'category_id': 1,  # Mock category ID
            'is_available': True,
            'allergens': ['gluten', 'dairy'],
            'calories': 650,
            'image_url': 'https://example.com/burger.jpg'
        }

    def test_create_menu_endpoint_exists(self):
        """POST /api/menus/ - Create menu endpoint must exist"""
        # This MUST FAIL until endpoint is implemented
        self.client.force_authenticate(user=self.user)
        response = self.client.post(self.menus_url, self.valid_menu_data)
        self.assertNotEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_create_menu_success(self):
        """POST /api/menus/ - Successfully create menu"""
        # This MUST FAIL until menu creation is implemented
        
        self.client.force_authenticate(user=self.user)
        response = self.client.post(self.menus_url, self.valid_menu_data)
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('id', response.data)
        self.assertEqual(response.data['name'], 'Main Menu')
        self.assertEqual(response.data['business'], self.business_id)
        self.assertTrue(response.data['is_active'])

    def test_create_menu_validation(self):
        """POST /api/menus/ - Menu creation validation"""
        # This MUST FAIL until validation is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Missing required name
        invalid_data = self.valid_menu_data.copy()
        del invalid_data['name']
        response = self.client.post(self.menus_url, invalid_data)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('name', response.data)
        
        # Invalid business reference
        invalid_data = self.valid_menu_data.copy()
        invalid_data['business'] = 99999
        response = self.client.post(self.menus_url, invalid_data)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('business', response.data)

    def test_get_menus_list_success(self):
        """GET /api/menus/ - List menus for business"""
        # This MUST FAIL until menu listing is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Create menu first
        create_response = self.client.post(self.menus_url, self.valid_menu_data)
        menu_id = create_response.data['id']
        
        # List menus (should filter by user's businesses)
        response = self.client.get(self.menus_url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('results', response.data)
        self.assertEqual(len(response.data['results']), 1)
        self.assertEqual(response.data['results'][0]['id'], menu_id)

    def test_get_menu_detail_success(self):
        """GET /api/menus/{id}/ - Get menu details with categories and items"""
        # This MUST FAIL until menu detail is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Create menu
        create_response = self.client.post(self.menus_url, self.valid_menu_data)
        menu_id = create_response.data['id']
        
        # Get menu detail
        response = self.client.get(self.menu_detail_url(menu_id))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['id'], menu_id)
        self.assertIn('categories', response.data)
        self.assertIn('items_count', response.data)
        self.assertIn('last_published', response.data)

    def test_update_menu_success(self):
        """PUT /api/menus/{id}/ - Update menu details"""
        # This MUST FAIL until menu update is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Create menu
        create_response = self.client.post(self.menus_url, self.valid_menu_data)
        menu_id = create_response.data['id']
        
        # Update menu
        update_data = self.valid_menu_data.copy()
        update_data['name'] = 'Updated Menu Name'
        update_data['description'] = 'Updated description'
        
        response = self.client.put(self.menu_detail_url(menu_id), update_data)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['name'], 'Updated Menu Name')
        self.assertEqual(response.data['description'], 'Updated description')

    def test_delete_menu_success(self):
        """DELETE /api/menus/{id}/ - Delete menu"""
        # This MUST FAIL until menu deletion is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Create menu
        create_response = self.client.post(self.menus_url, self.valid_menu_data)
        menu_id = create_response.data['id']
        
        # Delete menu
        response = self.client.delete(self.menu_detail_url(menu_id))
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        
        # Verify deletion
        response = self.client.get(self.menu_detail_url(menu_id))
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)


class TestMenuCategoryEndpoints(APITestCase):
    """Test menu category management endpoints - MUST FAIL initially"""

    def setUp(self):
        self.user = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )
        self.menu_id = 1  # Mock menu ID
        self.categories_url = lambda pk: reverse('menus:menu-categories', kwargs={'menu_pk': pk})
        self.category_detail_url = lambda menu_pk, cat_pk: reverse(
            'menus:category-detail',
            kwargs={'menu_pk': menu_pk, 'pk': cat_pk}
        )
        
        self.valid_category_data = {
            'name': 'Appetizers',
            'description': 'Start your meal right',
            'display_order': 1,
            'is_active': True
        }

    def test_create_category_endpoint_exists(self):
        """POST /api/menus/{id}/categories/ - Create category endpoint must exist"""
        # This MUST FAIL until endpoint is implemented
        self.client.force_authenticate(user=self.user)
        response = self.client.post(self.categories_url(self.menu_id), self.valid_category_data)
        self.assertNotEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_create_category_success(self):
        """POST /api/menus/{id}/categories/ - Successfully create category"""
        # This MUST FAIL until category creation is implemented
        
        self.client.force_authenticate(user=self.user)
        response = self.client.post(self.categories_url(self.menu_id), self.valid_category_data)
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('id', response.data)
        self.assertEqual(response.data['name'], 'Appetizers')
        self.assertEqual(response.data['display_order'], 1)
        self.assertTrue(response.data['is_active'])

    def test_get_categories_list_success(self):
        """GET /api/menus/{id}/categories/ - List menu categories ordered by display_order"""
        # This MUST FAIL until category listing is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Create multiple categories
        category_data_1 = self.valid_category_data.copy()
        category_data_1['name'] = 'Appetizers'
        category_data_1['display_order'] = 1
        
        category_data_2 = self.valid_category_data.copy()
        category_data_2['name'] = 'Main Courses'
        category_data_2['display_order'] = 2
        
        self.client.post(self.categories_url(self.menu_id), category_data_1)
        self.client.post(self.categories_url(self.menu_id), category_data_2)
        
        # List categories
        response = self.client.get(self.categories_url(self.menu_id))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('results', response.data)
        self.assertEqual(len(response.data['results']), 2)
        # Should be ordered by display_order
        self.assertEqual(response.data['results'][0]['name'], 'Appetizers')
        self.assertEqual(response.data['results'][1]['name'], 'Main Courses')

    def test_update_category_display_order(self):
        """PUT /api/menus/{id}/categories/{cat_id}/ - Update category display order"""
        # This MUST FAIL until category update is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Create category
        create_response = self.client.post(self.categories_url(self.menu_id), self.valid_category_data)
        category_id = create_response.data['id']
        
        # Update display order
        update_data = self.valid_category_data.copy()
        update_data['display_order'] = 5
        
        response = self.client.put(
            self.category_detail_url(self.menu_id, category_id),
            update_data
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['display_order'], 5)

    def test_delete_category_success(self):
        """DELETE /api/menus/{id}/categories/{cat_id}/ - Delete category"""
        # This MUST FAIL until category deletion is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Create category
        create_response = self.client.post(self.categories_url(self.menu_id), self.valid_category_data)
        category_id = create_response.data['id']
        
        # Delete category
        response = self.client.delete(self.category_detail_url(self.menu_id, category_id))
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


class TestMenuItemEndpoints(APITestCase):
    """Test menu item management endpoints - MUST FAIL initially"""

    def setUp(self):
        self.user = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )
        self.menu_id = 1  # Mock menu ID
        self.category_id = 1  # Mock category ID
        self.items_url = lambda pk: reverse('menus:menu-items', kwargs={'menu_pk': pk})
        self.item_detail_url = lambda menu_pk, item_pk: reverse(
            'menus:item-detail',
            kwargs={'menu_pk': menu_pk, 'pk': item_pk}
        )
        self.item_availability_url = lambda menu_pk, item_pk: reverse(
            'menus:item-availability',
            kwargs={'menu_pk': menu_pk, 'pk': item_pk}
        )
        
        self.valid_item_data = {
            'name': 'Classic Cheeseburger',
            'description': 'Beef patty with cheese, lettuce, tomato',
            'price': '12.99',
            'category': self.category_id,
            'is_available': True,
            'allergens': ['gluten', 'dairy'],
            'calories': 750,
            'prep_time_minutes': 15,
            'image_url': 'https://example.com/cheeseburger.jpg'
        }

    def test_create_menu_item_endpoint_exists(self):
        """POST /api/menus/{id}/items/ - Create menu item endpoint must exist"""
        # This MUST FAIL until endpoint is implemented
        self.client.force_authenticate(user=self.user)
        response = self.client.post(self.items_url(self.menu_id), self.valid_item_data)
        self.assertNotEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_create_menu_item_success(self):
        """POST /api/menus/{id}/items/ - Successfully create menu item"""
        # This MUST FAIL until item creation is implemented
        
        self.client.force_authenticate(user=self.user)
        response = self.client.post(self.items_url(self.menu_id), self.valid_item_data)
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('id', response.data)
        self.assertEqual(response.data['name'], 'Classic Cheeseburger')
        self.assertEqual(float(response.data['price']), 12.99)
        self.assertEqual(response.data['category'], self.category_id)
        self.assertTrue(response.data['is_available'])

    def test_create_menu_item_validation(self):
        """POST /api/menus/{id}/items/ - Menu item validation"""
        # This MUST FAIL until validation is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Missing required name
        invalid_data = self.valid_item_data.copy()
        del invalid_data['name']
        response = self.client.post(self.items_url(self.menu_id), invalid_data)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('name', response.data)
        
        # Invalid price format
        invalid_data = self.valid_item_data.copy()
        invalid_data['price'] = 'not-a-price'
        response = self.client.post(self.items_url(self.menu_id), invalid_data)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('price', response.data)
        
        # Negative price
        invalid_data = self.valid_item_data.copy()
        invalid_data['price'] = '-5.99'
        response = self.client.post(self.items_url(self.menu_id), invalid_data)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('price', response.data)

    def test_get_menu_items_list_success(self):
        """GET /api/menus/{id}/items/ - List menu items by category"""
        # This MUST FAIL until item listing is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Create menu item
        create_response = self.client.post(self.items_url(self.menu_id), self.valid_item_data)
        item_id = create_response.data['id']
        
        # List items
        response = self.client.get(self.items_url(self.menu_id))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('results', response.data)
        self.assertEqual(len(response.data['results']), 1)
        self.assertEqual(response.data['results'][0]['id'], item_id)

    def test_get_menu_items_filtered_by_category(self):
        """GET /api/menus/{id}/items/?category={cat_id} - Filter items by category"""
        # This MUST FAIL until filtering is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Create item in category 1
        self.client.post(self.items_url(self.menu_id), self.valid_item_data)
        
        # Create item in different category
        other_item_data = self.valid_item_data.copy()
        other_item_data['name'] = 'Different Item'
        other_item_data['category'] = 2
        self.client.post(self.items_url(self.menu_id), other_item_data)
        
        # Filter by category 1
        response = self.client.get(self.items_url(self.menu_id), {'category': self.category_id})
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 1)
        self.assertEqual(response.data['results'][0]['name'], 'Classic Cheeseburger')

    def test_get_menu_items_filtered_by_availability(self):
        """GET /api/menus/{id}/items/?available=true - Filter items by availability"""
        # This MUST FAIL until availability filtering is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Create available item
        self.client.post(self.items_url(self.menu_id), self.valid_item_data)
        
        # Create unavailable item
        unavailable_item = self.valid_item_data.copy()
        unavailable_item['name'] = 'Unavailable Item'
        unavailable_item['is_available'] = False
        self.client.post(self.items_url(self.menu_id), unavailable_item)
        
        # Filter by available only
        response = self.client.get(self.items_url(self.menu_id), {'available': 'true'})
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 1)
        self.assertEqual(response.data['results'][0]['name'], 'Classic Cheeseburger')

    def test_update_menu_item_success(self):
        """PUT /api/menus/{id}/items/{item_id}/ - Update menu item"""
        # This MUST FAIL until item update is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Create item
        create_response = self.client.post(self.items_url(self.menu_id), self.valid_item_data)
        item_id = create_response.data['id']
        
        # Update item
        update_data = self.valid_item_data.copy()
        update_data['name'] = 'Updated Burger Name'
        update_data['price'] = '14.99'
        
        response = self.client.put(self.item_detail_url(self.menu_id, item_id), update_data)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['name'], 'Updated Burger Name')
        self.assertEqual(float(response.data['price']), 14.99)

    def test_toggle_item_availability_success(self):
        """PATCH /api/menus/{id}/items/{item_id}/availability/ - Toggle item availability"""
        # This MUST FAIL until availability toggle is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Create available item
        create_response = self.client.post(self.items_url(self.menu_id), self.valid_item_data)
        item_id = create_response.data['id']
        
        # Toggle to unavailable
        response = self.client.patch(
            self.item_availability_url(self.menu_id, item_id),
            {'is_available': False}
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data['is_available'])
        
        # Toggle back to available
        response = self.client.patch(
            self.item_availability_url(self.menu_id, item_id),
            {'is_available': True}
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['is_available'])

    def test_delete_menu_item_success(self):
        """DELETE /api/menus/{id}/items/{item_id}/ - Delete menu item"""
        # This MUST FAIL until item deletion is implemented
        
        self.client.force_authenticate(user=self.user)
        
        # Create item
        create_response = self.client.post(self.items_url(self.menu_id), self.valid_item_data)
        item_id = create_response.data['id']
        
        # Delete item
        response = self.client.delete(self.item_detail_url(self.menu_id, item_id))
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


class TestMenuPublishingEndpoints(APITestCase):
    """Test menu publishing endpoints - MUST FAIL initially"""

    def setUp(self):
        self.user = User.objects.create_user(
            email='owner@example.com',
            password='SecurePass123!'
        )
        self.menu_id = 1  # Mock menu ID
        self.publish_url = lambda pk: reverse('menus:menu-publish', kwargs={'pk': pk})
        self.published_menu_url = lambda pk: reverse('menus:published-menu', kwargs={'pk': pk})

    def test_publish_menu_endpoint_exists(self):
        """POST /api/menus/{id}/publish/ - Publish menu endpoint must exist"""
        # This MUST FAIL until endpoint is implemented
        self.client.force_authenticate(user=self.user)
        response = self.client.post(self.publish_url(self.menu_id))
        self.assertNotEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_publish_menu_success(self):
        """POST /api/menus/{id}/publish/ - Successfully publish menu"""
        # This MUST FAIL until menu publishing is implemented
        
        self.client.force_authenticate(user=self.user)
        response = self.client.post(self.publish_url(self.menu_id))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('published_at', response.data)
        self.assertIn('version', response.data)
        self.assertTrue(response.data['is_published'])

    def test_get_published_menu_public_access(self):
        """GET /api/menus/{id}/published/ - Public access to published menu"""
        # This MUST FAIL until published menu endpoint is implemented
        
        # This endpoint should NOT require authentication (public access)
        response = self.client.get(self.published_menu_url(self.menu_id))
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('categories', response.data)
        self.assertIn('items', response.data)
        self.assertIn('published_at', response.data)
        # Should only show available items
        for item in response.data['items']:
            self.assertTrue(item['is_available'])


# These tests MUST all FAIL initially - they define our contracts
if __name__ == '__main__':
    pytest.main([__file__, '-v'])