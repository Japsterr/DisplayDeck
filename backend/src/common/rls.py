"""
Row-Level Security (RLS) policy implementation for multi-tenant data isolation.

This module provides database-level security policies to ensure that tenants
can only access their own data. It includes utilities for creating and managing
RLS policies across different database backends.
"""

import logging
from django.db import connection, transaction
from django.conf import settings
from django.core.management.base import CommandError
from apps.businesses.models import BusinessAccount

logger = logging.getLogger(__name__)


class RLSManager:
    """Manager for Row-Level Security policies"""
    
    def __init__(self):
        self.connection = connection
        self.vendor = connection.vendor
        
    def create_all_policies(self):
        """Create all RLS policies for multi-tenant tables"""
        
        if self.vendor == 'postgresql':
            self._create_postgresql_policies()
        else:
            logger.warning(f"RLS not supported for database vendor: {self.vendor}")
            
    def drop_all_policies(self):
        """Drop all RLS policies"""
        
        if self.vendor == 'postgresql':
            self._drop_postgresql_policies()
            
    def _create_postgresql_policies(self):
        """Create PostgreSQL RLS policies"""
        
        with transaction.atomic():
            cursor = self.connection.cursor()
            
            try:
                # Enable RLS on tenant-aware tables
                tenant_tables = [
                    'businesses_businessaccount',
                    'businesses_businessmember',
                    'menus_menu',
                    'menus_menucategory',
                    'menus_menuitem',
                    'displays_displaydevice',
                    'displays_displaygroup',
                    'media_mediaasset',
                    'analytics_analyticsevent'
                ]
                
                for table in tenant_tables:
                    self._enable_rls_on_table(cursor, table)
                    self._create_tenant_policy(cursor, table)
                    
                logger.info("Successfully created all RLS policies")
                
            except Exception as e:
                logger.error(f"Error creating RLS policies: {str(e)}")
                raise
                
    def _drop_postgresql_policies(self):
        """Drop PostgreSQL RLS policies"""
        
        with transaction.atomic():
            cursor = self.connection.cursor()
            
            try:
                # List of tables with RLS policies
                tenant_tables = [
                    'businesses_businessaccount',
                    'businesses_businessmember', 
                    'menus_menu',
                    'menus_menucategory',
                    'menus_menuitem',
                    'displays_displaydevice',
                    'displays_displaygroup',
                    'media_mediaasset',
                    'analytics_analyticsevent'
                ]
                
                for table in tenant_tables:
                    self._drop_tenant_policy(cursor, table)
                    self._disable_rls_on_table(cursor, table)
                    
                logger.info("Successfully dropped all RLS policies")
                
            except Exception as e:
                logger.error(f"Error dropping RLS policies: {str(e)}")
                raise
                
    def _enable_rls_on_table(self, cursor, table_name):
        """Enable RLS on a specific table"""
        
        try:
            cursor.execute(f"ALTER TABLE {table_name} ENABLE ROW LEVEL SECURITY;")
            logger.debug(f"Enabled RLS on table: {table_name}")
        except Exception as e:
            logger.warning(f"Could not enable RLS on {table_name}: {str(e)}")
            
    def _disable_rls_on_table(self, cursor, table_name):
        """Disable RLS on a specific table"""
        
        try:
            cursor.execute(f"ALTER TABLE {table_name} DISABLE ROW LEVEL SECURITY;")
            logger.debug(f"Disabled RLS on table: {table_name}")
        except Exception as e:
            logger.warning(f"Could not disable RLS on {table_name}: {str(e)}")
            
    def _create_tenant_policy(self, cursor, table_name):
        """Create tenant isolation policy for a table"""
        
        try:
            # Determine the business column name based on table
            business_column = self._get_business_column_name(table_name)
            
            if not business_column:
                logger.warning(f"No business column found for table: {table_name}")
                return
            
            policy_name = f"tenant_isolation_{table_name}"
            
            # Drop policy if it exists
            cursor.execute(f"""
                DROP POLICY IF EXISTS {policy_name} ON {table_name};
            """)
            
            # Create the tenant isolation policy
            if table_name == 'businesses_businessaccount':
                # Special case for business account table
                cursor.execute(f"""
                    CREATE POLICY {policy_name} ON {table_name}
                    USING (
                        id = COALESCE(
                            NULLIF(current_setting('app.current_tenant_id', true), ''),
                            '0'
                        )::INTEGER
                    );
                """)
            else:
                # Standard policy for tables with business foreign key
                cursor.execute(f"""
                    CREATE POLICY {policy_name} ON {table_name}
                    USING (
                        {business_column} = COALESCE(
                            NULLIF(current_setting('app.current_tenant_id', true), ''),
                            '0'
                        )::INTEGER
                    );
                """)
            
            logger.debug(f"Created tenant policy for table: {table_name}")
            
        except Exception as e:
            logger.error(f"Error creating policy for {table_name}: {str(e)}")
            
    def _drop_tenant_policy(self, cursor, table_name):
        """Drop tenant isolation policy for a table"""
        
        try:
            policy_name = f"tenant_isolation_{table_name}"
            cursor.execute(f"DROP POLICY IF EXISTS {policy_name} ON {table_name};")
            logger.debug(f"Dropped tenant policy for table: {table_name}")
        except Exception as e:
            logger.warning(f"Could not drop policy for {table_name}: {str(e)}")
            
    def _get_business_column_name(self, table_name):
        """Get the business foreign key column name for a table"""
        
        business_column_map = {
            'businesses_businessaccount': 'id',  # Special case
            'businesses_businessmember': 'business_id',
            'menus_menu': 'business_id',
            'menus_menucategory': 'menu__business_id',  # Through relationship
            'menus_menuitem': 'category__menu__business_id',  # Through relationship
            'displays_displaydevice': 'business_id',
            'displays_displaygroup': 'business_id',
            'media_mediaasset': 'business_id',
            'analytics_analyticsevent': 'business_id'
        }
        
        return business_column_map.get(table_name)


class TenantContext:
    """Context manager for setting tenant context in database session"""
    
    def __init__(self, tenant_id):
        self.tenant_id = tenant_id
        self.connection = connection
        
    def __enter__(self):
        """Set tenant context when entering the context"""
        self.set_tenant_context(self.tenant_id)
        return self
        
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Clear tenant context when exiting the context"""
        self.clear_tenant_context()
        
    def set_tenant_context(self, tenant_id):
        """Set the current tenant context in the database session"""
        
        if self.connection.vendor == 'postgresql':
            with self.connection.cursor() as cursor:
                cursor.execute(
                    "SELECT set_config('app.current_tenant_id', %s, false);",
                    [str(tenant_id)]
                )
                logger.debug(f"Set tenant context to: {tenant_id}")
        else:
            logger.warning("Tenant context setting not supported for this database")
            
    def clear_tenant_context(self):
        """Clear the current tenant context in the database session"""
        
        if self.connection.vendor == 'postgresql':
            with self.connection.cursor() as cursor:
                cursor.execute("SELECT set_config('app.current_tenant_id', '', false);")
                logger.debug("Cleared tenant context")


def set_tenant_context(tenant_id):
    """Set tenant context for the current database session"""
    context = TenantContext(tenant_id)
    context.set_tenant_context(tenant_id)


def clear_tenant_context():
    """Clear tenant context for the current database session"""
    context = TenantContext(None)
    context.clear_tenant_context()


def with_tenant_context(tenant_id):
    """Decorator to execute a function with tenant context"""
    
    def decorator(func):
        def wrapper(*args, **kwargs):
            with TenantContext(tenant_id):
                return func(*args, **kwargs)
        return wrapper
    return decorator


class TenantAwareQuerySet:
    """Mixin for QuerySets to automatically enforce tenant isolation"""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
    def get_queryset(self):
        """Override to add tenant filtering"""
        qs = super().get_queryset()
        
        # Get current tenant from context
        from common.middleware import get_current_tenant
        tenant = get_current_tenant()
        
        if tenant and hasattr(self.model, 'business'):
            qs = qs.filter(business=tenant)
        
        return qs


class RLSTestCase:
    """Utility class for testing RLS policies"""
    
    def __init__(self):
        self.rls_manager = RLSManager()
        
    def test_tenant_isolation(self, tenant1_id, tenant2_id, model_class):
        """Test that tenant isolation works correctly"""
        
        results = {}
        
        # Test with tenant1 context
        with TenantContext(tenant1_id):
            tenant1_count = model_class.objects.count()
            results['tenant1_count'] = tenant1_count
            
        # Test with tenant2 context  
        with TenantContext(tenant2_id):
            tenant2_count = model_class.objects.count()
            results['tenant2_count'] = tenant2_count
            
        # Test without tenant context
        clear_tenant_context()
        no_context_count = model_class.objects.count()
        results['no_context_count'] = no_context_count
        
        return results
        
    def verify_policy_exists(self, table_name):
        """Verify that RLS policy exists for a table"""
        
        if connection.vendor != 'postgresql':
            return False
            
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT EXISTS (
                    SELECT 1 FROM pg_policies 
                    WHERE tablename = %s 
                    AND policyname LIKE 'tenant_isolation_%'
                );
            """, [table_name])
            
            return cursor.fetchone()[0]


# Initialize RLS manager instance
rls_manager = RLSManager()


def setup_rls_policies():
    """Setup all RLS policies - to be called during deployment"""
    try:
        rls_manager.create_all_policies()
        logger.info("RLS policies setup completed successfully")
        return True
    except Exception as e:
        logger.error(f"Failed to setup RLS policies: {str(e)}")
        return False


def teardown_rls_policies():
    """Teardown all RLS policies - for testing/debugging"""
    try:
        rls_manager.drop_all_policies()
        logger.info("RLS policies teardown completed successfully") 
        return True
    except Exception as e:
        logger.error(f"Failed to teardown RLS policies: {str(e)}")
        return False