# DisplayDeck User Manual

## Table of Contents

1. [Getting Started](#getting-started)
2. [Business Management](#business-management) 
3. [Menu Management](#menu-management)
4. [Display Management](#display-management)
5. [User Management](#user-management)
6. [Mobile App Guide](#mobile-app-guide)
7. [Troubleshooting](#troubleshooting)

## Getting Started

### Logging In

#### Web Dashboard
1. Navigate to your DisplayDeck URL (e.g., `https://yourrestaurant.displaydeck.com`)
2. Enter your email and password
3. Click "Sign In"

#### Mobile App
1. Open the DisplayDeck mobile app
2. Enter your business URL or select from the list
3. Use your email/password or biometric authentication (if enabled)

### Dashboard Overview

The main dashboard provides:
- **Menu Status**: Quick overview of active menus and recent changes
- **Display Status**: Real-time status of all connected displays
- **Recent Activity**: Latest updates and user actions
- **Quick Actions**: Common tasks like updating prices or adding items

## Business Management

### Business Profile

#### Updating Business Information
1. Go to **Settings** → **Business Profile**
2. Update information:
   - Business name and description
   - Contact information (email, phone)
   - Address and timezone
   - Business hours
3. Click **Save Changes**

#### Business Types
- **Fast Food**: Quick service restaurants, burger joints, pizza places
- **Cafe**: Coffee shops, bakeries, light meal establishments  
- **Restaurant**: Full-service dining establishments
- **Food Truck**: Mobile food service
- **Other**: Custom business types

### Subscription Management

#### Plan Features
- **Starter**: Up to 3 displays, basic features
- **Professional**: Up to 15 displays, advanced analytics
- **Enterprise**: Unlimited displays, custom features

#### Upgrading Your Plan
1. Go to **Settings** → **Subscription**
2. Select your desired plan
3. Enter payment information
4. Confirm upgrade

## Menu Management

### Creating Your First Menu

#### Step 1: Menu Basics
1. Navigate to **Menus** → **Create New Menu**
2. Enter menu details:
   - **Name**: e.g., "Lunch Menu", "Breakfast Specials"
   - **Description**: Brief description of the menu
   - **Active Hours**: When this menu should be displayed
3. Click **Create Menu**

#### Step 2: Add Categories
1. In your new menu, click **Add Category**
2. Enter category information:
   - **Name**: e.g., "Burgers", "Sides", "Beverages"
   - **Description**: Optional description
   - **Display Order**: Controls the order categories appear
3. Click **Add Category**

#### Step 3: Add Menu Items
1. Click on a category to add items
2. Click **Add Item**
3. Fill in item details:
   - **Name**: Item name as it appears to customers
   - **Description**: Detailed description
   - **Price**: Current price (can include multiple sizes)
   - **Image**: Upload high-quality image (recommended 800x600px)
   - **Dietary Info**: Vegetarian, vegan, gluten-free, etc.
   - **Allergen Info**: Common allergens present
   - **Availability**: Currently available or sold out

### Menu Design and Styling

#### Customizing Appearance
1. Go to **Menu Design** in your menu editor
2. Customize:
   - **Colors**: Background, text, accent colors
   - **Fonts**: Choose from available font families
   - **Layout**: Grid vs. list view, spacing options
   - **Logo**: Upload your business logo

#### Best Practices for Menu Design
- **High-Quality Images**: Use clear, appetizing photos
- **Consistent Styling**: Keep colors and fonts uniform
- **Clear Pricing**: Make prices easy to read
- **Logical Grouping**: Group similar items together
- **Seasonal Updates**: Update seasonal items regularly

### Managing Menu Items

#### Updating Prices
**Quick Price Update:**
1. Go to **Menus** → Select your menu
2. Find the item and click the price field
3. Enter new price
4. Press Enter or click outside to save
5. Changes sync to displays immediately

**Bulk Price Updates:**
1. Select multiple items using checkboxes
2. Click **Bulk Actions** → **Update Prices**
3. Choose:
   - **Fixed Amount**: Add/subtract specific amount
   - **Percentage**: Increase/decrease by percentage
4. Click **Apply Changes**

#### Managing Item Availability
**Mark Items as Sold Out:**
1. Find the item in your menu
2. Click the **Available** toggle to mark as sold out
3. Item appears grayed out on displays with "Sold Out" indicator

**Temporary Items:**
1. Create items with specific start/end dates
2. Use for daily specials or limited-time offers
3. Items automatically appear/disappear on schedule

#### Image Management
**Uploading Images:**
1. Click **Edit Item** → **Upload Image**
2. Choose high-resolution image (recommended: 800x600px, under 5MB)
3. Crop and adjust as needed
4. Click **Save**

**Image Requirements:**
- Format: JPG, PNG, or WebP
- Size: Maximum 5MB
- Recommended resolution: 800x600px or 1200x900px
- Aspect ratio: 4:3 or 16:9 for best display

### Menu Scheduling

#### Setting Menu Hours
1. Edit your menu
2. Go to **Schedule** tab
3. Set active hours for each day
4. Options:
   - **All Day**: Menu available 24/7
   - **Custom Hours**: Specific start/end times
   - **Closed**: Menu not available on certain days

#### Multiple Menu Management
**Use Cases:**
- Breakfast, lunch, and dinner menus
- Seasonal menus
- Special event menus
- Happy hour menus

**Setup:**
1. Create separate menus for each time period
2. Set appropriate schedules for each
3. Assign to displays as needed

## Display Management

### Adding New Displays

#### Android TV Displays
1. Install DisplayDeck app on Android TV device
2. Open app and note the pairing QR code
3. In web dashboard: **Displays** → **Add Display**
4. Scan QR code or enter pairing code manually
5. Assign display name and location
6. Assign menu to display

#### Web Displays (Browser-based)
1. Go to **Displays** → **Add Display**
2. Select **Web Display** type
3. Note the display URL provided
4. Open URL in full-screen browser on display device
5. Configure display settings as needed

### Display Configuration

#### Basic Settings
- **Display Name**: Easy identification (e.g., "Front Counter", "Drive-Thru")
- **Location**: Physical location description
- **Assigned Menu**: Which menu to show
- **Orientation**: Portrait or landscape
- **Brightness**: Auto or manual brightness control

#### Advanced Settings
- **Auto-sleep**: Turn off display during closed hours
- **Update Frequency**: How often to check for menu changes
- **Offline Mode**: Continue showing last menu when disconnected
- **Screen Saver**: Display business info when idle

### Display Groups

#### Creating Display Groups
1. Go to **Displays** → **Groups** → **Create Group**
2. Enter group name (e.g., "Main Dining", "Drive-Thru Lanes")
3. Add displays to the group
4. Configure group settings

#### Group Benefits
- **Synchronized Updates**: Update multiple displays simultaneously
- **Coordinated Promotions**: Show promotions across all displays in group
- **Centralized Management**: Manage multiple displays as one unit

### Display Monitoring

#### Real-Time Status
The display dashboard shows:
- **Online/Offline Status**: Green (online) or red (offline)
- **Last Seen**: When display last communicated
- **Current Menu**: Which menu is currently displayed
- **System Health**: Battery, memory usage, connection quality

#### Health Alerts
Automatic alerts for:
- Display goes offline
- Low battery (for battery-powered displays)
- Poor connection quality
- System errors

### Display Troubleshooting

#### Display Won't Connect
1. Check internet connection on display device
2. Verify pairing code hasn't expired
3. Restart DisplayDeck app
4. Re-pair if necessary

#### Menu Not Updating
1. Check display status in dashboard
2. Force refresh from display settings
3. Verify menu is assigned to display
4. Check for any error messages

#### Poor Display Quality
1. Adjust display resolution in settings
2. Check internet connection speed
3. Optimize images (reduce file sizes)
4. Update DisplayDeck app

## User Management

### User Roles

#### Owner
- Full access to all features
- Business settings management
- User management
- Billing and subscription
- Can delete business account

#### Manager  
- Menu management (create, edit, delete)
- Display management
- View analytics and reports
- Cannot manage users or billing

#### Staff
- View menus and displays
- Update item availability
- Basic display monitoring
- Cannot create or delete content

### Inviting Users

#### Adding Team Members
1. Go to **Settings** → **Users** → **Invite User**
2. Enter email address
3. Select role (Manager or Staff)
4. Add personal message (optional)
5. Click **Send Invitation**

#### User receives:
- Email invitation with setup link
- Temporary password (must be changed on first login)
- Access to assigned business

### Managing User Permissions

#### Customizing Permissions
1. Go to **Settings** → **Users**
2. Click on user to edit
3. Adjust permissions:
   - Menu editing rights
   - Display management access
   - Analytics viewing
   - User invitation abilities

#### Removing Users
1. Find user in user list
2. Click **Actions** → **Remove User**
3. Confirm removal
4. User immediately loses access

## Mobile App Guide

### Installation and Setup

#### Download and Install
- **iOS**: Download from App Store
- **Android**: Download from Google Play Store
- Search for "DisplayDeck Business"

#### First-Time Setup
1. Open app and tap **Get Started**
2. Enter your business URL or select from list
3. Sign in with your credentials
4. Enable biometric authentication (optional but recommended)
5. Allow notifications for display alerts

### Mobile App Features

#### Dashboard
- Quick menu status overview
- Display status indicators  
- Recent activity feed
- Quick action buttons

#### Menu Management
**Quick Price Updates:**
1. Tap **Menus**
2. Find item and tap price
3. Enter new price
4. Tap **Save** - updates sync immediately

**Item Availability:**
1. Tap **Menus** → Select menu
2. Toggle items on/off for availability
3. Changes appear on displays instantly

#### Display Control
**Monitor Displays:**
- View all displays and their status
- Tap display for detailed information
- Receive push notifications for issues

**Remote Control:**
- Restart displays remotely
- Force menu updates
- Adjust display brightness

#### Offline Functionality
The mobile app works offline for:
- Viewing current menu data
- Making price changes (sync when reconnected)
- Viewing display status (last known state)
- Basic business information

### Mobile App Tips

#### Notifications
Enable notifications for:
- Display connectivity issues
- System alerts and errors
- Menu update confirmations
- User activity (optional)

#### Quick Actions
Use widget or shortcuts for:
- Mark items sold out
- Update daily specials
- Check display status
- Emergency display restart

## Troubleshooting

### Common Issues

#### Login Problems
**Forgot Password:**
1. Click **Forgot Password** on login screen
2. Enter email address
3. Check email for reset link
4. Create new password

**Account Locked:**
- Contact your business owner or admin
- They can unlock your account in user management

#### Menu Not Displaying
**Check Menu Status:**
1. Verify menu is marked as "Active"
2. Check menu schedule (is it within active hours?)
3. Confirm menu is assigned to display
4. Force refresh display

**Image Issues:**
1. Check image file size (must be under 5MB)
2. Verify image format (JPG, PNG, WebP only)
3. Try uploading different image
4. Clear browser cache and retry

#### Display Connection Issues
**Display Shows "Connecting":**
1. Check internet connection on display device
2. Restart DisplayDeck app
3. Verify pairing hasn't expired
4. Contact support if issue persists

**Display Shows Old Menu:**
1. Force refresh from display settings
2. Check if newer menu is assigned
3. Restart display app
4. Verify display has internet connection

#### Performance Issues
**App Running Slowly:**
1. Close other apps on device
2. Restart DisplayDeck app
3. Check internet connection speed
4. Update to latest app version

**Changes Not Syncing:**
1. Check internet connection
2. Force refresh displays
3. Verify user permissions
4. Check for system maintenance notifications

### Getting Help

#### In-App Help
- Tap **Help** in any screen for context-specific guidance
- Use **Search** to find specific topics
- Access video tutorials and guides

#### Contact Support
- **Email**: support@displaydeck.com
- **Phone**: Available for Enterprise customers
- **Live Chat**: Available during business hours
- **Help Center**: help.displaydeck.com

#### Emergency Support
For urgent issues (displays down during business hours):
- Use **Emergency Contact** button in mobile app
- Priority response within 1 hour during business hours
- Available 24/7 for Enterprise customers

### Best Practices

#### Daily Routine
1. **Morning**: Check display status, update daily specials
2. **Throughout Day**: Monitor item availability, adjust as needed
3. **Evening**: Review day's activity, prepare tomorrow's updates

#### Weekly Maintenance
1. Review menu performance analytics
2. Update seasonal items
3. Check and update business information
4. Review user access and permissions

#### Monthly Tasks
1. Analyze customer preferences from analytics
2. Plan seasonal menu updates
3. Review display placement and effectiveness
4. Update team training on new features

---

For additional help and advanced features, visit our [Help Center](https://help.displaydeck.com) or contact support.