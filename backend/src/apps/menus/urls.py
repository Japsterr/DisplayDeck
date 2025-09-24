# Menu URL patterns

from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    BusinessMenuListView,
    MenuViewSet,
    MenuItemViewSet,
    update_item_price
)

app_name = 'menus'

# Create router for ViewSets
router = DefaultRouter()
router.register(r'', MenuViewSet, basename='menu')
router.register(r'items', MenuItemViewSet, basename='menuitem')

urlpatterns = [
    # Business-specific menu endpoints
    path('businesses/<uuid:business_id>/menus/', BusinessMenuListView.as_view(), name='business-menus'),
    
    # Menu ViewSet routes (includes CRUD, with_items, publish, clone, etc.)
    path('menus/', include(router.urls)),
    
    # Real-time price update endpoint (T052)
    path('menus/<uuid:menu_id>/items/<uuid:item_id>/price/', update_item_price, name='update-item-price'),
]