"""
CRITICAL: Performance and Load Testing Contract Tests

These tests MUST FAIL until performance optimization and load handling is implemented.
They define exact performance requirements from our specification.

Performance requirements tested:
- API response time benchmarks
- WebSocket message throughput
- Database query optimization
- Concurrent user handling
- Memory and CPU usage limits
- Display update latency
"""

import pytest
import time
import asyncio
import threading
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed
from django.test import TestCase, TransactionTestCase, override_settings
from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from django.db import connection
from django.test.utils import override_settings
import psutil
import gc

User = get_user_model()


class TestAPIPerformanceBenchmarks(APITestCase):
    """Test API performance benchmarks - MUST FAIL initially"""

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            email='perf@example.com',
            password='SecurePass123!'
        )
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')

    def test_authentication_endpoint_performance(self):
        """Authentication endpoints must respond within 200ms"""
        # This MUST FAIL until performance optimization is implemented
        
        login_data = {
            'email': 'perf@example.com',
            'password': 'SecurePass123!'
        }
        
        # Measure login performance
        start_time = time.time()
        response = self.client.post('/api/auth/login', login_data, format='json')
        end_time = time.time()
        
        response_time = (end_time - start_time) * 1000  # Convert to milliseconds
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertLess(response_time, 200, f"Login took {response_time:.2f}ms, expected < 200ms")
        
        # Measure token refresh performance
        refresh_data = {
            'refresh': response.data['refresh_token']
        }
        
        start_time = time.time()
        refresh_response = self.client.post('/api/auth/refresh', refresh_data, format='json')
        end_time = time.time()
        
        refresh_time = (end_time - start_time) * 1000
        
        self.assertEqual(refresh_response.status_code, status.HTTP_200_OK)
        self.assertLess(refresh_time, 100, f"Token refresh took {refresh_time:.2f}ms, expected < 100ms")

    def test_menu_api_performance_benchmarks(self):
        """Menu API endpoints must meet performance requirements"""
        # This MUST FAIL until optimization is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu, MenuItem
        
        # Create test data
        business = Business.objects.create(
            name='Performance Restaurant',
            slug='performance-restaurant',
            owner=self.user
        )
        
        menu = Menu.objects.create(
            name='Performance Menu',
            business=business,
            created_by=self.user
        )
        
        # Create 100 menu items for realistic load
        for i in range(100):
            MenuItem.objects.create(
                menu=menu,
                name=f'Menu Item {i}',
                description=f'Description for item {i}',
                price=f'{9.99 + (i * 0.1):.2f}',
                is_available=True
            )
        
        # Test menu list performance (should be < 150ms)
        start_time = time.time()
        menu_list_response = self.client.get(f'/api/businesses/{business.id}/menus')
        end_time = time.time()
        
        list_time = (end_time - start_time) * 1000
        
        self.assertEqual(menu_list_response.status_code, status.HTTP_200_OK)
        self.assertLess(list_time, 150, f"Menu list took {list_time:.2f}ms, expected < 150ms")
        
        # Test menu detail performance with all items (should be < 300ms)
        start_time = time.time()
        menu_detail_response = self.client.get(f'/api/menus/{menu.id}')
        end_time = time.time()
        
        detail_time = (end_time - start_time) * 1000
        
        self.assertEqual(menu_detail_response.status_code, status.HTTP_200_OK)
        self.assertLess(detail_time, 300, f"Menu detail took {detail_time:.2f}ms, expected < 300ms")
        
        # Verify all 100 items are included
        self.assertEqual(len(menu_detail_response.data['categories'][0]['items']), 100)

    def test_database_query_optimization(self):
        """Database queries must be optimized to prevent N+1 problems"""
        # This MUST FAIL until query optimization is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu, MenuItem
        from django.db import connection
        
        # Create test data with relationships
        business = Business.objects.create(
            name='Query Test Restaurant',
            slug='query-test-restaurant',
            owner=self.user
        )
        
        menus = []
        for i in range(10):
            menu = Menu.objects.create(
                name=f'Menu {i}',
                business=business,
                created_by=self.user
            )
            menus.append(menu)
            
            # Add items to each menu
            for j in range(20):
                MenuItem.objects.create(
                    menu=menu,
                    name=f'Item {j} in Menu {i}',
                    price='9.99'
                )
        
        # Reset query count
        connection.queries_log.clear()
        
        # Fetch business with all menus and items
        start_queries = len(connection.queries)
        
        response = self.client.get(f'/api/businesses/{business.id}/menus')
        
        end_queries = len(connection.queries)
        query_count = end_queries - start_queries
        
        # Should use select_related/prefetch_related to minimize queries
        # Expecting: 1 for business, 1 for menus, 1 for items = 3 queries max
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertLess(query_count, 5, f"Menu list used {query_count} queries, expected < 5")
        
        # Verify all data is returned
        self.assertEqual(len(response.data['results']), 10)

    def test_bulk_operations_performance(self):
        """Bulk operations must be significantly faster than individual operations"""
        # This MUST FAIL until bulk optimization is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu, MenuItem
        
        business = Business.objects.create(
            name='Bulk Test Restaurant',
            slug='bulk-test-restaurant',
            owner=self.user
        )
        
        menu = Menu.objects.create(
            name='Bulk Test Menu',
            business=business,
            created_by=self.user
        )
        
        # Create 50 items
        items = []
        for i in range(50):
            item = MenuItem.objects.create(
                menu=menu,
                name=f'Bulk Item {i}',
                price='9.99',
                is_available=True
            )
            items.append(item)
        
        item_ids = [item.id for item in items]
        
        # Test bulk availability update performance
        bulk_data = {
            'item_ids': item_ids,
            'is_available': False
        }
        
        start_time = time.time()
        bulk_response = self.client.post(f'/api/menus/{menu.id}/bulk-availability', bulk_data, format='json')
        end_time = time.time()
        
        bulk_time = (end_time - start_time) * 1000
        
        self.assertEqual(bulk_response.status_code, status.HTTP_200_OK)
        self.assertEqual(bulk_response.data['updated_count'], 50)
        
        # Bulk operation should complete in < 500ms for 50 items
        self.assertLess(bulk_time, 500, f"Bulk update took {bulk_time:.2f}ms, expected < 500ms")
        
        # Verify bulk operation efficiency (should use UPDATE WHERE id IN (...))
        # Individual updates would take much longer


class TestConcurrentUserHandling(APITestCase):
    """Test concurrent user handling - MUST FAIL initially"""

    def setUp(self):
        self.base_url = 'http://testserver'  # Test server base URL

    def test_concurrent_authentication_load(self):
        """System must handle concurrent authentication requests"""
        # This MUST FAIL until concurrency optimization is implemented
        
        # Create test users
        users = []
        for i in range(20):
            user = User.objects.create_user(
                email=f'concurrent{i}@example.com',
                password='SecurePass123!'
            )
            users.append(user)
        
        def login_user(user_data):
            """Login function for concurrent testing"""
            client = APIClient()
            login_data = {
                'email': user_data['email'],
                'password': 'SecurePass123!'
            }
            
            start_time = time.time()
            response = client.post('/api/auth/login', login_data, format='json')
            end_time = time.time()
            
            return {
                'email': user_data['email'],
                'status_code': response.status_code,
                'response_time': (end_time - start_time) * 1000,
                'success': response.status_code == 200
            }
        
        # Execute concurrent logins
        start_time = time.time()
        
        with ThreadPoolExecutor(max_workers=10) as executor:
            user_data = [{'email': user.email} for user in users]
            futures = [executor.submit(login_user, data) for data in user_data]
            results = [future.result() for future in as_completed(futures)]
        
        end_time = time.time()
        total_time = (end_time - start_time) * 1000
        
        # Analyze results
        successful_logins = sum(1 for r in results if r['success'])
        max_response_time = max(r['response_time'] for r in results)
        avg_response_time = sum(r['response_time'] for r in results) / len(results)
        
        # All logins should succeed
        self.assertEqual(successful_logins, 20, "All concurrent logins should succeed")
        
        # No individual request should exceed 1000ms under load
        self.assertLess(max_response_time, 1000, f"Max response time was {max_response_time:.2f}ms")
        
        # Average response time should be reasonable
        self.assertLess(avg_response_time, 500, f"Average response time was {avg_response_time:.2f}ms")
        
        # Total time should be significantly less than sequential execution
        sequential_estimate = 20 * 200  # 20 users * 200ms each
        self.assertLess(total_time, sequential_estimate * 0.7, "Concurrent execution should be faster")

    def test_concurrent_menu_updates_with_websocket_broadcast(self):
        """System must handle concurrent menu updates with real-time broadcasting"""
        # This MUST FAIL until concurrent WebSocket handling is implemented
        
        from apps.businesses.models import Business
        from apps.menus.models import Menu, MenuItem
        from apps.displays.models import Display
        
        # Create test business and menu
        owner = User.objects.create_user(
            email='concurrent_owner@example.com',
            password='SecurePass123!'
        )
        
        business = Business.objects.create(
            name='Concurrent Test Restaurant',
            slug='concurrent-test-restaurant',
            owner=owner
        )
        
        menu = Menu.objects.create(
            name='Concurrent Test Menu',
            business=business,
            created_by=owner
        )
        
        # Create 20 menu items
        items = []
        for i in range(20):
            item = MenuItem.objects.create(
                menu=menu,
                name=f'Concurrent Item {i}',
                price='9.99',
                is_available=True
            )
            items.append(item)
        
        # Create 5 displays
        displays = []
        for i in range(5):
            display = Display.objects.create(
                name=f'Concurrent Display {i}',
                business=business,
                created_by=owner
            )
            displays.append(display)
        
        def update_item_availability(item_data):
            """Update item availability concurrently"""
            client = APIClient()
            refresh = RefreshToken.for_user(owner)
            client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
            
            update_data = {
                'is_available': not item_data['current_availability']
            }
            
            start_time = time.time()
            response = client.patch(f'/api/menu-items/{item_data["item_id"]}', update_data, format='json')
            end_time = time.time()
            
            return {
                'item_id': item_data['item_id'],
                'status_code': response.status_code,
                'response_time': (end_time - start_time) * 1000,
                'success': response.status_code == 200
            }
        
        # Execute concurrent updates
        item_data = [
            {'item_id': item.id, 'current_availability': item.is_available}
            for item in items
        ]
        
        start_time = time.time()
        
        with ThreadPoolExecutor(max_workers=8) as executor:
            futures = [executor.submit(update_item_availability, data) for data in item_data]
            results = [future.result() for future in as_completed(futures)]
        
        end_time = time.time()
        total_time = (end_time - start_time) * 1000
        
        # All updates should succeed without conflicts
        successful_updates = sum(1 for r in results if r['success'])
        self.assertEqual(successful_updates, 20, "All concurrent updates should succeed")
        
        # No database deadlocks or race conditions
        max_response_time = max(r['response_time'] for r in results)
        self.assertLess(max_response_time, 2000, "No update should take longer than 2 seconds")
        
        # WebSocket broadcasts should be sent to all displays (would be tested with WebSocket connections)

    def test_memory_usage_under_load(self):
        """Memory usage must remain stable under high load"""
        # This MUST FAIL until memory optimization is implemented
        
        initial_memory = psutil.Process().memory_info().rss / 1024 / 1024  # MB
        
        # Create test data and perform operations
        users = []
        for i in range(50):
            user = User.objects.create_user(
                email=f'memory{i}@example.com',
                password='SecurePass123!'
            )
            users.append(user)
        
        # Perform memory-intensive operations
        for user in users:
            refresh = RefreshToken.for_user(user)
            client = APIClient()
            client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
            
            # Create business and menu data
            from apps.businesses.models import Business
            from apps.menus.models import Menu, MenuItem
            
            business = Business.objects.create(
                name=f'Memory Test Business {user.id}',
                slug=f'memory-test-{user.id}',
                owner=user
            )
            
            menu = Menu.objects.create(
                name=f'Memory Test Menu {user.id}',
                business=business,
                created_by=user
            )
            
            # Create menu items
            for j in range(10):
                MenuItem.objects.create(
                    menu=menu,
                    name=f'Memory Item {j}',
                    price='9.99'
                )
            
            # Make API calls
            client.get(f'/api/businesses/{business.id}/menus')
            client.get(f'/api/menus/{menu.id}')
        
        # Force garbage collection
        gc.collect()
        
        final_memory = psutil.Process().memory_info().rss / 1024 / 1024  # MB
        memory_increase = final_memory - initial_memory
        
        # Memory increase should be reasonable (< 100MB for this test)
        self.assertLess(memory_increase, 100, f"Memory increased by {memory_increase:.2f}MB, expected < 100MB")
        
        # Check for memory leaks by running operations again
        pre_second_run = final_memory
        
        # Perform same operations again
        for user in users[:10]:  # Smaller subset for second run
            refresh = RefreshToken.for_user(user)
            client = APIClient()
            client.credentials(HTTP_AUTHORIZATION=f'Bearer {refresh.access_token}')
            
            # Get existing data (should use caching)
            client.get('/api/businesses')
        
        gc.collect()
        post_second_run = psutil.Process().memory_info().rss / 1024 / 1024
        
        second_run_increase = post_second_run - pre_second_run
        
        # Second run should not significantly increase memory (< 10MB)
        self.assertLess(second_run_increase, 10, f"Second run increased memory by {second_run_increase:.2f}MB")


@pytest.mark.asyncio
class TestWebSocketPerformance(TransactionTestCase):
    """Test WebSocket performance - MUST FAIL initially"""

    def setUp(self):
        self.owner = User.objects.create_user(
            email='ws_owner@example.com',
            password='SecurePass123!'
        )

    async def test_websocket_message_throughput(self):
        """WebSocket connections must handle high message throughput"""
        # This MUST FAIL until WebSocket optimization is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        from core.routing import application
        from channels.testing import WebsocketCommunicator
        
        business = Business.objects.create(
            name='WS Performance Test',
            slug='ws-performance-test',
            owner=self.owner
        )
        
        display = Display.objects.create(
            name='Performance Display',
            business=business,
            created_by=self.owner
        )
        
        # Connect to WebSocket
        display_token = f"perf-token-{display.id}"
        communicator = WebsocketCommunicator(
            application,
            f"/ws/displays/{display_token}/"
        )
        
        connected, _ = await communicator.connect()
        self.assertTrue(connected)
        
        # Skip connection confirmation
        await communicator.receive_json_from()
        
        # Test message throughput
        message_count = 100
        start_time = time.time()
        
        # Send messages rapidly
        for i in range(message_count):
            message = {
                'type': 'item_availability',
                'data': {
                    'item_id': i,
                    'is_available': i % 2 == 0,
                    'timestamp': datetime.now().isoformat()
                }
            }
            await communicator.send_json_to(message)
        
        # Receive all messages
        received_messages = []
        for i in range(message_count):
            message = await communicator.receive_json_from()
            received_messages.append(message)
        
        end_time = time.time()
        total_time = (end_time - start_time) * 1000  # milliseconds
        
        # Calculate throughput
        messages_per_second = (message_count * 2) / (total_time / 1000)  # Send + receive
        
        # Should handle at least 200 messages/second
        self.assertGreater(messages_per_second, 200, f"Throughput was {messages_per_second:.2f} msg/s")
        
        # Verify all messages received correctly
        self.assertEqual(len(received_messages), message_count)
        
        await communicator.disconnect()

    async def test_multiple_websocket_connections_performance(self):
        """System must handle multiple concurrent WebSocket connections"""
        # This MUST FAIL until concurrent WebSocket handling is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        from core.routing import application
        from channels.testing import WebsocketCommunicator
        
        business = Business.objects.create(
            name='Multi WS Test',
            slug='multi-ws-test',
            owner=self.owner
        )
        
        # Create multiple displays and connections
        connection_count = 20
        communicators = []
        displays = []
        
        # Setup connections
        for i in range(connection_count):
            display = Display.objects.create(
                name=f'Multi Display {i}',
                business=business,
                created_by=self.owner
            )
            displays.append(display)
            
            display_token = f"multi-token-{display.id}"
            communicator = WebsocketCommunicator(
                application,
                f"/ws/displays/{display_token}/"
            )
            
            connected, _ = await communicator.connect()
            self.assertTrue(connected, f"Connection {i} failed")
            await communicator.receive_json_from()  # Skip confirmation
            communicators.append(communicator)
        
        # Test broadcast performance
        broadcast_message = {
            'type': 'business_announcement',
            'data': {
                'title': 'Performance Test',
                'message': 'Testing broadcast performance',
                'timestamp': datetime.now().isoformat()
            }
        }
        
        start_time = time.time()
        
        # Broadcast to all connections
        for communicator in communicators:
            await communicator.send_json_to(broadcast_message)
        
        # Receive on all connections
        received_count = 0
        for communicator in communicators:
            try:
                message = await communicator.receive_json_from()
                if message['type'] == 'business_announcement':
                    received_count += 1
            except Exception as e:
                self.fail(f"Failed to receive message: {e}")
        
        end_time = time.time()
        broadcast_time = (end_time - start_time) * 1000
        
        # All connections should receive the broadcast
        self.assertEqual(received_count, connection_count)
        
        # Broadcast should complete within reasonable time (< 2 seconds for 20 connections)
        self.assertLess(broadcast_time, 2000, f"Broadcast took {broadcast_time:.2f}ms")
        
        # Cleanup
        for communicator in communicators:
            await communicator.disconnect()

    async def test_websocket_connection_stability_under_load(self):
        """WebSocket connections must remain stable under continuous load"""
        # This MUST FAIL until connection stability is implemented
        
        from apps.businesses.models import Business
        from apps.displays.models import Display
        from core.routing import application
        from channels.testing import WebsocketCommunicator
        
        business = Business.objects.create(
            name='Stability Test',
            slug='stability-test',
            owner=self.owner
        )
        
        display = Display.objects.create(
            name='Stability Display',
            business=business,
            created_by=self.owner
        )
        
        display_token = f"stability-token-{display.id}"
        communicator = WebsocketCommunicator(
            application,
            f"/ws/displays/{display_token}/"
        )
        
        connected, _ = await communicator.connect()
        self.assertTrue(connected)
        await communicator.receive_json_from()  # Skip confirmation
        
        # Send messages continuously for extended period
        duration_seconds = 30
        message_interval = 0.1  # 10 messages per second
        expected_messages = int(duration_seconds / message_interval)
        
        sent_count = 0
        received_count = 0
        start_time = time.time()
        
        async def sender():
            nonlocal sent_count
            while time.time() - start_time < duration_seconds:
                message = {
                    'type': 'heartbeat',
                    'data': {
                        'timestamp': datetime.now().isoformat(),
                        'sequence': sent_count
                    }
                }
                await communicator.send_json_to(message)
                sent_count += 1
                await asyncio.sleep(message_interval)
        
        async def receiver():
            nonlocal received_count
            while time.time() - start_time < duration_seconds + 5:  # Extra time for final messages
                try:
                    message = await communicator.receive_json_from()
                    if message.get('type') == 'heartbeat':
                        received_count += 1
                except Exception:
                    break
        
        # Run sender and receiver concurrently
        await asyncio.gather(sender(), receiver())
        
        # Connection should remain stable throughout the test
        # Allow for some message loss due to test timing (95% threshold)
        min_expected = int(expected_messages * 0.95)
        
        self.assertGreater(received_count, min_expected,
                         f"Received {received_count} messages, expected > {min_expected}")
        
        # Connection should still be active
        ping_message = {'type': 'ping', 'data': {}}
        await communicator.send_json_to(ping_message)
        
        response = await communicator.receive_json_from()
        self.assertEqual(response.get('type'), 'ping')
        
        await communicator.disconnect()


# These tests MUST all FAIL initially - they define our performance contracts
if __name__ == '__main__':
    pytest.main([__file__, '-v'])