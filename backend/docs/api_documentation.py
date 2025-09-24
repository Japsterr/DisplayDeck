"""
Django settings for API documentation with Swagger UI
Configures drf-spectacular for comprehensive API documentation
"""

from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularRedocView,
    SpectacularSwaggerView,
)
from django.urls import path

# API Documentation URLs
api_docs_urlpatterns = [
    # OpenAPI 3 schema
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    
    # Swagger UI
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    
    # ReDoc
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
]

# Spectacular settings for API documentation
SPECTACULAR_SETTINGS = {
    'TITLE': 'DisplayDeck API',
    'DESCRIPTION': '''
    # DisplayDeck Digital Menu Management API

    A comprehensive REST API for managing digital menus, businesses, displays, and real-time synchronization.

    ## Features

    - **Multi-tenant Business Management**: Manage multiple restaurant locations
    - **Dynamic Menu System**: Create, update, and organize menus with categories and items  
    - **Display Device Management**: Register and control display devices via QR code pairing
    - **Real-time Synchronization**: WebSocket-based live updates across all platforms
    - **User Authentication**: JWT-based authentication with role-based permissions
    - **Media Management**: Upload and optimize images for menu items

    ## Authentication

    This API uses JWT (JSON Web Token) authentication. Include the access token in the Authorization header:

    ```
    Authorization: Bearer <your_access_token>
    ```

    ### Getting Started

    1. **Register a new account**: `POST /api/auth/register/`
    2. **Login to get tokens**: `POST /api/auth/login/`
    3. **Create a business**: `POST /api/businesses/`
    4. **Create menus and items**: `POST /api/businesses/{id}/menus/`
    5. **Register displays**: `POST /api/displays/pair/`

    ## Rate Limiting

    API requests are rate-limited to prevent abuse:
    - **Authentication endpoints**: 5 requests per minute
    - **General API endpoints**: 100 requests per minute
    - **Media uploads**: 10 requests per minute

    ## Error Handling

    The API uses standard HTTP status codes and returns structured error responses:

    ```json
    {
        "error": "Error type",
        "message": "Human readable error message",
        "details": {
            "field": ["Specific field error"]
        }
    }
    ```

    ## Pagination

    List endpoints support cursor-based pagination:

    ```json
    {
        "count": 150,
        "next": "http://api.example.com/accounts/?cursor=cD0yMDIzLTA5LTE%3D",
        "previous": null,
        "results": [...]
    }
    ```

    ## WebSocket Real-time Updates

    Connect to WebSocket endpoints for real-time updates:

    - **Admin updates**: `ws://api.example.com/ws/admin/{business_id}/`
    - **Display updates**: `ws://api.example.com/ws/display/{display_id}/`

    ## Data Models

    ### Business Account
    - Represents a restaurant or food service business
    - Contains location, contact, and branding information
    - Supports multi-location businesses

    ### Menu System
    - **Menu**: Container for categories and items (e.g., "Lunch Menu", "Dinner Menu")
    - **Category**: Groups related items (e.g., "Appetizers", "Main Courses")
    - **Item**: Individual menu items with pricing and descriptions

    ### Display Devices
    - Physical display devices (tablets, TVs, kiosks)
    - Paired via QR code for security
    - Support offline caching and automatic updates

    ### User Roles
    - **Owner**: Full business management access
    - **Manager**: Menu and display management
    - **Staff**: Limited menu viewing and updates

    ''',
    'VERSION': '1.0.0',
    'SERVE_INCLUDE_SCHEMA': False,
    
    # Security schemes
    'AUTHENTICATION_WHITELIST': [
        'rest_framework.authentication.SessionAuthentication',
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    
    # Component schemas
    'COMPONENT_SPLIT_REQUEST': True,
    'COMPONENT_NO_READ_ONLY_REQUIRED': True,
    
    # Tags for grouping endpoints
    'TAGS': [
        {
            'name': 'Authentication',
            'description': 'User authentication and token management'
        },
        {
            'name': 'Businesses',
            'description': 'Business account management and multi-tenancy'
        },
        {
            'name': 'Menus',
            'description': 'Menu, category, and item management'
        },
        {
            'name': 'Displays',
            'description': 'Display device management and pairing'
        },
        {
            'name': 'Media',
            'description': 'Image and asset management'
        },
        {
            'name': 'Analytics',
            'description': 'Usage analytics and reporting'
        },
        {
            'name': 'Performance',
            'description': 'System performance monitoring and optimization'
        }
    ],
    
    # Server information
    'SERVERS': [
        {
            'url': 'http://localhost:8000',
            'description': 'Development server'
        },
        {
            'url': 'https://api.displaydeck.com',
            'description': 'Production server'
        },
        {
            'url': 'https://staging-api.displaydeck.com',
            'description': 'Staging server'
        }
    ],
    
    # External documentation
    'EXTERNAL_DOCS': {
        'description': 'DisplayDeck Documentation',
        'url': 'https://docs.displaydeck.com/'
    },
    
    # Schema customizations
    'SCHEMA_PATH_PREFIX': '/api/',
    'SCHEMA_PATH_PREFIX_TRIM': True,
    'SERVE_PERMISSIONS': ['rest_framework.permissions.IsAuthenticated'],
    'SERVE_AUTHENTICATION': ['rest_framework_simplejwt.authentication.JWTAuthentication'],
    
    # Extensions
    'EXTENSIONS_INFO': {
        'x-logo': {
            'url': 'https://displaydeck.com/logo.png',
            'altText': 'DisplayDeck Logo'
        }
    },
    
    # Preprocessing hooks
    'PREPROCESSING_HOOKS': [
        'backend.docs.spectacular.preprocessing_hooks.custom_preprocessing_hook',
    ],
    
    # Post-processing hooks  
    'POSTPROCESSING_HOOKS': [
        'backend.docs.spectacular.postprocessing_hooks.custom_postprocessing_hook',
    ],
}

# Custom schema view with additional context
class DisplayDeckAPISchemaView(SpectacularAPIView):
    """Custom schema view with DisplayDeck-specific enhancements."""
    
    def get(self, request, *args, **kwargs):
        response = super().get(request, *args, **kwargs)
        
        # Add custom headers
        response['X-API-Version'] = '1.0.0'
        response['X-Documentation-URL'] = 'https://docs.displaydeck.com/'
        
        return response


# Custom Swagger view with branding
class DisplayDeckSwaggerView(SpectacularSwaggerView):
    """Custom Swagger UI with DisplayDeck branding."""
    
    template_name = 'docs/swagger-ui.html'
    
    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context.update({
            'title': 'DisplayDeck API Documentation',
            'brand_name': 'DisplayDeck',
            'brand_url': 'https://displaydeck.com',
            'support_email': 'support@displaydeck.com'
        })
        return context


# Example usage in serializers for better documentation
def documented_serializer_method(func):
    """
    Decorator to add documentation to serializer methods.
    
    Usage:
    @documented_serializer_method
    def get_full_address(self, obj):
        '''Returns the complete formatted address.'''
        return f"{obj.address}, {obj.city}, {obj.state} {obj.zip_code}"
    """
    return func


# Example schema extensions for common patterns
COMMON_SCHEMA_EXTENSIONS = {
    'pagination': {
        'type': 'object',
        'properties': {
            'count': {
                'type': 'integer',
                'description': 'Total number of items'
            },
            'next': {
                'type': 'string',
                'nullable': True,
                'description': 'URL to next page'
            },
            'previous': {
                'type': 'string', 
                'nullable': True,
                'description': 'URL to previous page'
            },
            'results': {
                'type': 'array',
                'description': 'Array of results'
            }
        }
    },
    'error_response': {
        'type': 'object',
        'properties': {
            'error': {
                'type': 'string',
                'description': 'Error type identifier'
            },
            'message': {
                'type': 'string',
                'description': 'Human readable error message'
            },
            'details': {
                'type': 'object',
                'description': 'Detailed field-specific errors',
                'additionalProperties': {
                    'type': 'array',
                    'items': {'type': 'string'}
                }
            }
        }
    },
    'success_response': {
        'type': 'object',
        'properties': {
            'success': {
                'type': 'boolean',
                'description': 'Operation success status'
            },
            'message': {
                'type': 'string',
                'description': 'Success message'
            },
            'data': {
                'type': 'object',
                'description': 'Response data'
            }
        }
    }
}