# Businesses URL patterns

from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    BusinessListView,
    BusinessCreateView,
    BusinessViewSet,
    accept_invitation,
    decline_invitation,
    cancel_invitation,
    invitation_details,
)

app_name = 'businesses'

# Create router for ViewSet
router = DefaultRouter()
router.register(r'manage', BusinessViewSet, basename='business-manage')

urlpatterns = [
    # Business CRUD operations
    path('', BusinessListView.as_view(), name='business-list'),
    path('create/', BusinessCreateView.as_view(), name='business-create'),
    
    # ViewSet routes (includes detail views, stats, members, etc.)
    path('', include(router.urls)),
    
    # Invitation management
    path('invitations/<str:token>/', invitation_details, name='invitation-details'),
    path('invitations/<str:token>/accept/', accept_invitation, name='accept-invitation'),
    path('invitations/<str:token>/decline/', decline_invitation, name='decline-invitation'),
    path('invitations/<uuid:invitation_id>/cancel/', cancel_invitation, name='cancel-invitation'),
]