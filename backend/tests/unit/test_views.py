"""
Unit tests for API views and endpoints
Tests authentication, serialization, and business logic
"""

import json
from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from businesses.models import BusinessAccount, BusinessUserRole
from menus.models import Menu, MenuItem, MenuCategory

User = get_user_model()


class AuthenticationAPITests(TestCase):
    """Test authentication API endpoints."""

    def setUp(self):
        """Set up test data."""
        self.client = APIClient()
        self.user_data = {
            'email': 'test@example.com',
            'password': 'testpassword123',
            'first_name': 'John',
            'last_name': 'Doe'
        }
        self.user = User.objects.create_user(**self.user_data)
        
        self.login_url = reverse('auth:login')
        self.refresh_url = reverse('auth:refresh')
        self.register_url = reverse('auth:register')

    def test_user_login_success(self):
        """Test successful user login."""
        login_data = {
            'email': self.user_data['email'],
            'password': self.user_data['password']
        }
        
        response = self.client.post(self.login_url, login_data)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
        self.assertIn('user', response.data)
        self.assertEqual(response.data['user']['email'], self.user.email)

    def test_user_login_invalid_credentials(self):
        """Test login with invalid credentials."""
        login_data = {
            'email': self.user_data['email'],
            'password': 'wrongpassword'
        }
        
        response = self.client.post(self.login_url, login_data)
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertIn('detail', response.data)

    def test_user_login_missing_fields(self):
        """Test login with missing fields."""
        login_data = {'email': self.user_data['email']}
        
        response = self.client.post(self.login_url, login_data)
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('password', response.data)

    def test_token_refresh_success(self):
        """Test successful token refresh."""
        refresh = RefreshToken.for_user(self.user)
        refresh_data = {'refresh': str(refresh)}
        
        response = self.client.post(self.refresh_url, refresh_data)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)

    def test_token_refresh_invalid_token(self):
        """Test token refresh with invalid token."""
        refresh_data = {'refresh': 'invalid_token'}
        
        response = self.client.post(self.refresh_url, refresh_data)
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_user_registration_success(self):
        """Test successful user registration."""
        registration_data = {
            'email': 'newuser@example.com',
            'password': 'newpassword123',
            'password_confirm': 'newpassword123',
            'first_name': 'Jane',
            'last_name': 'Smith'
        }
        
        response = self.client.post(self.register_url, registration_data)
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(User.objects.filter(email='newuser@example.com').exists())

    def test_user_registration_password_mismatch(self):
        """Test registration with password mismatch."""
        registration_data = {
            'email': 'newuser@example.com',
            'password': 'newpassword123',
            'password_confirm': 'differentpassword',
            'first_name': 'Jane',
            'last_name': 'Smith'
        }
        
        response = self.client.post(self.register_url, registration_data)
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_user_registration_duplicate_email(self):
        """Test registration with duplicate email."""
        registration_data = {
            'email': self.user_data['email'],  # Existing user email
            'password': 'newpassword123',
            'password_confirm': 'newpassword123',
            'first_name': 'Jane',
            'last_name': 'Smith'
        }
        
        response = self.client.post(self.register_url, registration_data)
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class BusinessAPITests(TestCase):
    """Test business management API endpoints."""

    def setUp(self):
        """Set up test data."""
        self.client = APIClient()
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='ownerpassword123'
        )
        self.staff_user = User.objects.create_user(
            email='staff@example.com',
            password='staffpassword123'
        )
        
        self.business = BusinessAccount.objects.create(
            name='Test Restaurant',
            owner=self.owner,
            address='123 Main St',
            city='Test City',
            state='TS',
            zip_code='12345',
            phone='+1234567890',
            email='info@testrestaurant.com'
        )
        
        self.businesses_url = reverse('businesses:list')
        self.business_detail_url = reverse('businesses:detail', kwargs={'pk': self.business.id})

    def authenticate_user(self, user):
        """Helper method to authenticate a user."""
        refresh = RefreshToken.for_user(user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def test_list_businesses_authenticated(self):
        """Test listing businesses for authenticated user."""
        self.authenticate_user(self.owner)
        
        response = self.client.get(self.businesses_url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 1)
        self.assertEqual(response.data['results'][0]['name'], self.business.name)

    def test_list_businesses_unauthenticated(self):
        """Test listing businesses for unauthenticated user."""
        response = self.client.get(self.businesses_url)
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_create_business_success(self):
        """Test creating a new business."""
        self.authenticate_user(self.owner)
        
        business_data = {
            'name': 'New Restaurant',
            'address': '456 Oak St',
            'city': 'New City',
            'state': 'NC',
            'zip_code': '67890',
            'phone': '+0987654321',
            'email': 'info@newrestaurant.com'
        }
        
        response = self.client.post(self.businesses_url, business_data)
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['name'], business_data['name'])
        self.assertTrue(BusinessAccount.objects.filter(name='New Restaurant').exists())

    def test_create_business_invalid_data(self):
        """Test creating business with invalid data."""
        self.authenticate_user(self.owner)
        
        business_data = {
            'name': '',  # Required field empty
            'address': '456 Oak St',
            'city': 'New City'
        }
        
        response = self.client.post(self.businesses_url, business_data)
        
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('name', response.data)

    def test_get_business_detail_owner(self):
        """Test getting business detail as owner."""
        self.authenticate_user(self.owner)
        
        response = self.client.get(self.business_detail_url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['id'], self.business.id)
        self.assertEqual(response.data['name'], self.business.name)

    def test_get_business_detail_unauthorized(self):
        """Test getting business detail as unauthorized user."""
        unauthorized_user = User.objects.create_user(
            email='unauthorized@example.com',
            password='password123'
        )
        self.authenticate_user(unauthorized_user)
        
        response = self.client.get(self.business_detail_url)
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_update_business_owner(self):
        """Test updating business as owner."""
        self.authenticate_user(self.owner)
        
        update_data = {
            'name': 'Updated Restaurant Name',
            'phone': '+1111111111'
        }
        
        response = self.client.patch(self.business_detail_url, update_data)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['name'], update_data['name'])
        
        # Verify database was updated
        self.business.refresh_from_db()
        self.assertEqual(self.business.name, update_data['name'])

    def test_delete_business_owner(self):
        """Test deleting business as owner."""
        self.authenticate_user(self.owner)
        
        response = self.client.delete(self.business_detail_url)
        
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        
        # Verify business is deactivated, not deleted
        self.business.refresh_from_db()
        self.assertFalse(self.business.is_active)


class MenuAPITests(TestCase):
    """Test menu management API endpoints."""

    def setUp(self):
        """Set up test data."""
        self.client = APIClient()
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='ownerpassword123'
        )
        
        self.business = BusinessAccount.objects.create(
            name='Test Restaurant',
            owner=self.owner,
            address='123 Main St',
            city='Test City',
            state='TS',
            zip_code='12345',
            phone='+1234567890',
            email='info@testrestaurant.com'
        )
        
        self.menu = Menu.objects.create(
            business=self.business,
            name='Lunch Menu',
            description='Our delicious lunch offerings'
        )
        
        self.category = MenuCategory.objects.create(
            menu=self.menu,
            name='Main Courses',
            order=1
        )
        
        self.menu_item = MenuItem.objects.create(
            category=self.category,
            name='Burger',
            description='Delicious beef burger',
            price=12.99,
            order=1
        )
        
        self.menus_url = reverse('menus:list', kwargs={'business_id': self.business.id})
        self.menu_detail_url = reverse('menus:detail', kwargs={'pk': self.menu.id})

    def authenticate_user(self, user):
        """Helper method to authenticate a user."""
        refresh = RefreshToken.for_user(user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def test_list_menus_for_business(self):
        """Test listing menus for a business."""
        self.authenticate_user(self.owner)
        
        response = self.client.get(self.menus_url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 1)
        self.assertEqual(response.data['results'][0]['name'], self.menu.name)

    def test_create_menu_success(self):
        """Test creating a new menu."""
        self.authenticate_user(self.owner)
        
        menu_data = {
            'name': 'Dinner Menu',
            'description': 'Our evening selections',
            'is_active': True
        }
        
        response = self.client.post(self.menus_url, menu_data)
        
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['name'], menu_data['name'])
        self.assertTrue(Menu.objects.filter(name='Dinner Menu').exists())

    def test_get_menu_detail_with_items(self):
        """Test getting menu detail with categories and items."""
        self.authenticate_user(self.owner)
        
        response = self.client.get(self.menu_detail_url)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['id'], self.menu.id)
        self.assertEqual(response.data['name'], self.menu.name)
        
        # Check categories and items are included
        self.assertIn('categories', response.data)
        self.assertEqual(len(response.data['categories']), 1)
        self.assertEqual(response.data['categories'][0]['name'], self.category.name)

    def test_update_menu_item_price(self):
        """Test updating menu item price."""
        self.authenticate_user(self.owner)
        
        price_update_url = reverse('menu-items:update-price', kwargs={
            'menu_id': self.menu.id,
            'item_id': self.menu_item.id
        })
        
        update_data = {'price': 15.99}
        
        response = self.client.patch(price_update_url, update_data)
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(float(response.data['price']), update_data['price'])
        
        # Verify database was updated
        self.menu_item.refresh_from_db()
        self.assertEqual(float(self.menu_item.price), update_data['price'])

    def test_menu_access_permissions(self):
        """Test menu access is restricted to business members."""
        unauthorized_user = User.objects.create_user(
            email='unauthorized@example.com',
            password='password123'
        )
        self.authenticate_user(unauthorized_user)
        
        response = self.client.get(self.menus_url)
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)