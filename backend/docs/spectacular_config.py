"""
Enhanced DRF Spectacular configuration for comprehensive API documentation.
"""

from django.urls import path, include
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularRedocView,
    SpectacularSwaggerView,
)

# Add to your main urls.py
api_docs_urlpatterns = [
    # API schema endpoints
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    
    # Interactive API documentation
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
]

# Enhanced settings for DRF Spectacular
SPECTACULAR_SETTINGS = {
    'TITLE': 'DisplayDeck API',
    'DESCRIPTION': '''
    # DisplayDeck Digital Menu Management System API

    DisplayDeck is a comprehensive digital menu management system designed for fast food restaurants and cafes. 
    This API provides endpoints for managing businesses, menus, display devices, and real-time communication.

    ## Authentication

    The API supports multiple authentication methods:

    ### JWT Bearer Token (Web & Mobile)
    ```
    Authorization: Bearer <your-jwt-token>
    ```

    ### Display Device Token (Android TV)
    ```
    X-Display-Token: <your-display-token>
    ```

    ### API Key (Service-to-Service)
    ```
    X-API-Key: <your-api-key>
    ```

    ## Multi-Tenancy

    The API is multi-tenant aware. Specify tenant context using:

    ### Subdomain
    ```
    https://your-business.displaydeck.com/api/v1/
    ```

    ### Custom Header
    ```
    X-Tenant-ID: <business-id-or-slug>
    ```

    ## Rate Limiting

    API requests are rate limited:
    - Authenticated users: 1000 requests/hour
    - Anonymous users: 100 requests/hour
    - Display devices: 10000 requests/hour

    ## Pagination

    List endpoints use cursor-based pagination:
    ```json
    {
        "count": 150,
        "next": "http://api.example.org/accounts/?cursor=cD0yMDIzLTEwLTA2",
        "previous": null,
        "results": [...]
    }
    ```

    ## Error Handling

    The API uses standard HTTP status codes and returns detailed error information:

    ```json
    {
        "error": "ValidationError",
        "message": "Invalid input data",
        "details": {
            "email": ["This field is required."],
            "password": ["Password must be at least 8 characters."]
        },
        "timestamp": "2023-10-06T12:00:00Z"
    }
    ```

    ## WebSocket Endpoints

    Real-time communication is available via WebSocket:

    - Admin connections: `wss://your-domain/ws/admin/<business-id>/`
    - Display connections: `wss://your-domain/ws/displays/<display-id>/`

    ## Supported Platforms

    - **Web Dashboard**: Full administrative interface
    - **Mobile App**: Business management and display control
    - **Android TV**: Display client for showing menus
    ''',
    'VERSION': '1.0.0',
    'SERVE_INCLUDE_SCHEMA': False,
    'COMPONENT_SPLIT_REQUEST': True,
    'COMPONENT_NO_READ_ONLY_REQUIRED': True,
    
    # External documentation
    'EXTERNAL_DOCS': {
        'description': 'Find out more about DisplayDeck',
        'url': 'https://displaydeck.com/docs',
    },
    
    # Contact information
    'CONTACT': {
        'name': 'DisplayDeck Support',
        'email': 'support@displaydeck.com',
        'url': 'https://displaydeck.com/support',
    },
    
    # License information
    'LICENSE': {
        'name': 'MIT License',
        'url': 'https://opensource.org/licenses/MIT',
    },
    
    # Server information
    'SERVERS': [
        {
            'url': 'https://api.displaydeck.com/api/v1',
            'description': 'Production server'
        },
        {
            'url': 'https://staging-api.displaydeck.com/api/v1',
            'description': 'Staging server'
        },
        {
            'url': 'http://localhost:8000/api/v1',
            'description': 'Development server'
        }
    ],
    
    # Authentication schemes
    'AUTHENTICATION_WHITELIST': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
        'apps.authentication.middleware.CrossPlatformAuthMiddleware',
    ],
    
    # Custom extensions
    'EXTENSIONS_INFO': {
        'x-logo': {
            'url': 'https://displaydeck.com/logo.png',
            'altText': 'DisplayDeck Logo'
        }
    },
    
    # Schema customization
    'SCHEMA_PATH_PREFIX': '/api/v1',
    'SCHEMA_PATH_PREFIX_TRIM': True,
    'SERVE_PERMISSIONS': ['rest_framework.permissions.AllowAny'],
    'SERVE_AUTHENTICATION': [],
    
    # Documentation enhancements
    'SWAGGER_UI_SETTINGS': {
        'deepLinking': True,
        'persistAuthorization': True,
        'displayOperationId': True,
        'docExpansion': 'none',
        'filter': True,
        'showExtensions': True,
        'showCommonExtensions': True,
    },
    
    # Redoc settings
    'REDOC_UI_SETTINGS': {
        'hideDownloadButton': False,
        'hideHostname': False,
        'hideLoading': False,
        'hideSchemaPattern': True,
        'scrollYOffset': 0,
        'theme': {
            'colors': {
                'primary': {
                    'main': '#3b82f6'
                }
            },
            'typography': {
                'fontSize': '14px',
                'lineHeight': '1.5em',
                'code': {
                    'fontSize': '13px'
                }
            }
        }
    },
    
    # Custom preprocessing
    'PREPROCESSING_HOOKS': [
        'backend.docs.spectacular_hooks.custom_preprocessing_hook',
    ],
    
    # Custom postprocessing
    'POSTPROCESSING_HOOKS': [
        'backend.docs.spectacular_hooks.custom_postprocessing_hook',
    ],
}