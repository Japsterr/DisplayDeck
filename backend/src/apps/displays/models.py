# Display models for DisplayDeck - managing digital displays and pairing

import uuid
import secrets
from django.db import models
from django.utils.translation import gettext_lazy as _
from django.core.validators import RegexValidator, MinValueValidator, MaxValueValidator
from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError


User = get_user_model()


class Display(models.Model):
    """
    Model representing a digital display device (TV, tablet, etc.)
    that shows menu content in a restaurant.
    """
    
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        help_text=_("Unique identifier for the display")
    )
    
    business = models.ForeignKey(
        'businesses.Business',
        on_delete=models.CASCADE,
        related_name='displays',
        help_text=_("Business this display belongs to")
    )
    
    # Display identification
    name = models.CharField(
        _("display name"),
        max_length=100,
        help_text=_("Human-readable name for the display")
    )
    
    location = models.CharField(
        _("location"),
        max_length=255,
        blank=True,
        help_text=_("Physical location of the display (e.g., 'Main Counter', 'Drive-thru')")
    )
    
    # Device information
    DEVICE_TYPE_CHOICES = [
        ('android_tv', _('Android TV')),
        ('tablet', _('Tablet')),
        ('desktop', _('Desktop Computer')),
        ('smart_tv', _('Smart TV')),
        ('raspberry_pi', _('Raspberry Pi')),
        ('other', _('Other')),
    ]
    
    device_type = models.CharField(
        _("device type"),
        max_length=20,
        choices=DEVICE_TYPE_CHOICES,
        default='android_tv',
        help_text=_("Type of device used for this display")
    )
    
    device_model = models.CharField(
        _("device model"),
        max_length=100,
        blank=True,
        help_text=_("Model/brand of the display device")
    )
    
    # Screen specifications
    screen_width = models.PositiveIntegerField(
        _("screen width (pixels)"),
        blank=True,
        null=True,
        help_text=_("Screen width in pixels")
    )
    
    screen_height = models.PositiveIntegerField(
        _("screen height (pixels)"),
        blank=True,
        null=True,
        help_text=_("Screen height in pixels")
    )
    
    screen_size_inches = models.DecimalField(
        _("screen size (inches)"),
        max_digits=4,
        decimal_places=1,
        blank=True,
        null=True,
        validators=[MinValueValidator(1), MaxValueValidator(200)],
        help_text=_("Screen diagonal size in inches")
    )
    
    # Display orientation and layout
    ORIENTATION_CHOICES = [
        ('landscape', _('Landscape')),
        ('portrait', _('Portrait')),
        ('auto', _('Auto-rotate')),
    ]
    
    orientation = models.CharField(
        _("orientation"),
        max_length=20,
        choices=ORIENTATION_CHOICES,
        default='landscape',
        help_text=_("Display orientation")
    )
    
    # Menu assignment
    current_menu = models.ForeignKey(
        'menus.Menu',
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='assigned_displays',
        help_text=_("Currently assigned menu")
    )
    
    # Display settings and configuration
    settings = models.JSONField(
        _("display settings"),
        default=dict,
        blank=True,
        help_text=_("Display-specific settings and preferences")
    )
    
    # Pairing and authentication
    pairing_code = models.CharField(
        _("pairing code"),
        max_length=8,
        blank=True,
        unique=True,
        help_text=_("8-character code for pairing new displays")
    )
    
    pairing_expires_at = models.DateTimeField(
        _("pairing expires at"),
        blank=True,
        null=True,
        help_text=_("When the current pairing code expires")
    )
    
    device_token = models.CharField(
        _("device token"),
        max_length=255,
        blank=True,
        help_text=_("Unique token for device authentication")
    )
    
    # Status and connectivity
    STATUS_CHOICES = [
        ('offline', _('Offline')),
        ('online', _('Online')),
        ('connecting', _('Connecting')),
        ('error', _('Error')),
        ('updating', _('Updating')),
    ]
    
    status = models.CharField(
        _("status"),
        max_length=20,
        choices=STATUS_CHOICES,
        default='offline',
        help_text=_("Current status of the display")
    )
    
    is_active = models.BooleanField(
        _("is active"),
        default=True,
        help_text=_("Whether this display is currently active")
    )
    
    # Network and connectivity information
    ip_address = models.GenericIPAddressField(
        _("IP address"),
        blank=True,
        null=True,
        help_text=_("Current IP address of the display device")
    )
    
    mac_address = models.CharField(
        _("MAC address"),
        max_length=17,
        blank=True,
        validators=[RegexValidator(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$')],
        help_text=_("MAC address of the display device")
    )
    
    # Software and version information
    app_version = models.CharField(
        _("app version"),
        max_length=20,
        blank=True,
        help_text=_("Version of the display app")
    )
    
    os_version = models.CharField(
        _("OS version"),
        max_length=50,
        blank=True,
        help_text=_("Operating system version")
    )
    
    # Connection and activity tracking
    last_seen_at = models.DateTimeField(
        _("last seen at"),
        blank=True,
        null=True,
        help_text=_("Last time the display was seen online")
    )
    
    last_heartbeat_at = models.DateTimeField(
        _("last heartbeat at"),
        blank=True,
        null=True,
        help_text=_("Last heartbeat received from the display")
    )
    
    connection_count = models.PositiveIntegerField(
        _("connection count"),
        default=0,
        help_text=_("Total number of times display has connected")
    )
    
    # Performance and diagnostics
    last_error = models.TextField(
        _("last error"),
        blank=True,
        help_text=_("Last error message from the display")
    )
    
    last_error_at = models.DateTimeField(
        _("last error at"),
        blank=True,
        null=True,
        help_text=_("When the last error occurred")
    )
    
    performance_metrics = models.JSONField(
        _("performance metrics"),
        default=dict,
        blank=True,
        help_text=_("Performance and diagnostic metrics")
    )
    
    # Timestamps and tracking
    created_at = models.DateTimeField(
        _("created at"),
        auto_now_add=True,
        help_text=_("When the display was first registered")
    )
    
    updated_at = models.DateTimeField(
        _("updated at"),
        auto_now=True,
        help_text=_("When the display was last updated")
    )
    
    paired_at = models.DateTimeField(
        _("paired at"),
        blank=True,
        null=True,
        help_text=_("When the display was paired with the business")
    )
    
    paired_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='paired_displays',
        help_text=_("User who paired this display")
    )
    
    class Meta:
        verbose_name = _("Display")
        verbose_name_plural = _("Displays")
        db_table = "displays_display"
        ordering = ['name']
        indexes = [
            models.Index(fields=['business', 'is_active'], name='display_business_active_idx'),
            models.Index(fields=['status'], name='display_status_idx'),
            models.Index(fields=['pairing_code'], name='display_pairing_code_idx'),
            models.Index(fields=['device_token'], name='display_device_token_idx'),
            models.Index(fields=['last_seen_at'], name='display_last_seen_idx'),
            models.Index(fields=['ip_address'], name='display_ip_idx'),
        ]
        constraints = [
            models.CheckConstraint(
                check=models.Q(screen_width__isnull=True) | models.Q(screen_width__gt=0),
                name='display_positive_width'
            ),
            models.CheckConstraint(
                check=models.Q(screen_height__isnull=True) | models.Q(screen_height__gt=0),
                name='display_positive_height'
            ),
        ]
    
    def __str__(self):
        return f"{self.business.name} - {self.name}"
    
    def clean(self):
        """Validate the display."""
        super().clean()
        
        # Validate current menu belongs to the same business
        if self.current_menu and self.current_menu.business != self.business:
            raise ValidationError(_("Assigned menu must belong to the same business."))
        
        # Validate screen dimensions
        if self.screen_width and self.screen_height:
            if self.screen_width <= 0 or self.screen_height <= 0:
                raise ValidationError(_("Screen dimensions must be positive numbers."))
    
    def save(self, *args, **kwargs):
        """Override save to handle device token generation."""
        if not self.device_token:
            self.device_token = secrets.token_urlsafe(32)
        
        super().save(*args, **kwargs)
    
    def generate_pairing_code(self):
        """Generate a new pairing code for the display."""
        from django.utils import timezone
        from datetime import timedelta
        
        # Generate 8-character alphanumeric code
        code = ''.join(secrets.choice('ABCDEFGHJKMNPQRSTUVWXYZ23456789') for _ in range(8))
        
        # Ensure uniqueness
        while Display.objects.filter(pairing_code=code).exists():
            code = ''.join(secrets.choice('ABCDEFGHJKMNPQRSTUVWXYZ23456789') for _ in range(8))
        
        self.pairing_code = code
        self.pairing_expires_at = timezone.now() + timedelta(hours=24)
        self.save(update_fields=['pairing_code', 'pairing_expires_at'])
        
        return code
    
    def clear_pairing_code(self):
        """Clear the pairing code after successful pairing."""
        self.pairing_code = ''
        self.pairing_expires_at = None
        self.save(update_fields=['pairing_code', 'pairing_expires_at'])
    
    def is_pairing_code_valid(self):
        """Check if the current pairing code is valid."""
        from django.utils import timezone
        
        if not self.pairing_code:
            return False
        
        if not self.pairing_expires_at:
            return False
        
        return self.pairing_expires_at > timezone.now()
    
    def is_online(self):
        """Check if the display is currently online."""
        return self.status == 'online'
    
    def is_offline_too_long(self, threshold_minutes=5):
        """Check if display has been offline longer than threshold."""
        from django.utils import timezone
        from datetime import timedelta
        
        if not self.last_seen_at:
            return True
        
        threshold = timezone.now() - timedelta(minutes=threshold_minutes)
        return self.last_seen_at < threshold
    
    def mark_online(self, ip_address=None):
        """Mark the display as online and update connection info."""
        from django.utils import timezone
        
        self.status = 'online'
        self.last_seen_at = timezone.now()
        self.last_heartbeat_at = timezone.now()
        
        if ip_address:
            self.ip_address = ip_address
        
        self.connection_count += 1
        self.save(update_fields=[
            'status', 'last_seen_at', 'last_heartbeat_at', 
            'ip_address', 'connection_count'
        ])
    
    def mark_offline(self, error_message=None):
        """Mark the display as offline."""
        from django.utils import timezone
        
        self.status = 'offline'
        
        if error_message:
            self.last_error = error_message
            self.last_error_at = timezone.now()
            update_fields = ['status', 'last_error', 'last_error_at']
        else:
            update_fields = ['status']
        
        self.save(update_fields=update_fields)
    
    def update_heartbeat(self):
        """Update the last heartbeat timestamp."""
        from django.utils import timezone
        
        self.last_heartbeat_at = timezone.now()
        
        # Update status to online if it was offline
        if self.status == 'offline':
            self.status = 'online'
            update_fields = ['last_heartbeat_at', 'status']
        else:
            update_fields = ['last_heartbeat_at']
        
        self.save(update_fields=update_fields)
    
    def assign_menu(self, menu, user=None):
        """Assign a menu to this display."""
        if menu.business != self.business:
            raise ValidationError(_("Menu must belong to the same business as the display."))
        
        self.current_menu = menu
        self.save(update_fields=['current_menu'])
        
        # Log the assignment
        DisplayMenuAssignment.objects.create(
            display=self,
            menu=menu,
            assigned_by=user
        )
        
        return True
    
    def get_current_resolution_string(self):
        """Get the current resolution as a string."""
        if self.screen_width and self.screen_height:
            return f"{self.screen_width}x{self.screen_height}"
        return None
    
    def get_aspect_ratio(self):
        """Calculate the aspect ratio of the display."""
        if self.screen_width and self.screen_height:
            from math import gcd
            common_divisor = gcd(self.screen_width, self.screen_height)
            return f"{self.screen_width // common_divisor}:{self.screen_height // common_divisor}"
        return None
    
    def update_performance_metrics(self, metrics):
        """Update performance metrics for the display."""
        from django.utils import timezone
        
        if not isinstance(metrics, dict):
            return
        
        # Add timestamp to metrics
        metrics['updated_at'] = timezone.now().isoformat()
        
        # Merge with existing metrics
        if self.performance_metrics:
            self.performance_metrics.update(metrics)
        else:
            self.performance_metrics = metrics
        
        self.save(update_fields=['performance_metrics'])


class DisplayMenuAssignment(models.Model):
    """
    Model to track menu assignments to displays for audit purposes.
    """
    
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    
    display = models.ForeignKey(
        Display,
        on_delete=models.CASCADE,
        related_name='menu_assignments',
        help_text=_("Display that received the menu assignment")
    )
    
    menu = models.ForeignKey(
        'menus.Menu',
        on_delete=models.CASCADE,
        related_name='display_assignments',
        help_text=_("Menu that was assigned")
    )
    
    assigned_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='display_menu_assignments',
        help_text=_("User who made the assignment")
    )
    
    assigned_at = models.DateTimeField(
        _("assigned at"),
        auto_now_add=True,
        help_text=_("When the assignment was made")
    )
    
    is_active = models.BooleanField(
        _("is active"),
        default=True,
        help_text=_("Whether this is the current active assignment")
    )
    
    class Meta:
        verbose_name = _("Display Menu Assignment")
        verbose_name_plural = _("Display Menu Assignments")
        db_table = "displays_menu_assignment"
        ordering = ['-assigned_at']
        indexes = [
            models.Index(fields=['display', 'is_active'], name='assignment_display_active_idx'),
            models.Index(fields=['menu'], name='assignment_menu_idx'),
            models.Index(fields=['assigned_at'], name='assignment_assigned_idx'),
        ]
    
    def __str__(self):
        return f"{self.display.name} - {self.menu.name} ({self.assigned_at})"
    
    def save(self, *args, **kwargs):
        """Override save to ensure only one active assignment per display."""
        if self.is_active:
            # Mark all other assignments for this display as inactive
            DisplayMenuAssignment.objects.filter(
                display=self.display, is_active=True
            ).exclude(pk=self.pk).update(is_active=False)
        
        super().save(*args, **kwargs)


class DisplayGroup(models.Model):
    """
    Model for grouping displays together for bulk operations.
    """
    
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    
    business = models.ForeignKey(
        'businesses.Business',
        on_delete=models.CASCADE,
        related_name='display_groups',
        help_text=_("Business this group belongs to")
    )
    
    name = models.CharField(
        _("group name"),
        max_length=100,
        help_text=_("Name of the display group")
    )
    
    description = models.TextField(
        _("description"),
        blank=True,
        help_text=_("Description of the display group")
    )
    
    displays = models.ManyToManyField(
        Display,
        related_name='groups',
        help_text=_("Displays in this group")
    )
    
    # Group settings
    default_menu = models.ForeignKey(
        'menus.Menu',
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='default_display_groups',
        help_text=_("Default menu for displays in this group")
    )
    
    settings = models.JSONField(
        _("group settings"),
        default=dict,
        blank=True,
        help_text=_("Settings applied to all displays in the group")
    )
    
    is_active = models.BooleanField(
        _("is active"),
        default=True,
        help_text=_("Whether this group is currently active")
    )
    
    created_at = models.DateTimeField(
        _("created at"),
        auto_now_add=True,
        help_text=_("When the group was created")
    )
    
    updated_at = models.DateTimeField(
        _("updated at"),
        auto_now=True,
        help_text=_("When the group was last updated")
    )
    
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='created_display_groups',
        help_text=_("User who created this group")
    )
    
    class Meta:
        verbose_name = _("Display Group")
        verbose_name_plural = _("Display Groups")
        db_table = "displays_group"
        unique_together = [['business', 'name']]
        ordering = ['name']
        indexes = [
            models.Index(fields=['business', 'is_active'], name='group_business_active_idx'),
            models.Index(fields=['created_at'], name='group_created_idx'),
        ]
    
    def __str__(self):
        return f"{self.business.name} - {self.name}"
    
    def clean(self):
        """Validate the display group."""
        super().clean()
        
        # Validate default menu belongs to the same business
        if self.default_menu and self.default_menu.business != self.business:
            raise ValidationError(_("Default menu must belong to the same business."))
    
    def get_display_count(self):
        """Get the number of displays in this group."""
        return self.displays.count()
    
    def get_online_display_count(self):
        """Get the number of online displays in this group."""
        return self.displays.filter(status='online').count()
    
    def assign_menu_to_all(self, menu, user=None):
        """Assign a menu to all displays in the group."""
        if menu.business != self.business:
            raise ValidationError(_("Menu must belong to the same business."))
        
        success_count = 0
        for display in self.displays.filter(is_active=True):
            try:
                display.assign_menu(menu, user)
                success_count += 1
            except ValidationError:
                continue
        
        return success_count
    
    def apply_settings_to_all(self):
        """Apply group settings to all displays in the group."""
        if not self.settings:
            return 0
        
        updated_count = 0
        for display in self.displays.filter(is_active=True):
            # Merge group settings with display settings
            if display.settings:
                display.settings.update(self.settings)
            else:
                display.settings = self.settings.copy()
            
            display.save(update_fields=['settings'])
            updated_count += 1
        
        return updated_count


class DisplaySession(models.Model):
    """
    Model to track active display sessions for monitoring and diagnostics.
    """
    
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )
    
    display = models.ForeignKey(
        Display,
        on_delete=models.CASCADE,
        related_name='sessions',
        help_text=_("Display associated with this session")
    )
    
    session_id = models.CharField(
        _("session ID"),
        max_length=255,
        help_text=_("Unique identifier for this session")
    )
    
    # Session details
    started_at = models.DateTimeField(
        _("started at"),
        auto_now_add=True,
        help_text=_("When the session started")
    )
    
    ended_at = models.DateTimeField(
        _("ended at"),
        blank=True,
        null=True,
        help_text=_("When the session ended")
    )
    
    is_active = models.BooleanField(
        _("is active"),
        default=True,
        help_text=_("Whether this session is currently active")
    )
    
    # Connection information
    ip_address = models.GenericIPAddressField(
        _("IP address"),
        help_text=_("IP address of the display during this session")
    )
    
    user_agent = models.TextField(
        _("user agent"),
        blank=True,
        help_text=_("User agent string from the display")
    )
    
    # Session statistics
    total_uptime_seconds = models.PositiveIntegerField(
        _("total uptime (seconds)"),
        default=0,
        help_text=_("Total uptime for this session in seconds")
    )
    
    heartbeat_count = models.PositiveIntegerField(
        _("heartbeat count"),
        default=0,
        help_text=_("Number of heartbeats received during this session")
    )
    
    error_count = models.PositiveIntegerField(
        _("error count"),
        default=0,
        help_text=_("Number of errors during this session")
    )
    
    # Menu tracking
    menus_displayed = models.JSONField(
        _("menus displayed"),
        default=list,
        help_text=_("List of menus displayed during this session")
    )
    
    # Performance metrics
    performance_data = models.JSONField(
        _("performance data"),
        default=dict,
        blank=True,
        help_text=_("Performance metrics collected during this session")
    )
    
    class Meta:
        verbose_name = _("Display Session")
        verbose_name_plural = _("Display Sessions")
        db_table = "displays_session"
        ordering = ['-started_at']
        indexes = [
            models.Index(fields=['display', 'is_active'], name='session_display_active_idx'),
            models.Index(fields=['started_at'], name='session_started_idx'),
            models.Index(fields=['session_id'], name='session_id_idx'),
        ]
    
    def __str__(self):
        return f"{self.display.name} - {self.started_at}"
    
    def end_session(self):
        """End the current session."""
        from django.utils import timezone
        
        if self.is_active:
            self.ended_at = timezone.now()
            self.is_active = False
            
            # Calculate total uptime
            if self.started_at:
                uptime = self.ended_at - self.started_at
                self.total_uptime_seconds = int(uptime.total_seconds())
            
            self.save(update_fields=['ended_at', 'is_active', 'total_uptime_seconds'])
    
    def record_heartbeat(self):
        """Record a heartbeat for this session."""
        self.heartbeat_count += 1
        self.save(update_fields=['heartbeat_count'])
    
    def record_error(self):
        """Record an error for this session."""
        self.error_count += 1
        self.save(update_fields=['error_count'])
    
    def add_menu_display(self, menu):
        """Add a menu to the list of displayed menus."""
        from django.utils import timezone
        
        menu_data = {
            'menu_id': str(menu.id),
            'menu_name': menu.name,
            'displayed_at': timezone.now().isoformat()
        }
        
        if not self.menus_displayed:
            self.menus_displayed = []
        
        self.menus_displayed.append(menu_data)
        self.save(update_fields=['menus_displayed'])
    
    def get_session_duration(self):
        """Get the duration of the session."""
        from django.utils import timezone
        
        end_time = self.ended_at if self.ended_at else timezone.now()
        duration = end_time - self.started_at
        return duration
    
    def get_uptime_percentage(self):
        """Calculate uptime percentage based on heartbeats."""
        if not self.heartbeat_count:
            return 0
        
        total_duration = self.get_session_duration()
        expected_heartbeats = total_duration.total_seconds() / 30  # Assuming 30-second intervals
        
        if expected_heartbeats <= 0:
            return 100
        
        uptime_percentage = (self.heartbeat_count / expected_heartbeats) * 100
        return min(100, uptime_percentage)