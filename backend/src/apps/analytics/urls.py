# Analytics URL patterns - basic placeholder

from django.urls import path
from .views import AnalyticsPlaceholderView

app_name = 'analytics'

urlpatterns = [
    path('', AnalyticsPlaceholderView.as_view(), name='analytics-placeholder'),
]