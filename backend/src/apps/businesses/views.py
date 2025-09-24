# Business views for DisplayDeck API

from rest_framework import status, generics, permissions, filters
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.response import Response
from rest_framework.viewsets import ModelViewSet
from rest_framework.views import APIView
from django.contrib.auth import get_user_model
from django.shortcuts import get_object_or_404
from django.db.models import Q, Count
from django_filters.rest_framework import DjangoFilterBackend
from drf_spectacular.utils import extend_schema, OpenApiResponse, OpenApiParameter
from drf_spectacular.openapi import OpenApiTypes

from .models import Business, BusinessMember, BusinessInvitation
from .serializers import (
    BusinessSerializer,
    BusinessCreateSerializer,
    BusinessUpdateSerializer,
    BusinessListSerializer,
    BusinessMemberSerializer,
    BusinessMemberUpdateSerializer,
    BusinessInvitationSerializer,
    BusinessInvitationCreateSerializer,
    BusinessStatsSerializer,
    BusinessTransferOwnershipSerializer
)
from apps.authentication.serializers import StandardErrorSerializer, ValidationErrorSerializer
from common.permissions import BusinessPermission

User = get_user_model()


@extend_schema(
    responses={
        200: BusinessListSerializer(many=True),
        401: StandardErrorSerializer,
    },
    parameters=[
        OpenApiParameter('search', OpenApiTypes.STR, description='Search businesses by name'),
        OpenApiParameter('business_type', OpenApiTypes.STR, description='Filter by business type'),
        OpenApiParameter('is_active', OpenApiTypes.BOOL, description='Filter by active status'),
    ],
    tags=['Businesses'],
    summary="List user's businesses",
    description="Retrieve all businesses that the authenticated user has access to."
)
class BusinessListView(generics.ListAPIView):
    """
    API endpoint to list businesses for the authenticated user.
    """
    serializer_class = BusinessListSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['business_type', 'is_active']
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'created_at', 'business_type']
    ordering = ['-created_at']
    
    def get_queryset(self):
        """Return businesses where user is a member."""
        return Business.objects.filter(
            members=self.request.user,
            memberships__is_active=True
        ).distinct().select_related('owner').prefetch_related('displays', 'menus')


@extend_schema(
    request=BusinessCreateSerializer,
    responses={
        201: BusinessSerializer,
        400: ValidationErrorSerializer,
        401: StandardErrorSerializer,
    },
    tags=['Businesses'],
    summary="Create new business",
    description="Create a new business with the authenticated user as owner."
)
class BusinessCreateView(generics.CreateAPIView):
    """
    API endpoint to create a new business.
    """
    serializer_class = BusinessCreateSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def perform_create(self, serializer):
        """Create business with current user as owner."""
        business = serializer.save()
        return business
    
    def create(self, request, *args, **kwargs):
        """Create business and return full business data."""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        business = self.perform_create(serializer)
        
        # Return full business data
        response_serializer = BusinessSerializer(business, context={'request': request})
        
        return Response(response_serializer.data, status=status.HTTP_201_CREATED)


class BusinessViewSet(ModelViewSet):
    """
    ViewSet for business CRUD operations.
    """
    permission_classes = [BusinessPermission]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['business_type', 'is_active']
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'created_at']
    ordering = ['name']
    
    def get_queryset(self):
        """Return businesses where user is a member."""
        return Business.objects.filter(
            members=self.request.user,
            memberships__is_active=True
        ).distinct().select_related('owner')
    
    def get_serializer_class(self):
        """Return appropriate serializer based on action."""
        if self.action == 'create':
            return BusinessCreateSerializer
        elif self.action in ['update', 'partial_update']:
            return BusinessUpdateSerializer
        elif self.action == 'list':
            return BusinessListSerializer
        return BusinessSerializer
    
    @extend_schema(
        responses={
            200: BusinessStatsSerializer,
            404: StandardErrorSerializer,
        },
        tags=['Businesses'],
        summary="Get business statistics",
        description="Retrieve statistics and analytics for a specific business."
    )
    @action(detail=True, methods=['get'])
    def stats(self, request, pk=None):
        """Get business statistics."""
        business = self.get_object()
        
        stats = {
            'total_menus': business.menus.count(),
            'total_menu_items': sum(menu.total_items for menu in business.menus.all()),
            'total_displays': business.displays.count(),
            'active_displays': business.displays.filter(is_active=True).count(),
            'total_members': business.members.count(),
            'active_members': business.members.filter(
                business_memberships__is_active=True
            ).count(),
            'plan_info': {
                'current_plan': business.plan,
                'plan_display_name': business.get_plan_display_name(),
                'expires_at': business.plan_expires_at,
            },
            'usage_limits': {
                'has_reached_display_limit': business.has_reached_display_limit(),
                'has_reached_member_limit': business.has_reached_member_limit(),
            }
        }
        
        serializer = BusinessStatsSerializer(stats)
        return Response(serializer.data)
    
    @extend_schema(
        request=BusinessTransferOwnershipSerializer,
        responses={
            200: BusinessSerializer,
            400: ValidationErrorSerializer,
            403: StandardErrorSerializer,
        },
        tags=['Businesses'],
        summary="Transfer business ownership",
        description="Transfer ownership of the business to another member."
    )
    @action(detail=True, methods=['post'])
    def transfer_ownership(self, request, pk=None):
        """Transfer business ownership."""
        business = self.get_object()
        
        # Only current owner can transfer ownership
        if business.owner != request.user:
            return Response({
                'error': 'Only the current owner can transfer ownership.'
            }, status=status.HTTP_403_FORBIDDEN)
        
        serializer = BusinessTransferOwnershipSerializer(
            data=request.data,
            context={'business': business, 'request': request}
        )
        serializer.is_valid(raise_exception=True)
        
        updated_business = serializer.save()
        
        response_serializer = BusinessSerializer(updated_business, context={'request': request})
        return Response(response_serializer.data)
    
    @extend_schema(
        responses={
            200: BusinessMemberSerializer(many=True),
            404: StandardErrorSerializer,
        },
        tags=['Businesses'],
        summary="List business members",
        description="Retrieve all members of a specific business."
    )
    @action(detail=True, methods=['get'])
    def members(self, request, pk=None):
        """Get business members."""
        business = self.get_object()
        members = BusinessMember.objects.filter(
            business=business,
            is_active=True
        ).select_related('user', 'invited_by').order_by('role', 'joined_at')
        
        serializer = BusinessMemberSerializer(members, many=True, context={'request': request})
        return Response(serializer.data)
    
    @extend_schema(
        request=BusinessInvitationCreateSerializer,
        responses={
            201: BusinessInvitationSerializer,
            400: ValidationErrorSerializer,
        },
        tags=['Businesses'],
        summary="Invite user to business",
        description="Send an invitation to join the business."
    )
    @action(detail=True, methods=['post'])
    def invite(self, request, pk=None):
        """Invite a user to join the business."""
        business = self.get_object()
        
        # Check if business has reached member limit
        if business.has_reached_member_limit():
            return Response({
                'error': 'Business has reached the maximum number of members for the current plan.'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        serializer = BusinessInvitationCreateSerializer(
            data=request.data,
            context={'business': business, 'request': request}
        )
        serializer.is_valid(raise_exception=True)
        
        invitation = serializer.save()
        
        response_serializer = BusinessInvitationSerializer(invitation, context={'request': request})
        return Response(response_serializer.data, status=status.HTTP_201_CREATED)
    
    @extend_schema(
        responses={
            200: BusinessInvitationSerializer(many=True),
            404: StandardErrorSerializer,
        },
        tags=['Businesses'],
        summary="List business invitations",
        description="Retrieve all pending invitations for a business."
    )
    @action(detail=True, methods=['get'])
    def invitations(self, request, pk=None):
        """Get business invitations."""
        business = self.get_object()
        invitations = BusinessInvitation.objects.filter(
            business=business
        ).select_related('invited_by', 'accepted_by').order_by('-created_at')
        
        serializer = BusinessInvitationSerializer(invitations, many=True, context={'request': request})
        return Response(serializer.data)
    
    @extend_schema(
        responses={
            200: {"description": "Member removed successfully"},
            404: StandardErrorSerializer,
            403: StandardErrorSerializer,
        },
        tags=['Businesses'],
        summary="Remove business member",
        description="Remove a member from the business."
    )
    @action(detail=True, methods=['delete'], url_path='members/(?P<user_id>[^/.]+)')
    def remove_member(self, request, pk=None, user_id=None):
        """Remove a member from the business."""
        business = self.get_object()
        
        try:
            member = BusinessMember.objects.get(
                business=business,
                user_id=user_id,
                is_active=True
            )
        except BusinessMember.DoesNotExist:
            return Response({
                'error': 'Member not found.'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Cannot remove owner
        if member.user == business.owner:
            return Response({
                'error': 'Cannot remove business owner.'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Deactivate membership
        member.is_active = False
        member.save(update_fields=['is_active'])
        
        return Response({
            'message': 'Member removed successfully.'
        })
    
    @extend_schema(
        request=BusinessMemberUpdateSerializer,
        responses={
            200: BusinessMemberSerializer,
            404: StandardErrorSerializer,
        },
        tags=['Businesses'],
        summary="Update business member",
        description="Update a member's role and permissions."
    )
    @action(detail=True, methods=['patch'], url_path='members/(?P<user_id>[^/.]+)')
    def update_member(self, request, pk=None, user_id=None):
        """Update a business member."""
        business = self.get_object()
        
        try:
            member = BusinessMember.objects.get(
                business=business,
                user_id=user_id,
                is_active=True
            )
        except BusinessMember.DoesNotExist:
            return Response({
                'error': 'Member not found.'
            }, status=status.HTTP_404_NOT_FOUND)
        
        serializer = BusinessMemberUpdateSerializer(
            member,
            data=request.data,
            partial=True,
            context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        
        response_serializer = BusinessMemberSerializer(member, context={'request': request})
        return Response(response_serializer.data)


@extend_schema(
    responses={
        200: {"description": "Invitation accepted successfully"},
        400: StandardErrorSerializer,
        404: StandardErrorSerializer,
    },
    tags=['Businesses'],
    summary="Accept business invitation",
    description="Accept a business invitation using the invitation token."
)
@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def accept_invitation(request, token):
    """Accept a business invitation."""
    try:
        invitation = BusinessInvitation.objects.get(
            token=token,
            status='pending'
        )
    except BusinessInvitation.DoesNotExist:
        return Response({
            'error': 'Invalid or expired invitation.'
        }, status=status.HTTP_404_NOT_FOUND)
    
    if not invitation.can_be_accepted():
        return Response({
            'error': 'This invitation can no longer be accepted.'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Check if user email matches invitation
    if request.user.email.lower() != invitation.email.lower():
        return Response({
            'error': 'This invitation is for a different email address.'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        membership = invitation.accept(request.user)
        
        # Return business information
        business_serializer = BusinessSerializer(
            membership.business,
            context={'request': request}
        )
        
        return Response({
            'message': 'Invitation accepted successfully.',
            'business': business_serializer.data
        })
        
    except Exception as e:
        return Response({
            'error': str(e)
        }, status=status.HTTP_400_BAD_REQUEST)


@extend_schema(
    responses={
        200: {"description": "Invitation declined successfully"},
        404: StandardErrorSerializer,
    },
    tags=['Businesses'],
    summary="Decline business invitation",
    description="Decline a business invitation using the invitation token."
)
@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def decline_invitation(request, token):
    """Decline a business invitation."""
    try:
        invitation = BusinessInvitation.objects.get(
            token=token,
            status='pending'
        )
    except BusinessInvitation.DoesNotExist:
        return Response({
            'error': 'Invalid or expired invitation.'
        }, status=status.HTTP_404_NOT_FOUND)
    
    invitation.decline()
    
    return Response({
        'message': 'Invitation declined successfully.'
    })


@extend_schema(
    responses={
        200: {"description": "Invitation cancelled successfully"},
        404: StandardErrorSerializer,
        403: StandardErrorSerializer,
    },
    tags=['Businesses'],
    summary="Cancel business invitation",
    description="Cancel a pending business invitation."
)
@api_view(['DELETE'])
@permission_classes([permissions.IsAuthenticated])
def cancel_invitation(request, invitation_id):
    """Cancel a business invitation."""
    try:
        invitation = BusinessInvitation.objects.get(
            id=invitation_id,
            status='pending'
        )
    except BusinessInvitation.DoesNotExist:
        return Response({
            'error': 'Invitation not found.'
        }, status=status.HTTP_404_NOT_FOUND)
    
    # Check permissions
    try:
        membership = BusinessMember.objects.get(
            business=invitation.business,
            user=request.user,
            is_active=True
        )
        if not membership.has_permission('manage_members'):
            return Response({
                'error': 'Permission denied.'
            }, status=status.HTTP_403_FORBIDDEN)
    except BusinessMember.DoesNotExist:
        return Response({
            'error': 'Permission denied.'
        }, status=status.HTTP_403_FORBIDDEN)
    
    invitation.cancel()
    
    return Response({
        'message': 'Invitation cancelled successfully.'
    })


@extend_schema(
    responses={
        200: BusinessInvitationSerializer,
        404: StandardErrorSerializer,
    },
    tags=['Businesses'],
    summary="Get invitation details",
    description="Get details of a business invitation using the token."
)
@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def invitation_details(request, token):
    """Get invitation details."""
    try:
        invitation = BusinessInvitation.objects.get(token=token)
    except BusinessInvitation.DoesNotExist:
        return Response({
            'error': 'Invalid invitation token.'
        }, status=status.HTTP_404_NOT_FOUND)
    
    serializer = BusinessInvitationSerializer(invitation, context={'request': request})
    return Response(serializer.data)