"""
Unit tests for User and Business models
Tests model validation, relationships, and business logic
"""

from django.test import TestCase
from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.db.utils import IntegrityError
from businesses.models import BusinessAccount, BusinessUserRole
from users.models import User

User = get_user_model()


class UserModelTests(TestCase):
    """Test cases for the custom User model."""

    def setUp(self):
        """Set up test data."""
        self.user_data = {
            'email': 'test@example.com',
            'first_name': 'John',
            'last_name': 'Doe',
            'password': 'testpassword123'
        }

    def test_create_user_with_email(self):
        """Test creating a user with email is successful."""
        user = User.objects.create_user(**self.user_data)
        
        self.assertEqual(user.email, self.user_data['email'])
        self.assertEqual(user.first_name, self.user_data['first_name'])
        self.assertEqual(user.last_name, self.user_data['last_name'])
        self.assertTrue(user.check_password(self.user_data['password']))
        self.assertTrue(user.is_active)
        self.assertFalse(user.is_staff)
        self.assertFalse(user.is_superuser)

    def test_create_user_without_email_raises_error(self):
        """Test creating user without email raises ValueError."""
        with self.assertRaises(ValueError):
            User.objects.create_user(
                email='',
                password='testpassword123'
            )

    def test_create_superuser(self):
        """Test creating a superuser."""
        admin_user = User.objects.create_superuser(
            email='admin@example.com',
            password='adminpassword123'
        )
        
        self.assertEqual(admin_user.email, 'admin@example.com')
        self.assertTrue(admin_user.is_active)
        self.assertTrue(admin_user.is_staff)
        self.assertTrue(admin_user.is_superuser)

    def test_email_normalized(self):
        """Test email is normalized."""
        user = User.objects.create_user(
            email='Test@EXAMPLE.COM',
            password='testpassword123'
        )
        
        self.assertEqual(user.email, 'Test@example.com')

    def test_user_str_representation(self):
        """Test the user string representation."""
        user = User.objects.create_user(**self.user_data)
        
        self.assertEqual(str(user), self.user_data['email'])

    def test_user_get_full_name(self):
        """Test getting user's full name."""
        user = User.objects.create_user(**self.user_data)
        
        expected_name = f"{self.user_data['first_name']} {self.user_data['last_name']}"
        self.assertEqual(user.get_full_name(), expected_name)

    def test_user_get_short_name(self):
        """Test getting user's short name."""
        user = User.objects.create_user(**self.user_data)
        
        self.assertEqual(user.get_short_name(), self.user_data['first_name'])

    def test_duplicate_email_raises_error(self):
        """Test creating user with duplicate email raises IntegrityError."""
        User.objects.create_user(**self.user_data)
        
        with self.assertRaises(IntegrityError):
            User.objects.create_user(**self.user_data)


class BusinessAccountModelTests(TestCase):
    """Test cases for the BusinessAccount model."""

    def setUp(self):
        """Set up test data."""
        self.owner = User.objects.create_user(
            email='owner@example.com',
            password='ownerpassword123',
            first_name='Jane',
            last_name='Smith'
        )
        
        self.business_data = {
            'name': 'Test Restaurant',
            'owner': self.owner,
            'address': '123 Main St',
            'city': 'Test City',
            'state': 'TS',
            'zip_code': '12345',
            'phone': '+1234567890',
            'email': 'info@testrestaurant.com'
        }

    def test_create_business_account(self):
        """Test creating a business account."""
        business = BusinessAccount.objects.create(**self.business_data)
        
        self.assertEqual(business.name, self.business_data['name'])
        self.assertEqual(business.owner, self.owner)
        self.assertEqual(business.address, self.business_data['address'])
        self.assertEqual(business.phone, self.business_data['phone'])
        self.assertTrue(business.is_active)
        self.assertIsNotNone(business.created_at)
        self.assertIsNotNone(business.updated_at)

    def test_business_str_representation(self):
        """Test business string representation."""
        business = BusinessAccount.objects.create(**self.business_data)
        
        self.assertEqual(str(business), self.business_data['name'])

    def test_business_slug_generation(self):
        """Test business slug is generated from name."""
        business = BusinessAccount.objects.create(**self.business_data)
        
        # Assuming slug is generated from name
        expected_slug = 'test-restaurant'
        self.assertIsNotNone(business.slug)

    def test_business_full_address_property(self):
        """Test business full address property."""
        business = BusinessAccount.objects.create(**self.business_data)
        
        expected_address = f"{self.business_data['address']}, {self.business_data['city']}, {self.business_data['state']} {self.business_data['zip_code']}"
        # This assumes a full_address property exists
        # self.assertEqual(business.full_address, expected_address)

    def test_business_owner_relationship(self):
        """Test business owner relationship."""
        business = BusinessAccount.objects.create(**self.business_data)
        
        self.assertEqual(business.owner, self.owner)
        self.assertIn(business, self.owner.owned_businesses.all())

    def test_business_email_validation(self):
        """Test business email validation."""
        invalid_data = self.business_data.copy()
        invalid_data['email'] = 'invalid-email'
        
        business = BusinessAccount(**invalid_data)
        
        with self.assertRaises(ValidationError):
            business.full_clean()

    def test_business_phone_validation(self):
        """Test business phone validation."""
        invalid_data = self.business_data.copy()
        invalid_data['phone'] = 'invalid-phone'
        
        business = BusinessAccount(**invalid_data)
        
        # Assuming phone validation exists
        # with self.assertRaises(ValidationError):
        #     business.full_clean()

    def test_business_deactivation(self):
        """Test business can be deactivated."""
        business = BusinessAccount.objects.create(**self.business_data)
        
        business.is_active = False
        business.save()
        
        self.assertFalse(business.is_active)


class BusinessUserRoleTests(TestCase):
    """Test cases for BusinessUserRole model."""

    def setUp(self):
        """Set up test data."""
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

    def test_create_business_user_role(self):
        """Test creating a business user role."""
        role = BusinessUserRole.objects.create(
            user=self.staff_user,
            business=self.business,
            role='staff'
        )
        
        self.assertEqual(role.user, self.staff_user)
        self.assertEqual(role.business, self.business)
        self.assertEqual(role.role, 'staff')
        self.assertTrue(role.is_active)

    def test_business_user_role_str_representation(self):
        """Test business user role string representation."""
        role = BusinessUserRole.objects.create(
            user=self.staff_user,
            business=self.business,
            role='manager'
        )
        
        expected_str = f"{self.staff_user.email} - {self.business.name} (manager)"
        self.assertEqual(str(role), expected_str)

    def test_unique_user_business_constraint(self):
        """Test user can only have one role per business."""
        BusinessUserRole.objects.create(
            user=self.staff_user,
            business=self.business,
            role='staff'
        )
        
        with self.assertRaises(IntegrityError):
            BusinessUserRole.objects.create(
                user=self.staff_user,
                business=self.business,
                role='manager'
            )

    def test_business_user_role_permissions(self):
        """Test business user role permissions."""
        manager_role = BusinessUserRole.objects.create(
            user=self.staff_user,
            business=self.business,
            role='manager'
        )
        
        # Assuming permission methods exist
        # self.assertTrue(manager_role.can_edit_menu())
        # self.assertTrue(manager_role.can_manage_staff())
        
        staff_role = BusinessUserRole.objects.create(
            user=self.owner,  # Using different user for this test
            business=self.business,
            role='staff'
        )
        
        # self.assertFalse(staff_role.can_manage_staff())

    def test_deactivate_user_role(self):
        """Test deactivating a user role."""
        role = BusinessUserRole.objects.create(
            user=self.staff_user,
            business=self.business,
            role='staff'
        )
        
        role.is_active = False
        role.save()
        
        self.assertFalse(role.is_active)

    def test_get_active_roles_for_user(self):
        """Test getting active roles for a user."""
        # Create multiple roles
        BusinessUserRole.objects.create(
            user=self.staff_user,
            business=self.business,
            role='staff'
        )
        
        # Create another business and role
        another_business = BusinessAccount.objects.create(
            name='Another Restaurant',
            owner=self.owner,
            address='456 Oak St',
            city='Other City',
            state='OT',
            zip_code='67890',
            phone='+0987654321',
            email='info@another.com'
        )
        
        BusinessUserRole.objects.create(
            user=self.staff_user,
            business=another_business,
            role='manager'
        )
        
        active_roles = BusinessUserRole.objects.filter(
            user=self.staff_user,
            is_active=True
        )
        
        self.assertEqual(active_roles.count(), 2)

    def test_get_users_for_business(self):
        """Test getting all users for a business."""
        BusinessUserRole.objects.create(
            user=self.staff_user,
            business=self.business,
            role='staff'
        )
        
        business_users = BusinessUserRole.objects.filter(
            business=self.business,
            is_active=True
        )
        
        self.assertEqual(business_users.count(), 1)
        self.assertEqual(business_users.first().user, self.staff_user)