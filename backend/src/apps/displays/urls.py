"""
URL configuration for displays app.
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register(r'displays', views.DisplayViewSet, basename='display')
router.register(r'display-groups', views.DisplayGroupViewSet, basename='displaygroup')

app_name = 'displays'

urlpatterns = [
    # Business-specific display endpoints
    path('businesses/<uuid:business_id>/displays/', 
         views.BusinessDisplayListView.as_view(), 
         name='business-displays'),
    
    # Display pairing endpoints
    path('displays/pair/', 
         views.pair_display, 
         name='pair-display'),
    
    # Display health check endpoint (for display devices)
    path('displays/<uuid:display_id>/health/', 
         views.display_health_check, 
         name='display-health-check'),
    
    # Router URLs for ViewSets
    path('', include(router.urls)),
]