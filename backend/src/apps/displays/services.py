"""
Display services for DisplayDeck.

Contains business logic for display management, device communication,
status monitoring, and health checking.
"""

import uuid
import secrets
import qrcode
import qrcode.image.svg
from io import BytesIO
from datetime import timedelta
from typing import Dict, List, Any, Optional
from django.utils import timezone
from django.core.cache import cache
from django.conf import settings
from django.db.models import Q, Count, Avg, Sum
from django.contrib.auth import get_user_model

from .models import Display, DisplaySession, DisplayMenuAssignment, DisplayGroup
from apps.menus.models import Menu
from apps.businesses.models import Business

User = get_user_model()


class DisplayPairingService:
    """Service for handling display device pairing."""
    
    PAIRING_CODE_LENGTH = 8
    PAIRING_CODE_EXPIRY_MINUTES = 15
    QR_CODE_SIZE = 300
    
    @classmethod
    def generate_pairing_code(cls, display: Display) -> Dict[str, Any]:
        """
        Generate a new pairing code and QR code for display setup.
        
        Returns:
            Dict containing pairing code, QR code SVG, and expiry time
        """
        # Generate pairing code
        pairing_code = cls._generate_secure_code()
        
        # Set expiry time
        expires_at = timezone.now() + timedelta(minutes=cls.PAIRING_CODE_EXPIRY_MINUTES)
        
        # Update display
        display.pairing_code = pairing_code
        display.pairing_code_expires_at = expires_at
        display.save(update_fields=['pairing_code', 'pairing_code_expires_at'])
        
        # Generate QR code
        qr_code_data = {
            'type': 'display_pairing',
            'code': pairing_code,
            'display_id': str(display.id),
            'business_id': str(display.business_id),
            'expires_at': expires_at.isoformat()
        }
        
        qr_code_svg = cls._generate_qr_code(qr_code_data)
        
        return {
            'pairing_code': pairing_code,
            'qr_code_svg': qr_code_svg,
            'expires_at': expires_at,
            'display_name': display.name,
            'business_name': display.business.name
        }
    
    @classmethod
    def validate_pairing_code(cls, code: str) -> Optional[Display]:
        """
        Validate a pairing code and return the associated display.
        
        Returns:
            Display if valid, None otherwise
        """
        try:
            display = Display.objects.get(pairing_code=code.upper())
            
            # Check expiry
            if display.is_pairing_code_valid():
                return display
            else:
                # Clear expired code
                display.clear_pairing_code()
                return None
                
        except Display.DoesNotExist:
            return None
    
    @classmethod
    def complete_pairing(cls, display: Display, user: User, device_info: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Complete the pairing process for a display.
        
        Args:
            display: Display to pair
            user: User performing the pairing
            device_info: Optional device information
            
        Returns:
            Dict containing pairing results
        """
        # Update display
        display.paired_by = user
        display.paired_at = timezone.now()
        display.status = 'online'
        display.last_seen_at = timezone.now()
        
        # Generate device token for authentication
        if not display.device_token:
            display.device_token = cls._generate_device_token()
        
        # Update device info if provided
        if device_info:
            if 'app_version' in device_info:
                display.app_version = device_info['app_version']
            if 'os_version' in device_info:
                display.os_version = device_info['os_version']
            if 'screen_width' in device_info and 'screen_height' in device_info:
                display.screen_width = device_info['screen_width']
                display.screen_height = device_info['screen_height']
        
        display.save()
        
        # Clear pairing code
        display.clear_pairing_code()
        
        # Create initial session
        DisplaySessionService.start_session(display)
        
        return {
            'paired': True,
            'device_token': display.device_token,
            'display_name': display.name,
            'business_name': display.business.name
        }
    
    @classmethod
    def _generate_secure_code(cls) -> str:
        """Generate a secure pairing code."""
        return secrets.token_hex(4).upper()
    
    @classmethod
    def _generate_device_token(cls) -> str:
        """Generate a secure device token for API authentication."""
        return secrets.token_urlsafe(32)
    
    @classmethod
    def _generate_qr_code(cls, data: Dict[str, Any]) -> str:
        """Generate QR code SVG from data."""
        import json
        
        # Create QR code
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4
        )
        
        qr.add_data(json.dumps(data))
        qr.make(fit=True)
        
        # Generate SVG
        factory = qrcode.image.svg.SvgPathImage
        img = qr.make_image(image_factory=factory)
        
        # Convert to string
        buffer = BytesIO()
        img.save(buffer)
        return buffer.getvalue().decode('utf-8')


class DisplayStatusService:
    """Service for handling display status and health monitoring."""
    
    HEARTBEAT_INTERVAL_SECONDS = 60
    OFFLINE_THRESHOLD_MINUTES = 5
    HEALTH_CHECK_CACHE_SECONDS = 30
    
    @classmethod
    def process_health_check(cls, display: Display, health_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Process health check data from a display.
        
        Args:
            display: Display device
            health_data: Health metrics and status data
            
        Returns:
            Dict containing processing results
        """
        now = timezone.now()
        
        # Update basic status
        display.last_heartbeat_at = now
        display.last_seen_at = now
        display.connection_count += 1
        
        # Update status if changed
        new_status = health_data.get('status')
        if new_status and new_status != display.status:
            display.status = new_status
        
        # Update performance metrics
        if 'performance' in health_data:
            display.performance_metrics = cls._merge_performance_metrics(
                display.performance_metrics or {},
                health_data['performance']
            )
        
        # Update network info
        if 'ip_address' in health_data:
            display.ip_address = health_data['ip_address']
        
        # Handle errors
        if 'error' in health_data:
            display.last_error = health_data['error']
            display.last_error_at = now
        
        # Update app version if provided
        if 'app_version' in health_data:
            display.app_version = health_data['app_version']
        
        display.save()
        
        # Update current session
        session = DisplaySessionService.get_current_session(display)
        if session:
            session.last_heartbeat_at = now
            if 'performance' in health_data:
                session.performance_data = cls._merge_performance_metrics(
                    session.performance_data or {},
                    health_data['performance']
                )
            if 'error' in health_data:
                session.error_count += 1
                session.last_error = health_data['error']
            session.save()
        
        # Cache health status for quick access
        cache_key = f"display_health:{display.id}"
        cache.set(cache_key, health_data, cls.HEALTH_CHECK_CACHE_SECONDS)
        
        return {
            'processed': True,
            'status': display.status,
            'timestamp': now.isoformat()
        }
    
    @classmethod
    def check_display_health(cls, display: Display) -> Dict[str, Any]:
        """
        Get comprehensive health status for a display.
        
        Returns:
            Dict containing health metrics and status
        """
        now = timezone.now()
        
        # Check cache first
        cache_key = f"display_health:{display.id}"
        cached_data = cache.get(cache_key)
        
        # Calculate basic status
        is_online = display.is_online()
        is_offline_too_long = display.is_offline_too_long()
        
        # Get recent sessions for analysis
        recent_sessions = display.sessions.filter(
            started_at__gte=now - timedelta(days=1)
        ).order_by('-started_at')
        
        # Calculate uptime metrics
        total_sessions_today = recent_sessions.count()
        total_uptime_seconds = sum(s.total_uptime_seconds for s in recent_sessions)
        total_errors = sum(s.error_count for s in recent_sessions)
        
        # Performance analysis
        performance_data = display.performance_metrics or {}
        avg_cpu = performance_data.get('cpu_usage', 0)
        avg_memory = performance_data.get('memory_usage', 0)
        avg_network = performance_data.get('network_latency', 0)
        
        # Generate health score (0-100)
        health_score = cls._calculate_health_score(
            is_online, total_errors, avg_cpu, avg_memory, total_uptime_seconds
        )
        
        return {
            'display_id': str(display.id),
            'name': display.name,
            'status': display.status,
            'health_score': health_score,
            'is_online': is_online,
            'is_offline_too_long': is_offline_too_long,
            'connection': {
                'last_seen': display.last_seen_at.isoformat() if display.last_seen_at else None,
                'last_heartbeat': display.last_heartbeat_at.isoformat() if display.last_heartbeat_at else None,
                'connection_count': display.connection_count,
                'ip_address': display.ip_address
            },
            'uptime': {
                'sessions_today': total_sessions_today,
                'total_uptime_seconds': total_uptime_seconds,
                'uptime_percentage': cls._calculate_uptime_percentage(total_uptime_seconds)
            },
            'errors': {
                'total_errors_today': total_errors,
                'last_error': display.last_error,
                'last_error_at': display.last_error_at.isoformat() if display.last_error_at else None
            },
            'performance': performance_data,
            'device': {
                'app_version': display.app_version,
                'os_version': display.os_version,
                'device_model': display.device_model,
                'screen_resolution': f"{display.screen_width}x{display.screen_height}" if display.screen_width else None
            },
            'timestamp': now.isoformat(),
            'cached_data': cached_data
        }
    
    @classmethod
    def _merge_performance_metrics(cls, existing: Dict[str, Any], new: Dict[str, Any]) -> Dict[str, Any]:
        """Merge performance metrics with existing data."""
        merged = existing.copy()
        
        # Average numeric values
        numeric_fields = ['cpu_usage', 'memory_usage', 'network_latency', 'fps', 'battery_level']
        
        for field in numeric_fields:
            if field in new:
                if field in merged:
                    # Calculate running average
                    merged[field] = (merged[field] + new[field]) / 2
                else:
                    merged[field] = new[field]
        
        # Update timestamps and counts
        merged['last_updated'] = timezone.now().isoformat()
        merged['update_count'] = merged.get('update_count', 0) + 1
        
        return merged
    
    @classmethod
    def _calculate_health_score(cls, is_online: bool, error_count: int, cpu: float, memory: float, uptime: int) -> int:
        """Calculate overall health score (0-100)."""
        score = 100
        
        # Penalize if offline
        if not is_online:
            score -= 50
        
        # Penalize for errors
        score -= min(error_count * 5, 30)
        
        # Penalize for high resource usage
        if cpu > 80:
            score -= 10
        if memory > 80:
            score -= 10
        
        # Bonus for good uptime (more than 20 hours today)
        if uptime > 72000:  # 20 hours in seconds
            score += 5
        
        return max(0, min(100, score))
    
    @classmethod
    def _calculate_uptime_percentage(cls, uptime_seconds: int) -> float:
        """Calculate uptime percentage for today."""
        total_seconds_in_day = 24 * 60 * 60
        return min(100.0, (uptime_seconds / total_seconds_in_day) * 100)


class DisplaySessionService:
    """Service for managing display sessions and tracking usage."""
    
    @classmethod
    def start_session(cls, display: Display) -> DisplaySession:
        """Start a new session for a display."""
        # End any active session first
        cls.end_current_session(display)
        
        session = DisplaySession.objects.create(
            display=display,
            started_at=timezone.now(),
            started_by=display.paired_by
        )
        
        return session
    
    @classmethod
    def end_current_session(cls, display: Display) -> Optional[DisplaySession]:
        """End the current session for a display."""
        try:
            session = display.sessions.filter(ended_at__isnull=True).latest('started_at')
            session.ended_at = timezone.now()
            session.total_uptime_seconds = (session.ended_at - session.started_at).total_seconds()
            session.save()
            return session
        except DisplaySession.DoesNotExist:
            return None
    
    @classmethod
    def get_current_session(cls, display: Display) -> Optional[DisplaySession]:
        """Get the current active session for a display."""
        try:
            return display.sessions.filter(ended_at__isnull=True).latest('started_at')
        except DisplaySession.DoesNotExist:
            return None
    
    @classmethod
    def update_session_metrics(cls, display: Display, metrics: Dict[str, Any]) -> bool:
        """Update metrics for the current session."""
        session = cls.get_current_session(display)
        if not session:
            return False
        
        session.performance_data = DisplayStatusService._merge_performance_metrics(
            session.performance_data or {},
            metrics
        )
        session.last_heartbeat_at = timezone.now()
        session.save()
        
        return True
    
    @classmethod
    def get_session_analytics(cls, display: Display, days: int = 7) -> Dict[str, Any]:
        """Get session analytics for a display."""
        since = timezone.now() - timedelta(days=days)
        sessions = display.sessions.filter(started_at__gte=since)
        
        total_sessions = sessions.count()
        total_uptime = sum(s.total_uptime_seconds for s in sessions)
        total_errors = sum(s.error_count for s in sessions)
        
        # Calculate averages
        avg_session_duration = total_uptime / total_sessions if total_sessions > 0 else 0
        avg_errors_per_session = total_errors / total_sessions if total_sessions > 0 else 0
        
        # Get daily breakdown
        daily_sessions = sessions.values('started_at__date').annotate(
            session_count=Count('id'),
            total_uptime=Sum('total_uptime_seconds'),
            total_errors=Sum('error_count')
        ).order_by('started_at__date')
        
        return {
            'period_days': days,
            'total_sessions': total_sessions,
            'total_uptime_seconds': total_uptime,
            'total_uptime_hours': total_uptime / 3600,
            'total_errors': total_errors,
            'avg_session_duration_seconds': avg_session_duration,
            'avg_errors_per_session': avg_errors_per_session,
            'daily_breakdown': list(daily_sessions)
        }


class DisplayGroupService:
    """Service for managing display groups and bulk operations."""
    
    @classmethod
    def assign_menu_to_group(cls, group: DisplayGroup, menu: Menu, user: User) -> int:
        """Assign a menu to all displays in a group."""
        displays = group.displays.filter(is_active=True)
        success_count = 0
        
        for display in displays:
            try:
                # Create or update menu assignment
                assignment, created = DisplayMenuAssignment.objects.update_or_create(
                    display=display,
                    defaults={
                        'menu': menu,
                        'assigned_by': user,
                        'assigned_at': timezone.now(),
                        'is_active': True
                    }
                )
                
                # Update display current menu
                display.current_menu = menu
                display.save(update_fields=['current_menu'])
                
                success_count += 1
            except Exception:
                continue
        
        return success_count
    
    @classmethod
    def apply_group_settings(cls, group: DisplayGroup) -> int:
        """Apply group settings to all displays."""
        displays = group.displays.filter(is_active=True)
        updated_count = 0
        
        for display in displays:
            try:
                # Apply group settings
                if group.default_orientation:
                    display.orientation = group.default_orientation
                
                if group.default_brightness:
                    display.brightness = group.default_brightness
                
                if group.default_volume:
                    display.volume = group.default_volume
                
                if group.default_menu:
                    display.current_menu = group.default_menu
                
                # Apply schedule settings
                if hasattr(group, 'schedule_settings'):
                    display.schedule_settings = group.schedule_settings
                
                display.save()
                updated_count += 1
            except Exception:
                continue
        
        return updated_count
    
    @classmethod
    def get_group_status_summary(cls, group: DisplayGroup) -> Dict[str, Any]:
        """Get status summary for all displays in a group."""
        displays = group.displays.filter(is_active=True)
        total_displays = displays.count()
        
        if total_displays == 0:
            return {
                'total_displays': 0,
                'online_count': 0,
                'offline_count': 0,
                'error_count': 0,
                'avg_health_score': 0
            }
        
        # Count statuses
        online_count = displays.filter(status='online').count()
        offline_count = displays.filter(status='offline').count()
        error_displays = displays.exclude(last_error__isnull=True, last_error='')
        
        # Calculate average health scores
        health_scores = []
        for display in displays:
            health_data = DisplayStatusService.check_display_health(display)
            health_scores.append(health_data['health_score'])
        
        avg_health_score = sum(health_scores) / len(health_scores) if health_scores else 0
        
        return {
            'total_displays': total_displays,
            'online_count': online_count,
            'offline_count': offline_count,
            'error_count': error_displays.count(),
            'avg_health_score': round(avg_health_score, 1),
            'status_distribution': {
                'online': online_count,
                'offline': offline_count,
                'updating': displays.filter(status='updating').count(),
                'error': displays.filter(status='error').count()
            }
        }


class DisplayAnalyticsService:
    """Service for display usage analytics and reporting."""
    
    @classmethod
    def get_business_display_analytics(cls, business: Business, days: int = 30) -> Dict[str, Any]:
        """Get analytics for all displays in a business."""
        since = timezone.now() - timedelta(days=days)
        displays = business.displays.filter(is_active=True)
        
        total_displays = displays.count()
        
        if total_displays == 0:
            return cls._empty_analytics(days)
        
        # Get all sessions in the period
        sessions = DisplaySession.objects.filter(
            display__in=displays,
            started_at__gte=since
        )
        
        # Calculate metrics
        total_sessions = sessions.count()
        total_uptime = sum(s.total_uptime_seconds for s in sessions)
        total_errors = sum(s.error_count for s in sessions)
        
        # Performance metrics
        active_displays = displays.filter(last_seen_at__gte=since)
        avg_health_scores = []
        
        for display in active_displays:
            health_data = DisplayStatusService.check_display_health(display)
            avg_health_scores.append(health_data['health_score'])
        
        avg_health_score = sum(avg_health_scores) / len(avg_health_scores) if avg_health_scores else 0
        
        # Daily breakdown
        daily_analytics = sessions.extra({
            'date': 'date(started_at)'
        }).values('date').annotate(
            session_count=Count('id'),
            total_uptime=Sum('total_uptime_seconds'),
            error_count=Sum('error_count'),
            active_displays=Count('display', distinct=True)
        ).order_by('date')
        
        # Top performing displays
        display_performance = []
        for display in displays:
            display_sessions = sessions.filter(display=display)
            display_uptime = sum(s.total_uptime_seconds for s in display_sessions)
            display_errors = sum(s.error_count for s in display_sessions)
            
            health_data = DisplayStatusService.check_display_health(display)
            
            display_performance.append({
                'display_id': str(display.id),
                'name': display.name,
                'location': display.location,
                'uptime_hours': display_uptime / 3600,
                'error_count': display_errors,
                'health_score': health_data['health_score'],
                'last_seen': display.last_seen_at.isoformat() if display.last_seen_at else None
            })
        
        # Sort by health score descending
        display_performance.sort(key=lambda x: x['health_score'], reverse=True)
        
        return {
            'period_days': days,
            'total_displays': total_displays,
            'active_displays': active_displays.count(),
            'total_sessions': total_sessions,
            'total_uptime_hours': total_uptime / 3600,
            'avg_uptime_per_display': (total_uptime / total_displays) / 3600 if total_displays > 0 else 0,
            'total_errors': total_errors,
            'avg_health_score': round(avg_health_score, 1),
            'daily_analytics': list(daily_analytics),
            'top_displays': display_performance[:10],  # Top 10 displays
            'bottom_displays': display_performance[-5:] if len(display_performance) > 5 else []  # Bottom 5 displays
        }
    
    @classmethod
    def _empty_analytics(cls, days: int) -> Dict[str, Any]:
        """Return empty analytics structure."""
        return {
            'period_days': days,
            'total_displays': 0,
            'active_displays': 0,
            'total_sessions': 0,
            'total_uptime_hours': 0,
            'avg_uptime_per_display': 0,
            'total_errors': 0,
            'avg_health_score': 0,
            'daily_analytics': [],
            'top_displays': [],
            'bottom_displays': []
        }