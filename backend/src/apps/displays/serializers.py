"""
Display serializers for DisplayDeck API.

Provides serialization for display devices, pairing logic, and display management.
Includes comprehensive display information and status tracking.
"""

from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.utils import timezone
from typing import Dict, List, Optional
import qrcode
import io
import base64

from .models import Display, DisplayGroup, DisplayMenuAssignment, DisplaySession
from apps.menus.models import Menu
from apps.businesses.models import Business
from common.permissions import BusinessPermissions, check_business_permission

User = get_user_model()


class DisplayCompactSerializer(serializers.ModelSerializer):
    """
    Compact serializer for displays - used in lists and references.
    """
    
    business_name = serializers.CharField(source='business.name', read_only=True)
    is_online = serializers.SerializerMethodField()
    current_menu_name = serializers.CharField(source='current_menu.name', read_only=True)
    resolution_string = serializers.SerializerMethodField()
    uptime_status = serializers.SerializerMethodField()
    
    class Meta:
        model = Display
        fields = [
            'id', 'name', 'location', 'device_type', 'orientation', 
            'status', 'is_active', 'is_online', 'business_name',
            'current_menu_name', 'resolution_string', 'uptime_status',
            'last_seen_at', 'created_at'
        ]
        read_only_fields = [
            'id', 'is_online', 'business_name', 'current_menu_name', 
            'resolution_string', 'uptime_status', 'created_at'
        ]
    
    def get_is_online(self, obj) -> bool:
        """Check if display is currently online."""
        return obj.is_online()
    
    def get_resolution_string(self, obj) -> Optional[str]:
        """Get display resolution as string."""
        return obj.get_current_resolution_string()
    
    def get_uptime_status(self, obj) -> str:
        """Get uptime status description."""
        if obj.is_online():
            return "Online"
        elif obj.is_offline_too_long():
            return "Offline (Long)"
        else:
            return "Recently Offline"


class DisplayDetailSerializer(serializers.ModelSerializer):
    """
    Detailed serializer for displays with full information.
    
    Includes all display details, performance metrics, and management options.
    """
    
    business_name = serializers.CharField(source='business.name', read_only=True)
    business_id = serializers.UUIDField(source='business.id', read_only=True)
    current_menu_name = serializers.CharField(source='current_menu.name', read_only=True)
    current_menu_id = serializers.UUIDField(source='current_menu.id', read_only=True)
    paired_by_name = serializers.CharField(source='paired_by.get_full_name', read_only=True)
    
    # Status and connectivity
    is_online = serializers.SerializerMethodField()
    is_pairing_active = serializers.SerializerMethodField()
    resolution_string = serializers.SerializerMethodField()
    aspect_ratio = serializers.SerializerMethodField()
    uptime_percentage = serializers.SerializerMethodField()
    
    # Performance metrics
    performance_summary = serializers.SerializerMethodField()
    connection_health = serializers.SerializerMethodField()
    
    class Meta:
        model = Display
        fields = [
            'id', 'name', 'location', 'device_type', 'device_model',
            'screen_width', 'screen_height', 'screen_size_inches',
            'orientation', 'current_menu_name', 'current_menu_id',
            'settings', 'status', 'is_active', 'is_online',
            'ip_address', 'mac_address', 'app_version', 'os_version',
            'last_seen_at', 'last_heartbeat_at', 'connection_count',
            'last_error', 'last_error_at', 'performance_metrics',
            'business_name', 'business_id', 'paired_by_name',
            'paired_at', 'created_at', 'updated_at',
            # Computed fields
            'is_pairing_active', 'resolution_string', 'aspect_ratio',
            'uptime_percentage', 'performance_summary', 'connection_health'
        ]
        read_only_fields = [
            'id', 'device_token', 'pairing_code', 'pairing_expires_at',
            'status', 'last_seen_at', 'last_heartbeat_at', 'connection_count',
            'last_error', 'last_error_at', 'performance_metrics',
            'business_name', 'business_id', 'paired_by_name', 'paired_at',
            'created_at', 'updated_at', 'is_online', 'is_pairing_active',
            'resolution_string', 'aspect_ratio', 'uptime_percentage',
            'performance_summary', 'connection_health'
        ]
    
    def get_is_online(self, obj) -> bool:
        """Check if display is currently online."""
        return obj.is_online()
    
    def get_is_pairing_active(self, obj) -> bool:
        """Check if display has active pairing code."""
        return obj.is_pairing_code_valid()
    
    def get_resolution_string(self, obj) -> Optional[str]:
        """Get display resolution as string."""
        return obj.get_current_resolution_string()
    
    def get_aspect_ratio(self, obj) -> Optional[str]:
        """Get display aspect ratio."""
        return obj.get_aspect_ratio()
    
    def get_uptime_percentage(self, obj) -> float:
        """Calculate uptime percentage from recent sessions."""
        try:
            recent_sessions = obj.sessions.filter(
                started_at__gte=timezone.now() - timezone.timedelta(days=7)
            )
            
            if not recent_sessions.exists():
                return 0.0
            
            total_uptime = sum(session.get_uptime_percentage() for session in recent_sessions)
            return round(total_uptime / recent_sessions.count(), 2)
        except Exception:
            return 0.0
    
    def get_performance_summary(self, obj) -> Dict:
        """Get performance summary from metrics."""
        if not obj.performance_metrics:
            return {}
        
        # Extract key performance indicators
        summary = {
            'memory_usage': obj.performance_metrics.get('memory_usage_mb', 0),
            'cpu_usage': obj.performance_metrics.get('cpu_usage_percent', 0),
            'network_latency': obj.performance_metrics.get('network_latency_ms', 0),
            'frame_rate': obj.performance_metrics.get('frame_rate_fps', 0),
            'storage_free': obj.performance_metrics.get('storage_free_gb', 0)
        }
        
        return summary
    
    def get_connection_health(self, obj) -> Dict:
        """Assess connection health."""
        now = timezone.now()
        health = {
            'status': 'healthy',
            'score': 100,
            'issues': []
        }
        
        # Check if recently seen
        if obj.last_seen_at:
            offline_minutes = (now - obj.last_seen_at).total_seconds() / 60
            if offline_minutes > 10:
                health['issues'].append('Offline for extended period')
                health['score'] -= 30
                health['status'] = 'warning'
            elif offline_minutes > 60:
                health['score'] = 0
                health['status'] = 'critical'
        else:
            health['issues'].append('Never connected')
            health['score'] = 0
            health['status'] = 'critical'
        
        # Check error frequency
        if obj.last_error_at:
            hours_since_error = (now - obj.last_error_at).total_seconds() / 3600
            if hours_since_error < 1:
                health['issues'].append('Recent errors detected')
                health['score'] -= 20
                if health['status'] == 'healthy':
                    health['status'] = 'warning'
        
        # Check connection stability
        if obj.connection_count > 0:
            # This is simplified - would need more data for accurate calculation
            if obj.connection_count > 100:  # Frequent reconnections might indicate issues
                health['issues'].append('Frequent reconnections detected')
                health['score'] -= 10
        
        health['score'] = max(0, health['score'])
        return health


class DisplayCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating new display devices.
    
    Handles initial display registration and validation.
    """
    
    class Meta:
        model = Display
        fields = [
            'name', 'location', 'device_type', 'device_model',
            'screen_width', 'screen_height', 'screen_size_inches',
            'orientation', 'settings', 'mac_address'
        ]
    
    def validate_name(self, value):
        """Validate display name is unique within business."""
        if hasattr(self, 'context') and 'business' in self.context:
            business = self.context['business']
            if Display.objects.filter(business=business, name=value).exists():
                raise serializers.ValidationError(
                    f"Display with name '{value}' already exists for this business."
                )
        return value
    
    def validate_mac_address(self, value):
        """Validate MAC address format."""
        if value:
            import re
            if not re.match(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$', value):
                raise serializers.ValidationError("Invalid MAC address format.")
        return value
    
    def validate(self, attrs):
        """Cross-field validation."""
        # Validate screen dimensions
        width = attrs.get('screen_width')
        height = attrs.get('screen_height')
        
        if (width and not height) or (height and not width):
            raise serializers.ValidationError(
                "Both screen width and height must be provided together."
            )
        
        if width and height:
            if width <= 0 or height <= 0:
                raise serializers.ValidationError(
                    "Screen dimensions must be positive numbers."
                )
        
        return attrs
    
    def create(self, validated_data):
        """Create display with business context."""
        business = self.context['business']
        validated_data['business'] = business
        
        return super().create(validated_data)


class DisplayPairingSerializer(serializers.Serializer):
    """
    Serializer for display pairing operations.
    
    Handles QR code generation and pairing process validation.
    """
    
    pairing_code = serializers.CharField(max_length=8, required=False)
    device_info = serializers.DictField(required=False)
    
    def validate_pairing_code(self, value):
        """Validate pairing code format."""
        if value:
            if len(value) != 8:
                raise serializers.ValidationError("Pairing code must be 8 characters long.")
            
            if not value.isalnum():
                raise serializers.ValidationError("Pairing code must be alphanumeric.")
        
        return value.upper() if value else None
    
    def create(self, validated_data):
        """Generate pairing code and QR code data."""
        display = self.context.get('display')
        if not display:
            raise serializers.ValidationError("Display context required.")
        
        # Generate pairing code
        pairing_code = display.generate_pairing_code()
        
        # Generate QR code
        qr_data = self.generate_qr_code_data(display, pairing_code)
        
        return {
            'pairing_code': pairing_code,
            'expires_at': display.pairing_expires_at,
            'qr_code_data': qr_data['data_url'],
            'qr_code_text': qr_data['text'],
            'instructions': self.get_pairing_instructions()
        }
    
    def generate_qr_code_data(self, display: Display, pairing_code: str) -> Dict:
        """Generate QR code for display pairing."""
        # Create pairing URL/data
        qr_text = f"displaydeck://pair?code={pairing_code}&display={display.id}&business={display.business.id}"
        
        # Generate QR code
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(qr_text)
        qr.make(fit=True)
        
        # Create image
        qr_image = qr.make_image(fill_color="black", back_color="white")
        
        # Convert to base64
        buffer = io.BytesIO()
        qr_image.save(buffer, format='PNG')
        qr_image_data = base64.b64encode(buffer.getvalue()).decode()
        
        return {
            'text': qr_text,
            'data_url': f"data:image/png;base64,{qr_image_data}"
        }
    
    def get_pairing_instructions(self) -> List[str]:
        """Get step-by-step pairing instructions."""
        return [
            "Open the DisplayDeck mobile app",
            "Tap 'Add New Display' or the '+' button",
            "Point your camera at this QR code",
            "Follow the in-app instructions to complete pairing",
            "The display will show 'Paired Successfully' when complete"
        ]


class DisplayMenuAssignmentSerializer(serializers.ModelSerializer):
    """
    Serializer for menu assignments to displays.
    """
    
    display_name = serializers.CharField(source='display.name', read_only=True)
    menu_name = serializers.CharField(source='menu.name', read_only=True)
    assigned_by_name = serializers.CharField(source='assigned_by.get_full_name', read_only=True)
    
    class Meta:
        model = DisplayMenuAssignment
        fields = [
            'id', 'display_name', 'menu_name', 'assigned_by_name',
            'assigned_at', 'is_active'
        ]
        read_only_fields = ['id', 'assigned_at', 'display_name', 'menu_name', 'assigned_by_name']


class DisplayMenuAssignmentCreateSerializer(serializers.Serializer):
    """
    Serializer for creating menu assignments.
    """
    
    menu_id = serializers.UUIDField()
    
    def validate_menu_id(self, value):
        """Validate menu exists and belongs to same business as display."""
        try:
            menu = Menu.objects.get(id=value)
        except Menu.DoesNotExist:
            raise serializers.ValidationError("Menu not found.")
        
        display = self.context.get('display')
        if display and menu.business != display.business:
            raise serializers.ValidationError(
                "Menu must belong to the same business as the display."
            )
        
        return value
    
    def create(self, validated_data):
        """Create menu assignment."""
        display = self.context['display']
        menu = Menu.objects.get(id=validated_data['menu_id'])
        user = self.context.get('request', {}).user
        
        # Assign menu to display
        display.assign_menu(menu, user)
        
        # Return the assignment record
        assignment = DisplayMenuAssignment.objects.filter(
            display=display,
            menu=menu,
            is_active=True
        ).first()
        
        return assignment


class DisplayStatusSerializer(serializers.Serializer):
    """
    Serializer for display status updates and health monitoring.
    """
    
    status = serializers.ChoiceField(choices=Display.STATUS_CHOICES)
    ip_address = serializers.IPAddressField(required=False)
    performance_metrics = serializers.DictField(required=False)
    error_message = serializers.CharField(required=False, allow_blank=True)
    
    def update(self, instance, validated_data):
        """Update display status and metrics."""
        status = validated_data.get('status')
        ip_address = validated_data.get('ip_address')
        performance_metrics = validated_data.get('performance_metrics')
        error_message = validated_data.get('error_message')
        
        # Update status
        if status:
            instance.status = status
        
        # Update IP address
        if ip_address:
            instance.ip_address = ip_address
        
        # Update last seen timestamp
        instance.last_seen_at = timezone.now()
        
        # Handle status-specific updates
        if status == 'online':
            instance.mark_online(ip_address)
        elif status == 'offline':
            instance.mark_offline(error_message)
        elif status == 'error' and error_message:
            instance.last_error = error_message
            instance.last_error_at = timezone.now()
        
        # Update performance metrics
        if performance_metrics:
            instance.update_performance_metrics(performance_metrics)
        
        # Save changes
        update_fields = ['status', 'last_seen_at']
        if ip_address:
            update_fields.append('ip_address')
        if error_message and status == 'error':
            update_fields.extend(['last_error', 'last_error_at'])
        
        instance.save(update_fields=update_fields)
        
        return instance


class DisplayGroupSerializer(serializers.ModelSerializer):
    """
    Serializer for display groups.
    """
    
    business_name = serializers.CharField(source='business.name', read_only=True)
    display_count = serializers.SerializerMethodField()
    online_display_count = serializers.SerializerMethodField()
    default_menu_name = serializers.CharField(source='default_menu.name', read_only=True)
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True)
    
    class Meta:
        model = DisplayGroup
        fields = [
            'id', 'name', 'description', 'is_active',
            'business_name', 'default_menu_name', 'created_by_name',
            'display_count', 'online_display_count', 'settings',
            'created_at', 'updated_at'
        ]
        read_only_fields = [
            'id', 'business_name', 'default_menu_name', 'created_by_name',
            'display_count', 'online_display_count', 'created_at', 'updated_at'
        ]
    
    def get_display_count(self, obj) -> int:
        """Get total number of displays in group."""
        return obj.get_display_count()
    
    def get_online_display_count(self, obj) -> int:
        """Get number of online displays in group."""
        return obj.get_online_display_count()


class DisplaySessionSerializer(serializers.ModelSerializer):
    """
    Serializer for display sessions.
    """
    
    display_name = serializers.CharField(source='display.name', read_only=True)
    session_duration = serializers.SerializerMethodField()
    uptime_percentage = serializers.SerializerMethodField()
    
    class Meta:
        model = DisplaySession
        fields = [
            'id', 'display_name', 'session_id', 'started_at', 'ended_at',
            'is_active', 'ip_address', 'total_uptime_seconds',
            'heartbeat_count', 'error_count', 'menus_displayed',
            'session_duration', 'uptime_percentage'
        ]
        read_only_fields = [
            'id', 'display_name', 'session_duration', 'uptime_percentage'
        ]
    
    def get_session_duration(self, obj) -> str:
        """Get session duration as formatted string."""
        duration = obj.get_session_duration()
        hours, remainder = divmod(duration.total_seconds(), 3600)
        minutes, seconds = divmod(remainder, 60)
        return f"{int(hours):02d}:{int(minutes):02d}:{int(seconds):02d}"
    
    def get_uptime_percentage(self, obj) -> float:
        """Get uptime percentage for this session."""
        return obj.get_uptime_percentage()


class DisplayHealthCheckSerializer(serializers.Serializer):
    """
    Serializer for display health check responses.
    """
    
    display_id = serializers.UUIDField()
    timestamp = serializers.DateTimeField()
    app_version = serializers.CharField(required=False)
    os_version = serializers.CharField(required=False)
    performance_metrics = serializers.DictField(required=False)
    current_menu_id = serializers.UUIDField(required=False)
    errors = serializers.ListField(child=serializers.CharField(), required=False)
    
    def validate_display_id(self, value):
        """Validate display exists."""
        try:
            display = Display.objects.get(id=value)
        except Display.DoesNotExist:
            raise serializers.ValidationError("Display not found.")
        
        return value
    
    def create(self, validated_data):
        """Process health check data."""
        display_id = validated_data['display_id']
        display = Display.objects.get(id=display_id)
        
        # Update display information
        app_version = validated_data.get('app_version')
        os_version = validated_data.get('os_version')
        performance_metrics = validated_data.get('performance_metrics')
        errors = validated_data.get('errors', [])
        
        update_fields = ['last_heartbeat_at']
        
        # Update heartbeat
        display.update_heartbeat()
        
        # Update version information
        if app_version and display.app_version != app_version:
            display.app_version = app_version
            update_fields.append('app_version')
        
        if os_version and display.os_version != os_version:
            display.os_version = os_version
            update_fields.append('os_version')
        
        # Update performance metrics
        if performance_metrics:
            display.update_performance_metrics(performance_metrics)
        
        # Handle errors
        if errors:
            display.last_error = '; '.join(errors[:3])  # Store up to 3 recent errors
            display.last_error_at = timezone.now()
            update_fields.extend(['last_error', 'last_error_at'])
        
        # Save if there are fields to update
        if len(update_fields) > 1:  # More than just last_heartbeat_at
            display.save(update_fields=update_fields)
        
        return {
            'display_id': display_id,
            'status': 'healthy' if not errors else 'warning',
            'message': 'Health check processed successfully',
            'next_check_in': 30  # seconds
        }