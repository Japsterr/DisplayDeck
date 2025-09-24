"""
Menu views for DisplayDeck API.

Provides REST API endpoints for menu management including CRUD operations,
menu publishing, and real-time price updates.
"""

from rest_framework import status, generics, permissions, filters
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.response import Response
from rest_framework.viewsets import ModelViewSet
from django.contrib.auth import get_user_model
from django.shortcuts import get_object_or_404
from django.db.models import Q, Count, Avg, Min, Max
from django_filters.rest_framework import DjangoFilterBackend
from drf_spectacular.utils import extend_schema, OpenApiResponse, OpenApiParameter
from drf_spectacular.openapi import OpenApiTypes

from .models import Menu, MenuCategory, MenuItem
from .serializers import (
    MenuWithCategoriesSerializer,
    MenuDetailSerializer,
    MenuCompactSerializer,
    MenuCreateSerializer,
    MenuUpdateSerializer,
    MenuItemDetailSerializer,
    MenuItemCreateSerializer,
    MenuItemCompactSerializer,
    MenuCategoryWithItemsSerializer,
    MenuCategoryCompactSerializer
)
from apps.businesses.models import Business, BusinessMember
from apps.authentication.serializers import StandardErrorSerializer, ValidationErrorSerializer
from common.permissions import MenuPermission, BusinessPermission, BusinessPermissions, check_business_permission

User = get_user_model()


class BusinessMenuListView(generics.ListCreateAPIView):
    """
    API endpoint to list menus for a specific business or create a new menu.
    
    GET: Returns all menus for the business that the user has access to.
    POST: Creates a new menu for the business (requires menu creation permissions).
    """
    
    permission_classes = [BusinessPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['menu_type', 'is_active', 'is_default']
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'created_at', 'updated_at', 'menu_type']
    ordering = ['-is_default', 'name']
    
    def get_queryset(self):
        """Return menus for the specified business."""
        business_id = self.kwargs['business_id']
        business = get_object_or_404(Business, id=business_id)
        
        # Check if user has access to this business
        try:
            membership = BusinessMember.objects.get(
                business=business,
                user=self.request.user,
                is_active=True
            )
        except BusinessMember.DoesNotExist:
            return Menu.objects.none()
        
        return Menu.objects.filter(business=business).select_related(
            'business', 'last_updated_by'
        ).prefetch_related('menu_items')
    
    def get_serializer_class(self):
        """Return appropriate serializer based on action."""
        if self.request.method == 'POST':
            return MenuCreateSerializer
        return MenuCompactSerializer
    
    def get_serializer_context(self):
        """Add business context to serializer."""
        context = super().get_serializer_context()
        if 'business_id' in self.kwargs:
            business = get_object_or_404(Business, id=self.kwargs['business_id'])
            context['business'] = business
        return context
    
    def perform_create(self, serializer):
        """Create menu with proper business association and permission checking."""
        business = self.get_serializer_context()['business']
        
        # Check if user has permission to create menus
        if not check_business_permission(self.request.user, business, 
                                       BusinessPermissions.CREATE_MENUS):
            raise permissions.PermissionDenied(
                "You don't have permission to create menus for this business."
            )
        
        serializer.save()
    
    @extend_schema(
        responses={
            200: MenuCompactSerializer(many=True),
            404: StandardErrorSerializer,
        },
        parameters=[
            OpenApiParameter('business_id', OpenApiTypes.UUID, OpenApiParameter.PATH,
                           description='ID of the business'),
            OpenApiParameter('menu_type', OpenApiTypes.STR, description='Filter by menu type'),
            OpenApiParameter('is_active', OpenApiTypes.BOOL, description='Filter by active status'),
            OpenApiParameter('search', OpenApiTypes.STR, description='Search menus by name or description'),
        ],
        tags=['Menus'],
        summary="List business menus",
        description="Retrieve all menus for a specific business."
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)
    
    @extend_schema(
        request=MenuCreateSerializer,
        responses={
            201: MenuDetailSerializer,
            400: ValidationErrorSerializer,
            403: StandardErrorSerializer,
        },
        tags=['Menus'],
        summary="Create new menu",
        description="Create a new menu for the specified business."
    )
    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        
        # Return detailed menu data on successful creation
        if response.status_code == status.HTTP_201_CREATED:
            menu = Menu.objects.get(id=response.data['id'])
            detailed_serializer = MenuDetailSerializer(menu, context=self.get_serializer_context())
            return Response(detailed_serializer.data, status=status.HTTP_201_CREATED)
        
        return response


class MenuViewSet(ModelViewSet):
    """
    ViewSet for menu CRUD operations.
    
    Provides endpoints for retrieving, updating, and deleting individual menus,
    as well as additional actions for menu management.
    """
    
    permission_classes = [MenuPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['menu_type', 'is_active', 'is_default']
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'created_at', 'updated_at']
    ordering = ['name']
    
    def get_queryset(self):
        """Return menus the user has access to."""
        return Menu.objects.filter(
            business__members=self.request.user,
            business__memberships__is_active=True
        ).distinct().select_related('business', 'last_updated_by')
    
    def get_serializer_class(self):
        """Return appropriate serializer based on action."""
        if self.action == 'create':
            return MenuCreateSerializer
        elif self.action in ['update', 'partial_update']:
            return MenuUpdateSerializer
        elif self.action == 'list':
            return MenuCompactSerializer
        elif self.action == 'with_items':
            return MenuWithCategoriesSerializer
        return MenuDetailSerializer
    
    @extend_schema(
        responses={
            200: MenuWithCategoriesSerializer,
            404: StandardErrorSerializer,
        },
        tags=['Menus'],
        summary="Get menu with full structure",
        description="Retrieve menu with complete category and item nesting."
    )
    @action(detail=True, methods=['get'])
    def with_items(self, request, pk=None):
        """Get menu with full category and item structure."""
        menu = self.get_object()
        serializer = MenuWithCategoriesSerializer(menu, context={'request': request})
        return Response(serializer.data)
    
    @extend_schema(
        responses={
            200: {"description": "Menu published successfully"},
            400: StandardErrorSerializer,
            403: StandardErrorSerializer,
        },
        tags=['Menus'],
        summary="Publish menu",
        description="Publish menu to all associated displays."
    )
    @action(detail=True, methods=['post'])
    def publish(self, request, pk=None):
        """Publish menu to displays."""
        menu = self.get_object()
        
        # Check if user has permission to publish menus
        if not check_business_permission(request.user, menu.business, 
                                       BusinessPermissions.PUBLISH_MENUS):
            return Response({
                'error': "You don't have permission to publish menus."
            }, status=status.HTTP_403_FORBIDDEN)
        
        menu.publish(user=request.user)
        
        # Trigger real-time updates (will be implemented with WebSocket)
        # This is where we'd broadcast to displays
        
        return Response({
            'message': 'Menu published successfully.',
            'published_at': menu.published_at
        })
    
    @extend_schema(
        responses={
            200: MenuDetailSerializer,
            404: StandardErrorSerializer,
            403: StandardErrorSerializer,
        },
        tags=['Menus'],
        summary="Clone menu",
        description="Create a copy of this menu."
    )
    @action(detail=True, methods=['post'])
    def clone(self, request, pk=None):
        """Clone a menu."""
        original_menu = self.get_object()
        
        # Check if user has permission to create menus
        if not check_business_permission(request.user, original_menu.business, 
                                       BusinessPermissions.CREATE_MENUS):
            return Response({
                'error': "You don't have permission to create menus."
            }, status=status.HTTP_403_FORBIDDEN)
        
        new_name = request.data.get('name', f"{original_menu.name} (Copy)")
        cloned_menu = original_menu.clone(new_name, user=request.user)
        
        serializer = MenuDetailSerializer(cloned_menu, context={'request': request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    @extend_schema(
        responses={
            200: MenuCategoryWithItemsSerializer(many=True),
            404: StandardErrorSerializer,
        },
        tags=['Menus'],
        summary="Get menu categories",
        description="Retrieve all categories for this menu."
    )
    @action(detail=True, methods=['get'])
    def categories(self, request, pk=None):
        """Get menu categories."""
        menu = self.get_object()
        categories = menu.get_categories()
        
        serializer = MenuCategoryWithItemsSerializer(
            categories, many=True, context={'request': request}
        )
        return Response(serializer.data)
    
    @extend_schema(
        responses={
            200: MenuItemDetailSerializer(many=True),
            404: StandardErrorSerializer,
        },
        parameters=[
            OpenApiParameter('category', OpenApiTypes.UUID, description='Filter by category ID'),
            OpenApiParameter('is_featured', OpenApiTypes.BOOL, description='Filter by featured items'),
            OpenApiParameter('is_available', OpenApiTypes.BOOL, description='Filter by availability'),
        ],
        tags=['Menus'],
        summary="Get menu items",
        description="Retrieve all items for this menu with optional filtering."
    )
    @action(detail=True, methods=['get'])
    def items(self, request, pk=None):
        """Get menu items."""
        menu = self.get_object()
        items = menu.menu_items.filter(is_active=True).select_related('category')
        
        # Apply filters
        category_id = request.query_params.get('category')
        if category_id:
            items = items.filter(category_id=category_id)
        
        is_featured = request.query_params.get('is_featured')
        if is_featured is not None:
            items = items.filter(is_featured=is_featured.lower() == 'true')
        
        is_available = request.query_params.get('is_available')
        if is_available is not None:
            available = is_available.lower() == 'true'
            if available:
                # Filter for available items (complex query)
                from django.utils import timezone
                now = timezone.now()
                current_time = now.time()
                current_weekday = now.weekday()
                
                items = items.filter(
                    Q(available_days__isnull=True) | Q(available_days__contains=[current_weekday]),
                    Q(available_from__isnull=True) | Q(available_from__lte=current_time),
                    Q(available_until__isnull=True) | Q(available_until__gte=current_time),
                    Q(track_inventory=False) | Q(inventory_count__gt=0)
                )
        
        serializer = MenuItemDetailSerializer(
            items, many=True, context={'request': request}
        )
        return Response(serializer.data)
    
    @extend_schema(
        request=MenuItemCreateSerializer,
        responses={
            201: MenuItemDetailSerializer,
            400: ValidationErrorSerializer,
            403: StandardErrorSerializer,
        },
        tags=['Menus'],
        summary="Add menu item",
        description="Add a new item to this menu."
    )
    @action(detail=True, methods=['post'], url_path='items')
    def add_item(self, request, pk=None):
        """Add a new item to the menu."""
        menu = self.get_object()
        
        # Check if user has permission to edit menus
        if not check_business_permission(request.user, menu.business, 
                                       BusinessPermissions.EDIT_MENUS):
            return Response({
                'error': "You don't have permission to edit menus."
            }, status=status.HTTP_403_FORBIDDEN)
        
        serializer = MenuItemCreateSerializer(
            data=request.data,
            context={'menu': menu, 'request': request}
        )
        serializer.is_valid(raise_exception=True)
        item = serializer.save()
        
        response_serializer = MenuItemDetailSerializer(item, context={'request': request})
        return Response(response_serializer.data, status=status.HTTP_201_CREATED)


@extend_schema(
    request={"price": {"type": "number", "format": "decimal"}},
    responses={
        200: {"description": "Price updated successfully"},
        400: StandardErrorSerializer,
        404: StandardErrorSerializer,
        403: StandardErrorSerializer,
    },
    tags=['Menus'],
    summary="Update item price",
    description="Update the price of a specific menu item in real-time."
)
@api_view(['PATCH'])
@permission_classes([permissions.IsAuthenticated])
def update_item_price(request, menu_id, item_id):
    """
    T052: PATCH /api/v1/menus/{id}/items/{item_id}/price endpoint for real-time price updates.
    
    This endpoint allows for quick price updates that will be broadcast to all displays.
    """
    try:
        menu = Menu.objects.get(id=menu_id)
        item = menu.menu_items.get(id=item_id)
    except (Menu.DoesNotExist, MenuItem.DoesNotExist):
        return Response({
            'error': 'Menu or item not found.'
        }, status=status.HTTP_404_NOT_FOUND)
    
    # Check permissions
    if not check_business_permission(request.user, menu.business, 
                                   BusinessPermissions.EDIT_MENUS):
        return Response({
            'error': "You don't have permission to edit menu prices."
        }, status=status.HTTP_403_FORBIDDEN)
    
    # Validate price
    try:
        new_price = request.data.get('price')
        if new_price is None:
            return Response({
                'error': 'Price is required.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        new_price = float(new_price)
        if new_price <= 0:
            return Response({
                'error': 'Price must be greater than zero.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
    except (ValueError, TypeError):
        return Response({
            'error': 'Invalid price format.'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Update price
    old_price = item.price
    item.price = new_price
    item.last_updated_by = request.user
    item.save(update_fields=['price', 'last_updated_by', 'updated_at'])
    
    # Trigger real-time updates (will be implemented with WebSocket)
    # This is where we'd broadcast price changes to displays
    
    return Response({
        'message': 'Price updated successfully.',
        'old_price': str(old_price),
        'new_price': str(new_price),
        'item_id': str(item.id),
        'updated_at': item.updated_at
    })


class MenuItemViewSet(ModelViewSet):
    """
    ViewSet for individual menu item CRUD operations.
    """
    
    permission_classes = [MenuPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['category', 'item_type', 'is_featured', 'is_popular', 'is_active']
    search_fields = ['name', 'description', 'tags']
    ordering_fields = ['name', 'price', 'sort_order', 'created_at']
    ordering = ['category__sort_order', 'sort_order', 'name']
    
    def get_queryset(self):
        """Return menu items the user has access to."""
        return MenuItem.objects.filter(
            menu__business__members=self.request.user,
            menu__business__memberships__is_active=True
        ).distinct().select_related(
            'menu', 'category', 'created_by', 'last_updated_by'
        )
    
    def get_serializer_class(self):
        """Return appropriate serializer based on action."""
        if self.action == 'create':
            return MenuItemCreateSerializer
        elif self.action == 'list':
            return MenuItemCompactSerializer
        return MenuItemDetailSerializer
    
    def perform_update(self, serializer):
        """Update item with user tracking."""
        serializer.save(last_updated_by=self.request.user)
    
    @extend_schema(
        responses={
            200: {"description": "Inventory updated successfully"},
            400: StandardErrorSerializer,
            404: StandardErrorSerializer,
            403: StandardErrorSerializer,
        },
        tags=['Menu Items'],
        summary="Update item inventory",
        description="Update inventory count for a menu item."
    )
    @action(detail=True, methods=['patch'])
    def inventory(self, request, pk=None):
        """Update item inventory."""
        item = self.get_object()
        
        # Check permissions
        if not check_business_permission(request.user, item.menu.business, 
                                       BusinessPermissions.EDIT_MENUS):
            return Response({
                'error': "You don't have permission to update inventory."
            }, status=status.HTTP_403_FORBIDDEN)
        
        if not item.track_inventory:
            return Response({
                'error': 'Inventory tracking is not enabled for this item.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Validate inventory count
        try:
            new_count = request.data.get('inventory_count')
            if new_count is None:
                return Response({
                    'error': 'inventory_count is required.'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            new_count = int(new_count)
            if new_count < 0:
                return Response({
                    'error': 'Inventory count cannot be negative.'
                }, status=status.HTTP_400_BAD_REQUEST)
            
        except (ValueError, TypeError):
            return Response({
                'error': 'Invalid inventory count format.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Update inventory
        old_count = item.inventory_count
        item.inventory_count = new_count
        item.last_updated_by = request.user
        item.save(update_fields=['inventory_count', 'last_updated_by', 'updated_at'])
        
        return Response({
            'message': 'Inventory updated successfully.',
            'old_count': old_count,
            'new_count': new_count,
            'is_low_stock': item.is_low_stock(),
            'is_out_of_stock': item.is_out_of_stock(),
            'updated_at': item.updated_at
        })