import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';
import { Platform, Alert } from 'react-native';

// Configure notification handling
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});

export interface NotificationData {
  type: 'display_offline' | 'display_online' | 'menu_updated' | 'system_alert';
  displayId?: string;
  displayName?: string;
  menuId?: string;
  menuName?: string;
  message: string;
  timestamp: string;
}

export interface LocalNotificationOptions {
  title: string;
  body: string;
  data?: any;
  sound?: boolean;
  badge?: number;
  priority?: 'default' | 'low' | 'high' | 'max';
}

class NotificationService {
  private expoPushToken: string | null = null;
  private isInitialized = false;

  async initialize() {
    if (this.isInitialized) return;

    try {
      // Request permissions
      const { status: existingStatus } = await Notifications.getPermissionsAsync();
      let finalStatus = existingStatus;

      if (existingStatus !== 'granted') {
        const { status } = await Notifications.requestPermissionsAsync();
        finalStatus = status;
      }

      if (finalStatus !== 'granted') {
        Alert.alert(
          'Notification Permission',
          'Push notifications are disabled. You can enable them in settings to receive display alerts.',
          [{ text: 'OK' }]
        );
        return;
      }

      // Get push token for physical devices
      if (Device.isDevice) {
        const token = await Notifications.getExpoPushTokenAsync();
        this.expoPushToken = token.data;
        console.log('Expo Push Token:', this.expoPushToken);
        
        // In a real app, send this token to your backend
        await this.registerPushToken(this.expoPushToken);
      } else {
        console.log('Push notifications require a physical device');
      }

      // Configure notification categories
      await this.setupNotificationCategories();

      this.isInitialized = true;
    } catch (error) {
      console.error('Failed to initialize notifications:', error);
    }
  }

  private async setupNotificationCategories() {
    // Define notification categories with actions
    await Notifications.setNotificationCategoryAsync('DISPLAY_ALERT', [
      {
        identifier: 'VIEW_DISPLAY',
        buttonTitle: 'View Display',
        options: {
          opensAppToForeground: true,
        },
      },
      {
        identifier: 'IGNORE',
        buttonTitle: 'Ignore',
        options: {
          opensAppToForeground: false,
        },
      },
    ]);

    await Notifications.setNotificationCategoryAsync('MENU_UPDATE', [
      {
        identifier: 'VIEW_MENU',
        buttonTitle: 'View Menu',
        options: {
          opensAppToForeground: true,
        },
      },
    ]);
  }

  async registerPushToken(token: string) {
    try {
      // In a real app, send the token to your backend API
      console.log('Registering push token with backend:', token);
      
      // Example API call:
      // await fetch('https://your-api.com/register-push-token', {
      //   method: 'POST',
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'Authorization': `Bearer ${userToken}`,
      //   },
      //   body: JSON.stringify({
      //     pushToken: token,
      //     platform: Platform.OS,
      //   }),
      // });
    } catch (error) {
      console.error('Failed to register push token:', error);
    }
  }

  async scheduleLocalNotification(options: LocalNotificationOptions) {
    try {
      const notificationId = await Notifications.scheduleNotificationAsync({
        content: {
          title: options.title,
          body: options.body,
          data: options.data || {},
          sound: options.sound !== false,
          badge: options.badge,
          priority: this.mapPriority(options.priority || 'default'),
        },
        trigger: null, // Show immediately
      });

      return notificationId;
    } catch (error) {
      console.error('Failed to schedule notification:', error);
      return null;
    }
  }

  async handleDisplayStatusNotification(data: NotificationData) {
    const isOffline = data.type === 'display_offline';
    
    await this.scheduleLocalNotification({
      title: isOffline ? 'Display Offline' : 'Display Online',
      body: data.message,
      data: {
        type: data.type,
        displayId: data.displayId,
        displayName: data.displayName,
        screen: 'Displays',
      },
      priority: isOffline ? 'high' : 'default',
    });
  }

  async handleMenuUpdateNotification(data: NotificationData) {
    await this.scheduleLocalNotification({
      title: 'Menu Updated',
      body: data.message,
      data: {
        type: data.type,
        menuId: data.menuId,
        menuName: data.menuName,
        screen: 'Menus',
      },
      priority: 'default',
    });
  }

  async handleSystemAlert(data: NotificationData) {
    await this.scheduleLocalNotification({
      title: 'System Alert',
      body: data.message,
      data: {
        type: data.type,
      },
      priority: 'high',
    });
  }

  async cancelNotification(notificationId: string) {
    try {
      await Notifications.cancelScheduledNotificationAsync(notificationId);
    } catch (error) {
      console.error('Failed to cancel notification:', error);
    }
  }

  async cancelAllNotifications() {
    try {
      await Notifications.cancelAllScheduledNotificationsAsync();
    } catch (error) {
      console.error('Failed to cancel all notifications:', error);
    }
  }

  async getBadgeCount(): Promise<number> {
    try {
      const count = await Notifications.getBadgeCountAsync();
      return count;
    } catch (error) {
      console.error('Failed to get badge count:', error);
      return 0;
    }
  }

  async setBadgeCount(count: number) {
    try {
      await Notifications.setBadgeCountAsync(count);
    } catch (error) {
      console.error('Failed to set badge count:', error);
    }
  }

  async clearBadge() {
    await this.setBadgeCount(0);
  }

  // Set up notification listeners
  setupNotificationListeners() {
    // Listen for notifications received while app is in foreground
    const foregroundSubscription = Notifications.addNotificationReceivedListener(notification => {
      console.log('Notification received in foreground:', notification);
      // Handle foreground notification (optional custom UI)
    });

    // Listen for notification responses (user tapped notification)
    const responseSubscription = Notifications.addNotificationResponseReceivedListener(response => {
      console.log('Notification response:', response);
      this.handleNotificationResponse(response);
    });

    return () => {
      foregroundSubscription.remove();
      responseSubscription.remove();
    };
  }

  private handleNotificationResponse(response: Notifications.NotificationResponse) {
    const { data, actionIdentifier } = response.notification.request.content;
    
    // Handle different actions
    switch (actionIdentifier) {
      case 'VIEW_DISPLAY':
        // Navigate to displays screen
        // navigationRef.navigate('Displays', { displayId: data.displayId });
        break;
      case 'VIEW_MENU':
        // Navigate to menus screen
        // navigationRef.navigate('Menus', { menuId: data.menuId });
        break;
      case 'IGNORE':
        // Do nothing
        break;
      default:
        // Default tap action
        if (data.screen) {
          // navigationRef.navigate(data.screen, data);
        }
        break;
    }
  }

  private mapPriority(priority: 'default' | 'low' | 'high' | 'max'): Notifications.AndroidImportance {
    switch (priority) {
      case 'low':
        return Notifications.AndroidImportance.LOW;
      case 'high':
        return Notifications.AndroidImportance.HIGH;
      case 'max':
        return Notifications.AndroidImportance.MAX;
      default:
        return Notifications.AndroidImportance.DEFAULT;
    }
  }

  getPushToken(): string | null {
    return this.expoPushToken;
  }

  isReady(): boolean {
    return this.isInitialized;
  }
}

export const notificationService = new NotificationService();

// Utility functions for common notification scenarios
export const displayOfflineAlert = (displayName: string, displayId: string) => {
  return notificationService.handleDisplayStatusNotification({
    type: 'display_offline',
    displayId,
    displayName,
    message: `${displayName} has gone offline`,
    timestamp: new Date().toISOString(),
  });
};

export const displayOnlineAlert = (displayName: string, displayId: string) => {
  return notificationService.handleDisplayStatusNotification({
    type: 'display_online',
    displayId,
    displayName,
    message: `${displayName} is back online`,
    timestamp: new Date().toISOString(),
  });
};

export const menuUpdatedAlert = (menuName: string, menuId: string) => {
  return notificationService.handleMenuUpdateNotification({
    type: 'menu_updated',
    menuId,
    menuName,
    message: `${menuName} has been updated`,
    timestamp: new Date().toISOString(),
  });
};

export default notificationService;