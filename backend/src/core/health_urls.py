# Health check URLs for DisplayDeck

from django.urls import path
from core.health import (
    health_check_view,
    health_check_simple,
    health_check_detailed,
    liveness_probe,
    readiness_probe
)

urlpatterns = [
    # Main health check endpoint
    path('', health_check_view, name='health_check'),
    
    # Simple health check (for load balancers)
    path('simple/', health_check_simple, name='health_simple'),
    
    # Detailed health check (for monitoring systems)
    path('detailed/', health_check_detailed, name='health_detailed'),
    
    # Kubernetes probes
    path('liveness/', liveness_probe, name='health_liveness'),
    path('readiness/', readiness_probe, name='health_readiness'),
]