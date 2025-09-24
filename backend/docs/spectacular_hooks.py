"""
Custom Spectacular hooks for enhanced API documentation.
"""

def custom_preprocessing_hook(endpoints):
    """
    Custom preprocessing hook for API schema generation.
    
    This hook can be used to modify the endpoints before schema generation.
    """
    # Add custom tags based on URL patterns
    for (path, path_regex, method, callback) in endpoints:
        # Add tags based on URL structure
        if '/api/v1/auth/' in path:
            callback.cls.tags = ['Authentication']
        elif '/api/v1/businesses/' in path:
            callback.cls.tags = ['Business Management']
        elif '/api/v1/menus/' in path:
            callback.cls.tags = ['Menu Management']
        elif '/api/v1/displays/' in path:
            callback.cls.tags = ['Display Management']
        elif '/api/v1/media/' in path:
            callback.cls.tags = ['Media Management']
        elif '/api/v1/analytics/' in path:
            callback.cls.tags = ['Analytics']
    
    return endpoints


def custom_postprocessing_hook(result, generator, request, public):
    """
    Custom postprocessing hook for API schema generation.
    
    This hook can be used to modify the generated schema.
    """
    # Add custom examples to schema
    if 'paths' in result:
        for path, methods in result['paths'].items():
            for method, operation in methods.items():
                # Add examples for authentication endpoints
                if '/auth/login' in path and method == 'post':
                    operation['requestBody'] = {
                        'content': {
                            'application/json': {
                                'schema': operation['requestBody']['content']['application/json']['schema'],
                                'examples': {
                                    'manager_login': {
                                        'summary': 'Manager Login',
                                        'value': {
                                            'email': 'manager@restaurant.com',
                                            'password': 'SecurePass123!'
                                        }
                                    },
                                    'owner_login': {
                                        'summary': 'Business Owner Login',
                                        'value': {
                                            'email': 'owner@fastfood.com',
                                            'password': 'OwnerPass456!'
                                        }
                                    }
                                }
                            }
                        }
                    }
                
                # Add examples for business creation
                elif '/businesses' in path and method == 'post':
                    operation['requestBody'] = {
                        'content': {
                            'application/json': {
                                'schema': operation['requestBody']['content']['application/json']['schema'],
                                'examples': {
                                    'fast_food': {
                                        'summary': 'Fast Food Restaurant',
                                        'value': {
                                            'name': 'Quick Burger',
                                            'business_type': 'fast_food',
                                            'description': 'Fast food restaurant specializing in burgers and fries',
                                            'email': 'contact@quickburger.com',
                                            'phone_number': '+1-555-0123',
                                            'address_line_1': '123 Main Street',
                                            'city': 'Anytown',
                                            'state_province': 'CA',
                                            'postal_code': '90210',
                                            'country': 'United States'
                                        }
                                    },
                                    'cafe': {
                                        'summary': 'Coffee Shop',
                                        'value': {
                                            'name': 'Central Perk Cafe',
                                            'business_type': 'cafe',
                                            'description': 'Cozy neighborhood coffee shop with fresh pastries',
                                            'email': 'hello@centralperk.com',
                                            'phone_number': '+1-555-0456',
                                            'address_line_1': '456 Coffee Ave',
                                            'city': 'Downtown',
                                            'state_province': 'NY',
                                            'postal_code': '10001',
                                            'country': 'United States'
                                        }
                                    }
                                }
                            }
                        }
                    }
    
    # Add security schemes
    if 'components' not in result:
        result['components'] = {}
    
    result['components']['securitySchemes'] = {
        'JWTAuth': {
            'type': 'http',
            'scheme': 'bearer',
            'bearerFormat': 'JWT',
            'description': 'JWT token for web and mobile authentication'
        },
        'DisplayToken': {
            'type': 'apiKey',
            'in': 'header',
            'name': 'X-Display-Token',
            'description': 'Token for Android TV display authentication'
        },
        'APIKey': {
            'type': 'apiKey',
            'in': 'header',
            'name': 'X-API-Key',
            'description': 'API key for service-to-service authentication'
        },
        'TenantID': {
            'type': 'apiKey',
            'in': 'header',
            'name': 'X-Tenant-ID',
            'description': 'Tenant identifier for multi-tenant operations'
        }
    }
    
    # Add custom response examples
    if 'components' not in result:
        result['components'] = {}
    if 'examples' not in result['components']:
        result['components']['examples'] = {}
    
    result['components']['examples'].update({
        'ValidationError': {
            'summary': 'Validation Error Response',
            'value': {
                'error': 'ValidationError',
                'message': 'Invalid input data',
                'details': {
                    'email': ['This field is required.'],
                    'password': ['Password must be at least 8 characters.']
                },
                'timestamp': '2023-10-06T12:00:00Z'
            }
        },
        'AuthenticationError': {
            'summary': 'Authentication Error Response',
            'value': {
                'error': 'AuthenticationFailed',
                'message': 'Invalid credentials',
                'timestamp': '2023-10-06T12:00:00Z'
            }
        },
        'PermissionError': {
            'summary': 'Permission Denied Response',
            'value': {
                'error': 'PermissionDenied',
                'message': 'You do not have permission to perform this action',
                'timestamp': '2023-10-06T12:00:00Z'
            }
        }
    })
    
    return result