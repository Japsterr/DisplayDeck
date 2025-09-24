import NetInfo from '@react-native-community/netinfo';
import { store } from '../store';
import { 
  setOnlineStatus, 
  setSyncing, 
  removeFromSyncQueue, 
  incrementRetryCount, 
  markSyncFailed 
} from '../store/slices/offlineSlice';

class SyncService {
  private isInitialized = false;
  private syncInterval: NodeJS.Timeout | null = null;
  private unsubscribeNetInfo: (() => void) | null = null;

  async initialize() {
    if (this.isInitialized) return;

    try {
      // Monitor network connectivity
      this.unsubscribeNetInfo = NetInfo.addEventListener(state => {
        const isOnline = state.isConnected && state.isInternetReachable;
        store.dispatch(setOnlineStatus(isOnline || false));

        if (isOnline) {
          // When coming back online, start sync
          this.startSyncProcess();
        } else {
          // When going offline, stop sync
          this.stopSyncProcess();
        }
      });

      // Check initial network state
      const netInfo = await NetInfo.fetch();
      const isOnline = netInfo.isConnected && netInfo.isInternetReachable;
      store.dispatch(setOnlineStatus(isOnline || false));

      // Start sync process if online
      if (isOnline) {
        this.startSyncProcess();
      }

      this.isInitialized = true;
      console.log('SyncService initialized');
    } catch (error) {
      console.error('Failed to initialize SyncService:', error);
    }
  }

  private startSyncProcess() {
    // Don't start multiple sync processes
    if (this.syncInterval) return;

    console.log('Starting background sync process');
    
    // Immediate sync
    this.performSync();

    // Set up periodic sync every 30 seconds
    this.syncInterval = setInterval(() => {
      this.performSync();
    }, 30000);
  }

  private stopSyncProcess() {
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
      this.syncInterval = null;
      console.log('Stopped background sync process');
    }
  }

  private async performSync() {
    const state = store.getState();
    const { isOnline, syncQueue, syncing } = state.offline;

    // Skip if offline or already syncing or nothing to sync
    if (!isOnline || syncing || syncQueue.length === 0) {
      return;
    }

    console.log(`Starting sync for ${syncQueue.length} items`);
    store.dispatch(setSyncing(true));

    try {
      // Process each item in the sync queue
      for (const action of syncQueue) {
        try {
          await this.syncAction(action);
          
          // Remove successfully synced item
          store.dispatch(removeFromSyncQueue(action.id));
          console.log(`Successfully synced action: ${action.type} ${action.entity} ${action.entityId}`);
          
        } catch (error) {
          console.error(`Failed to sync action: ${action.type} ${action.entity} ${action.entityId}`, error);
          
          // Increment retry count
          store.dispatch(incrementRetryCount(action.id));
          
          // Mark as failed if too many retries
          if (action.retryCount >= 3) {
            store.dispatch(markSyncFailed(action.id));
          }
        }
      }
    } catch (error) {
      console.error('Sync process error:', error);
    } finally {
      store.dispatch(setSyncing(false));
    }
  }

  private async syncAction(action: any) {
    const { type, entity, entityId, data } = action;
    
    // Mock API calls - replace with actual API endpoints
    const baseUrl = 'https://your-api.com/api';
    
    switch (entity) {
      case 'menu':
        await this.syncMenu(baseUrl, type, entityId, data);
        break;
        
      case 'menu_item':
        await this.syncMenuItem(baseUrl, type, entityId, data);
        break;
        
      case 'business':
        await this.syncBusiness(baseUrl, type, entityId, data);
        break;
        
      case 'display':
        await this.syncDisplay(baseUrl, type, entityId, data);
        break;
        
      default:
        throw new Error(`Unknown entity type: ${entity}`);
    }
  }

  private async syncMenu(baseUrl: string, type: string, entityId: string, data: any) {
    const state = store.getState();
    const { accessToken } = state.auth;
    
    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`,
    };

    switch (type) {
      case 'CREATE':
        await fetch(`${baseUrl}/menus/`, {
          method: 'POST',
          headers,
          body: JSON.stringify(data),
        });
        break;
        
      case 'UPDATE':
        await fetch(`${baseUrl}/menus/${entityId}/`, {
          method: 'PUT',
          headers,
          body: JSON.stringify(data),
        });
        break;
        
      case 'DELETE':
        await fetch(`${baseUrl}/menus/${entityId}/`, {
          method: 'DELETE',
          headers,
        });
        break;
    }
  }

  private async syncMenuItem(baseUrl: string, type: string, entityId: string, data: any) {
    const state = store.getState();
    const { accessToken } = state.auth;
    
    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`,
    };

    switch (type) {
      case 'CREATE':
        await fetch(`${baseUrl}/menu-items/`, {
          method: 'POST',
          headers,
          body: JSON.stringify(data),
        });
        break;
        
      case 'UPDATE':
        await fetch(`${baseUrl}/menu-items/${entityId}/`, {
          method: 'PUT',
          headers,
          body: JSON.stringify(data),
        });
        break;
        
      case 'DELETE':
        await fetch(`${baseUrl}/menu-items/${entityId}/`, {
          method: 'DELETE',
          headers,
        });
        break;
    }
  }

  private async syncBusiness(baseUrl: string, type: string, entityId: string, data: any) {
    const state = store.getState();
    const { accessToken } = state.auth;
    
    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`,
    };

    switch (type) {
      case 'CREATE':
        await fetch(`${baseUrl}/businesses/`, {
          method: 'POST',
          headers,
          body: JSON.stringify(data),
        });
        break;
        
      case 'UPDATE':
        await fetch(`${baseUrl}/businesses/${entityId}/`, {
          method: 'PUT',
          headers,
          body: JSON.stringify(data),
        });
        break;
        
      case 'DELETE':
        await fetch(`${baseUrl}/businesses/${entityId}/`, {
          method: 'DELETE',
          headers,
        });
        break;
    }
  }

  private async syncDisplay(baseUrl: string, type: string, entityId: string, data: any) {
    const state = store.getState();
    const { accessToken } = state.auth;
    
    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`,
    };

    switch (type) {
      case 'CREATE':
        await fetch(`${baseUrl}/displays/`, {
          method: 'POST',
          headers,
          body: JSON.stringify(data),
        });
        break;
        
      case 'UPDATE':
        await fetch(`${baseUrl}/displays/${entityId}/`, {
          method: 'PUT',
          headers,
          body: JSON.stringify(data),
        });
        break;
        
      case 'DELETE':
        await fetch(`${baseUrl}/displays/${entityId}/`, {
          method: 'DELETE',
          headers,
        });
        break;
    }
  }

  // Force sync all pending changes
  async forceSyncAll() {
    await this.performSync();
  }

  // Get sync status
  getSyncStatus() {
    const state = store.getState();
    return {
      isOnline: state.offline.isOnline,
      syncing: state.offline.syncing,
      pendingCount: state.offline.syncQueue.length,
      failedCount: state.offline.failedSyncs.length,
      lastSyncAttempt: state.offline.lastSyncAttempt,
    };
  }

  // Clean up
  destroy() {
    if (this.unsubscribeNetInfo) {
      this.unsubscribeNetInfo();
      this.unsubscribeNetInfo = null;
    }
    
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
      this.syncInterval = null;
    }
    
    this.isInitialized = false;
    console.log('SyncService destroyed');
  }
}

// Export singleton instance
export const syncService = new SyncService();

// Helper functions to add actions to sync queue
export const queueMenuSync = (type: 'CREATE' | 'UPDATE' | 'DELETE', menuId: string, data?: any) => {
  store.dispatch({
    type: 'offline/addToSyncQueue',
    payload: {
      type,
      entity: 'menu',
      entityId: menuId,
      data,
    },
  });
};

export const queueMenuItemSync = (type: 'CREATE' | 'UPDATE' | 'DELETE', itemId: string, data?: any) => {
  store.dispatch({
    type: 'offline/addToSyncQueue',
    payload: {
      type,
      entity: 'menu_item',
      entityId: itemId,
      data,
    },
  });
};

export const queueBusinessSync = (type: 'CREATE' | 'UPDATE' | 'DELETE', businessId: string, data?: any) => {
  store.dispatch({
    type: 'offline/addToSyncQueue',
    payload: {
      type,
      entity: 'business',
      entityId: businessId,
      data,
    },
  });
};

export const queueDisplaySync = (type: 'CREATE' | 'UPDATE' | 'DELETE', displayId: string, data?: any) => {
  store.dispatch({
    type: 'offline/addToSyncQueue',
    payload: {
      type,
      entity: 'display',
      entityId: displayId,
      data,
    },
  });
};

export default syncService;