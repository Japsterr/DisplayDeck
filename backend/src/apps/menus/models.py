# Menu models for DisplayDeck - digital menu management

import uuid
from django.db import models
from django.utils.translation import gettext_lazy as _
from django.core.validators import MinValueValidator, MaxValueValidator, RegexValidator
from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from decimal import Decimal


User = get_user_model()


class MenuCategory(models.Model):
    """
    Model representing a menu category (e.g., Burgers, Drinks, Sides).
    Categories help organize menu items and can be nested.
    """
    
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        help_text=_("Unique identifier for the category")
    )
    
    business = models.ForeignKey(
        'businesses.Business',
        on_delete=models.CASCADE,
        related_name='menu_categories',
        help_text=_("Business this category belongs to")
    )
    
    name = models.CharField(
        _("category name"),
        max_length=100,
        help_text=_("Name of the menu category")
    )
    
    slug = models.SlugField(
        _("slug"),
        max_length=100,
        help_text=_("URL-friendly identifier for the category")
    )
    
    description = models.TextField(
        _("description"),
        blank=True,
        help_text=_("Optional description of the category")
    )
    
    # Category hierarchy
    parent = models.ForeignKey(
        'self',
        on_delete=models.CASCADE,
        blank=True,
        null=True,
        related_name='subcategories',
        help_text=_("Parent category for nested categories")
    )
    
    # Display settings
    image = models.ImageField(
        _("category image"),
        upload_to="menu_categories/",
        blank=True,
        null=True,
        help_text=_("Image to represent this category")
    )
    
    icon = models.CharField(
        _("icon"),
        max_length=50,
        blank=True,
        help_text=_("Icon identifier (e.g., for icon fonts)")
    )
    
    color = models.CharField(
        _("color"),
        max_length=7,
        blank=True,
        validators=[RegexValidator(r'^#[0-9a-fA-F]{6}$')],
        help_text=_("Category color in hex format (#RRGGBB)")
    )
    
    # Ordering and visibility
    sort_order = models.PositiveIntegerField(
        _("sort order"),
        default=0,
        help_text=_("Order in which categories appear (lower numbers first)")
    )
    
    is_active = models.BooleanField(
        _("is active"),
        default=True,
        help_text=_("Whether this category is currently visible")
    )
    
    is_featured = models.BooleanField(
        _("is featured"),
        default=False,
        help_text=_("Whether to highlight this category prominently")
    )
    
    # Availability scheduling
    available_from = models.TimeField(
        _("available from"),
        blank=True,
        null=True,
        help_text=_("Time when category becomes available each day")
    )
    
    available_until = models.TimeField(
        _("available until"),
        blank=True,
        null=True,
        help_text=_("Time when category becomes unavailable each day")
    )
    
    # Days of week availability (JSON array)
    available_days = models.JSONField(
        _("available days"),
        default=list,
        help_text=_("Days of the week when category is available (0=Monday)")
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        _("created at"),
        auto_now_add=True,
        help_text=_("When the category was created")
    )
    
    updated_at = models.DateTimeField(
        _("updated at"),
        auto_now=True,
        help_text=_("When the category was last updated")
    )
    
    class Meta:
        verbose_name = _("Menu Category")
        verbose_name_plural = _("Menu Categories")
        db_table = "menus_category"
        unique_together = [['business', 'slug']]
        ordering = ['sort_order', 'name']
        indexes = [
            models.Index(fields=['business', 'is_active'], name='category_business_active_idx'),
            models.Index(fields=['parent'], name='category_parent_idx'),
            models.Index(fields=['sort_order'], name='category_sort_idx'),
            models.Index(fields=['is_featured'], name='category_featured_idx'),
        ]
    
    def __str__(self):
        if self.parent:
            return f"{self.parent.name} > {self.name}"
        return self.name
    
    def get_full_path(self):
        """Get the full category path (e.g., 'Food > Burgers > Specialty')."""
        path = [self.name]
        parent = self.parent
        while parent:
            path.insert(0, parent.name)
            parent = parent.parent
        return ' > '.join(path)
    
    def get_level(self):
        """Get the nesting level of this category (0 = root)."""
        level = 0
        parent = self.parent
        while parent:
            level += 1
            parent = parent.parent
        return level
    
    def get_descendants(self):
        """Get all descendant categories."""
        descendants = []
        for child in self.subcategories.all():
            descendants.append(child)
            descendants.extend(child.get_descendants())
        return descendants
    
    def clean(self):
        """Validate the category."""
        super().clean()
        
        # Prevent circular references
        if self.parent:
            parent = self.parent
            while parent:
                if parent == self:
                    raise ValidationError(_("A category cannot be its own ancestor."))
                parent = parent.parent
        
        # Validate business consistency with parent
        if self.parent and self.parent.business != self.business:
            raise ValidationError(_("Parent category must belong to the same business."))
        
        # Validate availability times
        if (self.available_from and self.available_until and 
            self.available_from >= self.available_until):
            raise ValidationError(_("Available from time must be before available until time."))
    
    def save(self, *args, **kwargs):
        """Override save to generate slug if not provided."""
        if not self.slug:
            from django.utils.text import slugify
            base_slug = slugify(self.name)
            slug = base_slug
            counter = 1
            while MenuCategory.objects.filter(
                business=self.business, slug=slug
            ).exclude(pk=self.pk).exists():
                slug = f"{base_slug}-{counter}"
                counter += 1
            self.slug = slug
        
        super().save(*args, **kwargs)
    
    def get_active_items_count(self):
        """Get the number of active menu items in this category."""
        return self.menu_items.filter(is_active=True).count()
    
    def is_available_now(self):
        """Check if the category is available at the current time."""
        from django.utils import timezone
        
        if not self.is_active:
            return False
        
        now = timezone.now()
        current_time = now.time()
        current_weekday = now.weekday()  # 0 = Monday
        
        # Check day availability
        if self.available_days and current_weekday not in self.available_days:
            return False
        
        # Check time availability
        if self.available_from and current_time < self.available_from:
            return False
        
        if self.available_until and current_time > self.available_until:
            return False
        
        return True


class Menu(models.Model):
    """
    Model representing a complete menu for a business.
    Businesses can have multiple menus (e.g., breakfast, lunch, dinner).
    """
    
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        help_text=_("Unique identifier for the menu")
    )
    
    business = models.ForeignKey(
        'businesses.Business',
        on_delete=models.CASCADE,
        related_name='menus',
        help_text=_("Business this menu belongs to")
    )
    
    name = models.CharField(
        _("menu name"),
        max_length=100,
        help_text=_("Name of the menu (e.g., 'Breakfast Menu', 'Lunch Specials')")
    )
    
    slug = models.SlugField(
        _("slug"),
        max_length=100,
        help_text=_("URL-friendly identifier for the menu")
    )
    
    description = models.TextField(
        _("description"),
        blank=True,
        help_text=_("Optional description of the menu")
    )
    
    # Menu type and settings
    MENU_TYPE_CHOICES = [
        ('main', _('Main Menu')),
        ('breakfast', _('Breakfast Menu')),
        ('lunch', _('Lunch Menu')),
        ('dinner', _('Dinner Menu')),
        ('drinks', _('Drinks Menu')),
        ('desserts', _('Desserts Menu')),
        ('specials', _('Daily Specials')),
        ('seasonal', _('Seasonal Menu')),
        ('catering', _('Catering Menu')),
        ('kids', _('Kids Menu')),
    ]
    
    menu_type = models.CharField(
        _("menu type"),
        max_length=20,
        choices=MENU_TYPE_CHOICES,
        default='main',
        help_text=_("Type of menu")
    )
    
    # Versioning for menu updates
    version = models.CharField(
        _("version"),
        max_length=20,
        default='1.0.0',
        help_text=_("Menu version for tracking changes")
    )
    
    version_notes = models.TextField(
        _("version notes"),
        blank=True,
        help_text=_("Notes about changes in this version")
    )
    
    # Display settings
    background_image = models.ImageField(
        _("background image"),
        upload_to="menu_backgrounds/",
        blank=True,
        null=True,
        help_text=_("Background image for the menu display")
    )
    
    theme_color = models.CharField(
        _("theme color"),
        max_length=7,
        blank=True,
        validators=[RegexValidator(r'^#[0-9a-fA-F]{6}$')],
        help_text=_("Primary theme color in hex format (#RRGGBB)")
    )
    
    layout = models.CharField(
        _("layout"),
        max_length=20,
        choices=[
            ('grid', _('Grid Layout')),
            ('list', _('List Layout')),
            ('card', _('Card Layout')),
            ('magazine', _('Magazine Layout')),
        ],
        default='grid',
        help_text=_("Display layout for the menu")
    )
    
    # Availability and scheduling
    is_active = models.BooleanField(
        _("is active"),
        default=True,
        help_text=_("Whether this menu is currently active")
    )
    
    is_default = models.BooleanField(
        _("is default"),
        default=False,
        help_text=_("Whether this is the default menu for the business")
    )
    
    available_from = models.TimeField(
        _("available from"),
        blank=True,
        null=True,
        help_text=_("Time when menu becomes available each day")
    )
    
    available_until = models.TimeField(
        _("available until"),
        blank=True,
        null=True,
        help_text=_("Time when menu becomes unavailable each day")
    )
    
    available_days = models.JSONField(
        _("available days"),
        default=list,
        help_text=_("Days of the week when menu is available (0=Monday)")
    )
    
    # Menu metadata
    total_items = models.PositiveIntegerField(
        _("total items"),
        default=0,
        help_text=_("Cached count of total menu items")
    )
    
    last_updated_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='updated_menus',
        help_text=_("User who last updated this menu")
    )
    
    # Timestamps
    created_at = models.DateTimeField(
        _("created at"),
        auto_now_add=True,
        help_text=_("When the menu was created")
    )
    
    updated_at = models.DateTimeField(
        _("updated at"),
        auto_now=True,
        help_text=_("When the menu was last updated")
    )
    
    published_at = models.DateTimeField(
        _("published at"),
        blank=True,
        null=True,
        help_text=_("When the menu was published to displays")
    )
    
    class Meta:
        verbose_name = _("Menu")
        verbose_name_plural = _("Menus")
        db_table = "menus_menu"
        unique_together = [['business', 'slug']]
        ordering = ['-is_default', 'name']
        indexes = [
            models.Index(fields=['business', 'is_active'], name='menu_business_active_idx'),
            models.Index(fields=['menu_type'], name='menu_type_idx'),
            models.Index(fields=['is_default'], name='menu_default_idx'),
            models.Index(fields=['published_at'], name='menu_published_idx'),
        ]
        constraints = [
            # Only one default menu per business
            models.UniqueConstraint(
                fields=['business'],
                condition=models.Q(is_default=True),
                name='one_default_menu_per_business'
            ),
        ]
    
    def __str__(self):
        return f"{self.business.name} - {self.name}"
    
    def clean(self):
        """Validate the menu."""
        super().clean()
        
        # Validate availability times
        if (self.available_from and self.available_until and 
            self.available_from >= self.available_until):
            raise ValidationError(_("Available from time must be before available until time."))
    
    def save(self, *args, **kwargs):
        """Override save to handle slug generation and default menu logic."""
        if not self.slug:
            from django.utils.text import slugify
            base_slug = slugify(self.name)
            slug = base_slug
            counter = 1
            while Menu.objects.filter(
                business=self.business, slug=slug
            ).exclude(pk=self.pk).exists():
                slug = f"{base_slug}-{counter}"
                counter += 1
            self.slug = slug
        
        # Ensure only one default menu per business
        if self.is_default:
            Menu.objects.filter(
                business=self.business, is_default=True
            ).exclude(pk=self.pk).update(is_default=False)
        
        super().save(*args, **kwargs)
        
        # Update total items count
        self.update_total_items_count()
    
    def update_total_items_count(self):
        """Update the cached total items count."""
        total = self.menu_items.filter(is_active=True).count()
        if total != self.total_items:
            Menu.objects.filter(pk=self.pk).update(total_items=total)
    
    def get_categories(self):
        """Get all categories used by items in this menu."""
        return MenuCategory.objects.filter(
            menu_items__menu=self
        ).distinct().order_by('sort_order', 'name')
    
    def get_items_by_category(self):
        """Get menu items grouped by category."""
        from collections import defaultdict
        
        items_by_category = defaultdict(list)
        items = self.menu_items.filter(is_active=True).select_related('category')
        
        for item in items:
            category_name = item.category.name if item.category else _('Uncategorized')
            items_by_category[category_name].append(item)
        
        return dict(items_by_category)
    
    def is_available_now(self):
        """Check if the menu is available at the current time."""
        from django.utils import timezone
        
        if not self.is_active:
            return False
        
        now = timezone.now()
        current_time = now.time()
        current_weekday = now.weekday()  # 0 = Monday
        
        # Check day availability
        if self.available_days and current_weekday not in self.available_days:
            return False
        
        # Check time availability
        if self.available_from and current_time < self.available_from:
            return False
        
        if self.available_until and current_time > self.available_until:
            return False
        
        return True
    
    def publish(self, user=None):
        """Publish the menu to displays."""
        from django.utils import timezone
        
        self.published_at = timezone.now()
        self.last_updated_by = user
        self.save(update_fields=['published_at', 'last_updated_by'])
        
        # Signal displays to update
        # This will be handled by WebSocket notifications in the views
    
    def clone(self, new_name, user=None):
        """Create a copy of this menu with all its items."""
        new_menu = Menu.objects.create(
            business=self.business,
            name=new_name,
            description=f"Copy of {self.name}",
            menu_type=self.menu_type,
            theme_color=self.theme_color,
            layout=self.layout,
            available_from=self.available_from,
            available_until=self.available_until,
            available_days=self.available_days.copy(),
            last_updated_by=user,
        )
        
        # Copy all menu items
        for item in self.menu_items.all():
            item.clone(new_menu)
        
        return new_menu


class MenuItem(models.Model):
    """
    Model representing an individual menu item (food/drink item).
    """
    
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        help_text=_("Unique identifier for the menu item")
    )
    
    menu = models.ForeignKey(
        Menu,
        on_delete=models.CASCADE,
        related_name='menu_items',
        help_text=_("Menu this item belongs to")
    )
    
    category = models.ForeignKey(
        MenuCategory,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='menu_items',
        help_text=_("Category this item belongs to")
    )
    
    # Basic item information
    name = models.CharField(
        _("item name"),
        max_length=100,
        help_text=_("Name of the menu item")
    )
    
    slug = models.SlugField(
        _("slug"),
        max_length=100,
        help_text=_("URL-friendly identifier for the item")
    )
    
    description = models.TextField(
        _("description"),
        blank=True,
        help_text=_("Description of the menu item")
    )
    
    short_description = models.CharField(
        _("short description"),
        max_length=255,
        blank=True,
        help_text=_("Brief description for compact displays")
    )
    
    # Pricing
    price = models.DecimalField(
        _("price"),
        max_digits=8,
        decimal_places=2,
        validators=[MinValueValidator(Decimal('0.01'))],
        help_text=_("Price of the menu item")
    )
    
    compare_at_price = models.DecimalField(
        _("compare at price"),
        max_digits=8,
        decimal_places=2,
        blank=True,
        null=True,
        help_text=_("Original price (for showing discounts)")
    )
    
    cost_price = models.DecimalField(
        _("cost price"),
        max_digits=8,
        decimal_places=2,
        blank=True,
        null=True,
        help_text=_("Cost price for profit margin calculations")
    )
    
    # Item attributes
    ITEM_TYPE_CHOICES = [
        ('food', _('Food')),
        ('drink', _('Drink')),
        ('combo', _('Combo/Meal')),
        ('side', _('Side Item')),
        ('dessert', _('Dessert')),
        ('appetizer', _('Appetizer')),
    ]
    
    item_type = models.CharField(
        _("item type"),
        max_length=20,
        choices=ITEM_TYPE_CHOICES,
        default='food',
        help_text=_("Type of menu item")
    )
    
    # Nutritional information
    calories = models.PositiveIntegerField(
        _("calories"),
        blank=True,
        null=True,
        help_text=_("Caloric content")
    )
    
    prep_time_minutes = models.PositiveIntegerField(
        _("preparation time (minutes)"),
        blank=True,
        null=True,
        validators=[MaxValueValidator(999)],
        help_text=_("Time required to prepare this item")
    )
    
    # Dietary information (JSON field for flexibility)
    dietary_info = models.JSONField(
        _("dietary information"),
        default=dict,
        blank=True,
        help_text=_("Dietary restrictions and allergen information")
    )
    
    # Popular tags (vegetarian, spicy, gluten-free, etc.)
    tags = models.JSONField(
        _("tags"),
        default=list,
        blank=True,
        help_text=_("Tags for filtering and search (e.g., 'spicy', 'vegetarian')")
    )
    
    # Images
    image = models.ImageField(
        _("item image"),
        upload_to="menu_items/",
        blank=True,
        null=True,
        help_text=_("Main image of the menu item")
    )
    
    gallery_images = models.JSONField(
        _("gallery images"),
        default=list,
        blank=True,
        help_text=_("Additional images for this item")
    )
    
    # Availability and ordering
    is_active = models.BooleanField(
        _("is active"),
        default=True,
        help_text=_("Whether this item is currently available")
    )
    
    is_featured = models.BooleanField(
        _("is featured"),
        default=False,
        help_text=_("Whether to highlight this item prominently")
    )
    
    is_popular = models.BooleanField(
        _("is popular"),
        default=False,
        help_text=_("Whether this is a popular/bestselling item")
    )
    
    sort_order = models.PositiveIntegerField(
        _("sort order"),
        default=0,
        help_text=_("Order in which items appear (lower numbers first)")
    )
    
    # Stock and availability
    track_inventory = models.BooleanField(
        _("track inventory"),
        default=False,
        help_text=_("Whether to track inventory for this item")
    )
    
    inventory_count = models.PositiveIntegerField(
        _("inventory count"),
        default=0,
        help_text=_("Current inventory count")
    )
    
    low_stock_threshold = models.PositiveIntegerField(
        _("low stock threshold"),
        default=5,
        help_text=_("Alert when inventory falls below this level")
    )
    
    # Time-based availability
    available_from = models.TimeField(
        _("available from"),
        blank=True,
        null=True,
        help_text=_("Time when item becomes available each day")
    )
    
    available_until = models.TimeField(
        _("available until"),
        blank=True,
        null=True,
        help_text=_("Time when item becomes unavailable each day")
    )
    
    available_days = models.JSONField(
        _("available days"),
        default=list,
        help_text=_("Days of the week when item is available (0=Monday)")
    )
    
    # Customization options (JSON for flexibility)
    customization_options = models.JSONField(
        _("customization options"),
        default=dict,
        blank=True,
        help_text=_("Available customizations (sizes, add-ons, etc.)")
    )
    
    # Timestamps and tracking
    created_at = models.DateTimeField(
        _("created at"),
        auto_now_add=True,
        help_text=_("When the item was created")
    )
    
    updated_at = models.DateTimeField(
        _("updated at"),
        auto_now=True,
        help_text=_("When the item was last updated")
    )
    
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='created_menu_items',
        help_text=_("User who created this item")
    )
    
    last_updated_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='updated_menu_items',
        help_text=_("User who last updated this item")
    )
    
    class Meta:
        verbose_name = _("Menu Item")
        verbose_name_plural = _("Menu Items")
        db_table = "menus_item"
        unique_together = [['menu', 'slug']]
        ordering = ['category__sort_order', 'sort_order', 'name']
        indexes = [
            models.Index(fields=['menu', 'is_active'], name='item_menu_active_idx'),
            models.Index(fields=['category'], name='item_category_idx'),
            models.Index(fields=['is_featured'], name='item_featured_idx'),
            models.Index(fields=['is_popular'], name='item_popular_idx'),
            models.Index(fields=['sort_order'], name='item_sort_idx'),
            models.Index(fields=['price'], name='item_price_idx'),
        ]
    
    def __str__(self):
        return f"{self.menu.name} - {self.name}"
    
    def clean(self):
        """Validate the menu item."""
        super().clean()
        
        # Validate category belongs to same business
        if self.category and self.category.business != self.menu.business:
            raise ValidationError(_("Category must belong to the same business as the menu."))
        
        # Validate availability times
        if (self.available_from and self.available_until and 
            self.available_from >= self.available_until):
            raise ValidationError(_("Available from time must be before available until time."))
        
        # Validate compare at price
        if self.compare_at_price and self.compare_at_price <= self.price:
            raise ValidationError(_("Compare at price must be higher than the regular price."))
        
        # Validate inventory settings
        if self.track_inventory and self.inventory_count < 0:
            raise ValidationError(_("Inventory count cannot be negative."))
    
    def save(self, *args, **kwargs):
        """Override save to handle slug generation and inventory alerts."""
        if not self.slug:
            from django.utils.text import slugify
            base_slug = slugify(self.name)
            slug = base_slug
            counter = 1
            while MenuItem.objects.filter(
                menu=self.menu, slug=slug
            ).exclude(pk=self.pk).exists():
                slug = f"{base_slug}-{counter}"
                counter += 1
            self.slug = slug
        
        super().save(*args, **kwargs)
        
        # Update menu's total items count
        self.menu.update_total_items_count()
    
    def is_available_now(self):
        """Check if the item is available at the current time."""
        from django.utils import timezone
        
        if not self.is_active:
            return False
        
        # Check inventory
        if self.track_inventory and self.inventory_count <= 0:
            return False
        
        now = timezone.now()
        current_time = now.time()
        current_weekday = now.weekday()  # 0 = Monday
        
        # Check day availability
        if self.available_days and current_weekday not in self.available_days:
            return False
        
        # Check time availability
        if self.available_from and current_time < self.available_from:
            return False
        
        if self.available_until and current_time > self.available_until:
            return False
        
        # Check category availability
        if self.category and not self.category.is_available_now():
            return False
        
        return True
    
    def is_low_stock(self):
        """Check if the item is running low on stock."""
        if not self.track_inventory:
            return False
        return self.inventory_count <= self.low_stock_threshold
    
    def is_out_of_stock(self):
        """Check if the item is out of stock."""
        if not self.track_inventory:
            return False
        return self.inventory_count <= 0
    
    def get_profit_margin(self):
        """Calculate profit margin percentage."""
        if not self.cost_price or self.cost_price <= 0:
            return None
        
        profit = self.price - self.cost_price
        margin = (profit / self.price) * 100
        return round(margin, 2)
    
    def get_discount_percentage(self):
        """Calculate discount percentage if compare_at_price is set."""
        if not self.compare_at_price or self.compare_at_price <= self.price:
            return None
        
        discount = ((self.compare_at_price - self.price) / self.compare_at_price) * 100
        return round(discount, 2)
    
    def clone(self, new_menu):
        """Create a copy of this item for a different menu."""
        return MenuItem.objects.create(
            menu=new_menu,
            category=self.category if self.category.business == new_menu.business else None,
            name=self.name,
            description=self.description,
            short_description=self.short_description,
            price=self.price,
            compare_at_price=self.compare_at_price,
            cost_price=self.cost_price,
            item_type=self.item_type,
            calories=self.calories,
            prep_time_minutes=self.prep_time_minutes,
            dietary_info=self.dietary_info.copy(),
            tags=self.tags.copy(),
            sort_order=self.sort_order,
            track_inventory=False,  # Don't copy inventory settings
            available_from=self.available_from,
            available_until=self.available_until,
            available_days=self.available_days.copy(),
            customization_options=self.customization_options.copy(),
        )
    
    def decrease_inventory(self, quantity=1):
        """Decrease inventory count (for order processing)."""
        if self.track_inventory:
            self.inventory_count = max(0, self.inventory_count - quantity)
            self.save(update_fields=['inventory_count'])
    
    def increase_inventory(self, quantity=1):
        """Increase inventory count (for restocking)."""
        if self.track_inventory:
            self.inventory_count += quantity
            self.save(update_fields=['inventory_count'])