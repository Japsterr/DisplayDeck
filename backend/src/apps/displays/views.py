"""
Display views for DisplayDeck API.

Provides REST API endpoints for display management including device registration,
pairing, status monitoring, and menu assignment.
"""

from rest_framework import status, generics, permissions, filters
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.response import Response
from rest_framework.viewsets import ModelViewSet
from django.contrib.auth import get_user_model
from django.shortcuts import get_object_or_404
from django.db.models import Q, Count
from django_filters.rest_framework import DjangoFilterBackend
from drf_spectacular.utils import extend_schema, OpenApiResponse, OpenApiParameter
from drf_spectacular.openapi import OpenApiTypes
from django.utils import timezone

from .models import Display, DisplayGroup, DisplayMenuAssignment, DisplaySession
from .serializers import (
    DisplayCompactSerializer,
    DisplayDetailSerializer,
    DisplayCreateSerializer,
    DisplayPairingSerializer,
    DisplayMenuAssignmentSerializer,
    DisplayMenuAssignmentCreateSerializer,
    DisplayStatusSerializer,
    DisplayGroupSerializer,
    DisplaySessionSerializer,
    DisplayHealthCheckSerializer
)
from apps.businesses.models import Business, BusinessMember
from apps.menus.models import Menu
from apps.authentication.serializers import StandardErrorSerializer, ValidationErrorSerializer
from common.permissions import DisplayPermission, BusinessPermission, BusinessPermissions, check_business_permission

User = get_user_model()


class BusinessDisplayListView(generics.ListCreateAPIView):
    """
    API endpoint to list displays for a specific business or register a new display.
    
    GET: Returns all displays for the business that the user has access to.
    POST: Registers a new display for the business (requires display management permissions).
    """
    
    permission_classes = [BusinessPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['device_type', 'status', 'is_active', 'orientation']
    search_fields = ['name', 'location', 'device_model']
    ordering_fields = ['name', 'location', 'created_at', 'last_seen_at']
    ordering = ['name']
    
    def get_queryset(self):
        """Return displays for the specified business."""
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
            return Display.objects.none()
        
        return Display.objects.filter(business=business).select_related(
            'business', 'current_menu', 'paired_by'
        )
    
    def get_serializer_class(self):
        """Return appropriate serializer based on action."""
        if self.request.method == 'POST':
            return DisplayCreateSerializer
        return DisplayCompactSerializer
    
    def get_serializer_context(self):
        """Add business context to serializer."""
        context = super().get_serializer_context()
        if 'business_id' in self.kwargs:
            business = get_object_or_404(Business, id=self.kwargs['business_id'])
            context['business'] = business
        return context
    
    def perform_create(self, serializer):
        """Create display with proper business association and permission checking."""
        business = self.get_serializer_context()['business']
        
        # Check if user has permission to manage displays
        if not check_business_permission(self.request.user, business, 
                                       BusinessPermissions.MANAGE_DISPLAYS):
            raise permissions.PermissionDenied(
                "You don't have permission to manage displays for this business."
            )
        
        serializer.save()
    
    @extend_schema(
        responses={
            200: DisplayCompactSerializer(many=True),
            404: StandardErrorSerializer,
        },
        parameters=[
            OpenApiParameter('business_id', OpenApiTypes.UUID, OpenApiParameter.PATH,
                           description='ID of the business'),
            OpenApiParameter('device_type', OpenApiTypes.STR, description='Filter by device type'),
            OpenApiParameter('status', OpenApiTypes.STR, description='Filter by status'),
            OpenApiParameter('search', OpenApiTypes.STR, description='Search displays by name or location'),
        ],
        tags=['Displays'],
        summary="List business displays",
        description="Retrieve all displays for a specific business."
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)
    
    @extend_schema(
        request=DisplayCreateSerializer,
        responses={
            201: DisplayDetailSerializer,
            400: ValidationErrorSerializer,
            403: StandardErrorSerializer,
        },
        tags=['Displays'],
        summary="Register new display",
        description="Register a new display device for the specified business."
    )
    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        
        # Return detailed display data on successful creation
        if response.status_code == status.HTTP_201_CREATED:
            display = Display.objects.get(id=response.data['id'])
            detailed_serializer = DisplayDetailSerializer(display, context=self.get_serializer_context())
            return Response(detailed_serializer.data, status=status.HTTP_201_CREATED)
        
        return response


class DisplayViewSet(ModelViewSet):
    """
    ViewSet for display CRUD operations and management actions.
    
    Provides endpoints for display details, pairing, status monitoring, and menu assignment.
    """
    
    permission_classes = [DisplayPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['device_type', 'status', 'is_active', 'orientation']
    search_fields = ['name', 'location', 'device_model']
    ordering_fields = ['name', 'last_seen_at', 'created_at']
    ordering = ['name']
    
    def get_queryset(self):
        """Return displays the user has access to."""
        return Display.objects.filter(
            business__members=self.request.user,
            business__memberships__is_active=True
        ).distinct().select_related('business', 'current_menu', 'paired_by')
    
    def get_serializer_class(self):
        """Return appropriate serializer based on action."""
        if self.action == 'create':
            return DisplayCreateSerializer
        elif self.action == 'list':
            return DisplayCompactSerializer
        elif self.action in ['pair', 'generate_pairing_code']:
            return DisplayPairingSerializer
        elif self.action == 'update_status':
            return DisplayStatusSerializer
        elif self.action == 'assign_menu':
            return DisplayMenuAssignmentCreateSerializer
        return DisplayDetailSerializer
    
    @extend_schema(
        responses={
            200: DisplayPairingSerializer,
            404: StandardErrorSerializer,
            403: StandardErrorSerializer,
        },
        tags=['Displays'],
        summary="Generate pairing code",
        description="Generate a new pairing code and QR code for display setup."
    )
    @action(detail=True, methods=['post'])
    def generate_pairing_code(self, request, pk=None):
        """Generate pairing code and QR code for display."""
        display = self.get_object()
        
        # Check permissions
        if not check_business_permission(request.user, display.business, 
                                       BusinessPermissions.PAIR_DISPLAYS):
            return Response({
                'error': "You don't have permission to pair displays."
            }, status=status.HTTP_403_FORBIDDEN)
        
        serializer = DisplayPairingSerializer(context={'display': display})
        pairing_data = serializer.create({})
        
        return Response(pairing_data)
    
    @extend_schema(
        request=DisplayPairingSerializer,
        responses={
            200: {"description": "Display paired successfully"},
            400: StandardErrorSerializer,
            404: StandardErrorSerializer,
        },
        tags=['Displays'],
        summary="Complete display pairing",
        description="Complete the pairing process using pairing code."
    )
    @action(detail=False, methods=['post'], url_path='pair')
    def pair(self, request):
        """Complete display pairing process."""
        serializer = DisplayPairingSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        pairing_code = serializer.validated_data.get('pairing_code')
        device_info = serializer.validated_data.get('device_info', {})
        
        if not pairing_code:
            return Response({
                'error': 'Pairing code is required.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Find display with this pairing code
        try:
            display = Display.objects.get(pairing_code=pairing_code)
        except Display.DoesNotExist:
            return Response({
                'error': 'Invalid pairing code.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if pairing code is still valid
        if not display.is_pairing_code_valid():
            return Response({
                'error': 'Pairing code has expired.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Update display with device info
        display.paired_by = request.user
        display.paired_at = timezone.now()
        display.status = 'online'
        display.last_seen_at = timezone.now()
        
        # Update device information if provided
        if device_info:
            if 'app_version' in device_info:
                display.app_version = device_info['app_version']
            if 'os_version' in device_info:
                display.os_version = device_info['os_version']
            if 'screen_width' in device_info and 'screen_height' in device_info:
                display.screen_width = device_info['screen_width']
                display.screen_height = device_info['screen_height']
        
        display.save()
        
        # Clear the pairing code
        display.clear_pairing_code()
        
        # Return display details
        response_serializer = DisplayDetailSerializer(display, context={'request': request})
        return Response({
            'message': 'Display paired successfully.',
            'display': response_serializer.data
        })
    
    @extend_schema(
        request=DisplayStatusSerializer,
        responses={
            200: DisplayStatusSerializer,
            404: StandardErrorSerializer,
        },
        tags=['Displays'],
        summary="Update display status",
        description="Update display status and performance metrics."
    )
    @action(detail=True, methods=['patch'])
    def update_status(self, request, pk=None):
        """Update display status and metrics."""
        display = self.get_object()
        
        serializer = DisplayStatusSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        updated_display = serializer.update(display, serializer.validated_data)
        
        response_serializer = DisplayStatusSerializer(updated_display)
        return Response(response_serializer.data)
    
    @extend_schema(
        request=DisplayMenuAssignmentCreateSerializer,
        responses={
            200: DisplayMenuAssignmentSerializer,
            400: StandardErrorSerializer,
            403: StandardErrorSerializer,
        },
        tags=['Displays'],
        summary="Assign menu to display",
        description="Assign a menu to this display."
    )
    @action(detail=True, methods=['post'])
    def assign_menu(self, request, pk=None):
        """Assign a menu to the display."""
        display = self.get_object()
        
        # Check permissions
        if not check_business_permission(request.user, display.business, 
                                       BusinessPermissions.ASSIGN_CONTENT):
            return Response({
                'error': "You don't have permission to assign content to displays."
            }, status=status.HTTP_403_FORBIDDEN)
        
        serializer = DisplayMenuAssignmentCreateSerializer(
            data=request.data,
            context={'display': display, 'request': request}
        )
        serializer.is_valid(raise_exception=True)
        
        assignment = serializer.save()
        
        response_serializer = DisplayMenuAssignmentSerializer(assignment, context={'request': request})
        return Response(response_serializer.data)
    
    @extend_schema(
        responses={
            200: DisplaySessionSerializer(many=True),
            404: StandardErrorSerializer,
        },
        parameters=[
            OpenApiParameter('days', OpenApiTypes.INT, description='Number of days to look back (default: 7)'),
        ],
        tags=['Displays'],
        summary="Get display sessions",
        description="Retrieve session history for this display."
    )
    @action(detail=True, methods=['get'])
    def sessions(self, request, pk=None):
        """Get display session history."""
        display = self.get_object()
        
        days = int(request.query_params.get('days', 7))
        since = timezone.now() - timezone.timedelta(days=days)
        
        sessions = display.sessions.filter(started_at__gte=since).order_by('-started_at')
        
        serializer = DisplaySessionSerializer(sessions, many=True, context={'request': request})
        return Response(serializer.data)
    
    @extend_schema(
        responses={
            200: {"description": "Display restart command sent"},
            404: StandardErrorSerializer,
            403: StandardErrorSerializer,
        },
        tags=['Displays'],
        summary="Restart display",
        description="Send restart command to display device."
    )
    @action(detail=True, methods=['post'])
    def restart(self, request, pk=None):
        """Restart the display device."""
        display = self.get_object()
        
        # Check permissions
        if not check_business_permission(request.user, display.business, 
                                       BusinessPermissions.MANAGE_DISPLAYS):
            return Response({
                'error': "You don't have permission to restart displays."
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Update display status
        display.status = 'updating'
        display.save(update_fields=['status'])
        
        # In a real implementation, this would send a WebSocket message to the display
        # For now, we'll just return success
        
        return Response({
            'message': 'Restart command sent to display.',
            'display_id': str(display.id),
            'timestamp': timezone.now()
        })
    
    @extend_schema(
        responses={
            200: {"type": "object", "properties": {
                "status": {"type": "string"},
                "uptime": {"type": "string"},
                "performance": {"type": "object"},
                "connection": {"type": "object"}
            }},
            404: StandardErrorSerializer,
        },
        tags=['Displays'],
        summary="Get display health status",
        description="Get comprehensive health status for this display."
    )
    @action(detail=True, methods=['get'])
    def health(self, request, pk=None):
        """Get display health status."""
        display = self.get_object()
        
        # Calculate uptime
        uptime_info = {
            'last_seen': display.last_seen_at.isoformat() if display.last_seen_at else None,
            'last_heartbeat': display.last_heartbeat_at.isoformat() if display.last_heartbeat_at else None,
            'is_online': display.is_online(),
            'offline_too_long': display.is_offline_too_long()
        }
        
        # Get recent session info
        recent_sessions = display.sessions.filter(
            started_at__gte=timezone.now() - timezone.timedelta(days=1)
        ).order_by('-started_at')[:5]
        
        session_info = {
            'recent_sessions': recent_sessions.count(),
            'total_uptime_today': sum(s.total_uptime_seconds for s in recent_sessions),
            'recent_errors': sum(s.error_count for s in recent_sessions)
        }
        
        # Performance metrics
        performance_info = display.performance_metrics or {}
        
        # Connection info
        connection_info = {
            'status': display.status,
            'connection_count': display.connection_count,
            'ip_address': display.ip_address,
            'last_error': display.last_error,
            'last_error_at': display.last_error_at.isoformat() if display.last_error_at else None
        }
        
        return Response({
            'display_id': str(display.id),
            'name': display.name,
            'status': display.status,
            'uptime': uptime_info,
            'sessions': session_info,
            'performance': performance_info,
            'connection': connection_info,
            'timestamp': timezone.now().isoformat()
        })


@extend_schema(
    request=DisplayHealthCheckSerializer,
    responses={
        200: {"description": "Health check processed"},
        400: StandardErrorSerializer,
        404: StandardErrorSerializer,
    },
    tags=['Displays'],
    summary="Display health check",
    description="Process health check data from display device."
)
@api_view(['POST'])
@permission_classes([permissions.AllowAny])  # Displays authenticate via device token
def display_health_check(request, display_id):
    """
    T058: GET /api/v1/displays/{id}/status endpoint for health monitoring.
    
    This endpoint receives health check data from display devices.
    """
    try:
        display = Display.objects.get(id=display_id)
    except Display.DoesNotExist:
        return Response({
            'error': 'Display not found.'
        }, status=status.HTTP_404_NOT_FOUND)
    
    # Validate device token (simplified authentication)
    device_token = request.META.get('HTTP_X_DEVICE_TOKEN')
    if not device_token or device_token != display.device_token:
        return Response({
            'error': 'Invalid device token.'
        }, status=status.HTTP_401_UNAUTHORIZED)
    
    # Process health check data
    data = request.data.copy()
    data['display_id'] = display_id
    data['timestamp'] = timezone.now()
    
    serializer = DisplayHealthCheckSerializer(data=data)
    serializer.is_valid(raise_exception=True)
    
    result = serializer.save()
    
    return Response(result)


@extend_schema(
    request={"pairing_code": {"type": "string"}},
    responses={
        200: DisplayDetailSerializer,
        400: StandardErrorSerializer,
        404: StandardErrorSerializer,
    },
    tags=['Displays'],
    summary="Pair display via QR code",
    description="Complete display pairing using QR code data."
)
@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def pair_display(request):
    """
    T056: POST /api/v1/displays/pair endpoint for QR code pairing.
    
    This endpoint handles display pairing via QR code scanning.
    """
    pairing_code = request.data.get('pairing_code')
    
    if not pairing_code:
        return Response({
            'error': 'Pairing code is required.'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Find display with this pairing code
    try:
        display = Display.objects.get(pairing_code=pairing_code.upper())
    except Display.DoesNotExist:
        return Response({
            'error': 'Invalid pairing code.'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Check if pairing code is still valid
    if not display.is_pairing_code_valid():
        return Response({
            'error': 'Pairing code has expired. Please generate a new one.'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Check if user has permission to pair displays for this business
    if not check_business_permission(request.user, display.business, 
                                   BusinessPermissions.PAIR_DISPLAYS):
        return Response({
            'error': "You don't have permission to pair displays for this business."
        }, status=status.HTTP_403_FORBIDDEN)
    
    # Complete pairing
    display.paired_by = request.user
    display.paired_at = timezone.now()
    display.status = 'online'
    display.last_seen_at = timezone.now()
    display.save(update_fields=['paired_by', 'paired_at', 'status', 'last_seen_at'])
    
    # Clear the pairing code
    display.clear_pairing_code()
    
    # Return display details
    serializer = DisplayDetailSerializer(display, context={'request': request})
    
    return Response({
        'message': 'Display paired successfully.',
        'display': serializer.data
    })


class DisplayGroupViewSet(ModelViewSet):
    """
    ViewSet for managing display groups.
    """
    
    permission_classes = [BusinessPermission]
    serializer_class = DisplayGroupSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['is_active']
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'created_at']
    ordering = ['name']
    
    def get_queryset(self):
        """Return display groups the user has access to."""
        return DisplayGroup.objects.filter(
            business__members=self.request.user,
            business__memberships__is_active=True
        ).distinct().select_related('business', 'default_menu', 'created_by')
    
    @extend_schema(
        responses={
            200: DisplayCompactSerializer(many=True),
            404: StandardErrorSerializer,
        },
        tags=['Display Groups'],
        summary="Get displays in group",
        description="Retrieve all displays that belong to this group."
    )
    @action(detail=True, methods=['get'])
    def displays(self, request, pk=None):
        """Get displays in the group."""
        group = self.get_object()
        displays = group.displays.filter(is_active=True)
        
        serializer = DisplayCompactSerializer(displays, many=True, context={'request': request})
        return Response(serializer.data)
    
    @extend_schema(
        request={"menu_id": {"type": "string", "format": "uuid"}},
        responses={
            200: {"description": "Menu assigned to all displays in group"},
            400: StandardErrorSerializer,
            403: StandardErrorSerializer,
        },
        tags=['Display Groups'],
        summary="Assign menu to all displays",
        description="Assign a menu to all displays in this group."
    )
    @action(detail=True, methods=['post'])
    def assign_menu_to_all(self, request, pk=None):
        """Assign menu to all displays in the group."""
        group = self.get_object()
        
        # Check permissions
        if not check_business_permission(request.user, group.business, 
                                       BusinessPermissions.ASSIGN_CONTENT):
            return Response({
                'error': "You don't have permission to assign content to displays."
            }, status=status.HTTP_403_FORBIDDEN)
        
        menu_id = request.data.get('menu_id')
        if not menu_id:
            return Response({
                'error': 'menu_id is required.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            menu = Menu.objects.get(id=menu_id, business=group.business)
        except Menu.DoesNotExist:
            return Response({
                'error': 'Menu not found or does not belong to this business.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Assign menu to all displays in group
        success_count = group.assign_menu_to_all(menu, request.user)
        
        return Response({
            'message': f'Menu assigned to {success_count} displays.',
            'menu_name': menu.name,
            'displays_updated': success_count
        })
    
    @extend_schema(
        responses={
            200: {"description": "Settings applied to all displays in group"},
            403: StandardErrorSerializer,
        },
        tags=['Display Groups'],
        summary="Apply group settings",
        description="Apply group settings to all displays in this group."
    )
    @action(detail=True, methods=['post'])
    def apply_settings(self, request, pk=None):
        """Apply group settings to all displays."""
        group = self.get_object()
        
        # Check permissions
        if not check_business_permission(request.user, group.business, 
                                       BusinessPermissions.MANAGE_DISPLAYS):
            return Response({
                'error': "You don't have permission to manage displays."
            }, status=status.HTTP_403_FORBIDDEN)
        
        updated_count = group.apply_settings_to_all()
        
        return Response({
            'message': f'Settings applied to {updated_count} displays.',
            'displays_updated': updated_count
        })