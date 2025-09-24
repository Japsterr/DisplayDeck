import { createSlice, PayloadAction } from '@reduxjs/toolkit';

interface OfflineAction {
  id: string;
  type: 'CREATE' | 'UPDATE' | 'DELETE';
  entity: 'menu' | 'menu_item' | 'business' | 'display';
  entityId: string;
  data: any;
  timestamp: string;
  retryCount: number;
}

interface OfflineState {
  isOnline: boolean;
  syncQueue: OfflineAction[];
  syncing: boolean;
  lastSyncAttempt: string | null;
  failedSyncs: string[]; // Action IDs that failed to sync
}

const initialState: OfflineState = {
  isOnline: true,
  syncQueue: [],
  syncing: false,
  lastSyncAttempt: null,
  failedSyncs: [],
};

const offlineSlice = createSlice({
  name: 'offline',
  initialState,
  reducers: {
    setOnlineStatus: (state, action: PayloadAction<boolean>) => {
      state.isOnline = action.payload;
      // If coming back online, prepare to sync
      if (action.payload && state.syncQueue.length > 0) {
        state.syncing = false; // Reset syncing state
      }
    },
    addToSyncQueue: (state, action: PayloadAction<Omit<OfflineAction, 'id' | 'timestamp' | 'retryCount'>>) => {
      const newAction: OfflineAction = {
        ...action.payload,
        id: `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        timestamp: new Date().toISOString(),
        retryCount: 0,
      };
      state.syncQueue.push(newAction);
    },
    removeFromSyncQueue: (state, action: PayloadAction<string>) => {
      state.syncQueue = state.syncQueue.filter(item => item.id !== action.payload);
      state.failedSyncs = state.failedSyncs.filter(id => id !== action.payload);
    },
    setSyncing: (state, action: PayloadAction<boolean>) => {
      state.syncing = action.payload;
      if (action.payload) {
        state.lastSyncAttempt = new Date().toISOString();
      }
    },
    incrementRetryCount: (state, action: PayloadAction<string>) => {
      const item = state.syncQueue.find(item => item.id === action.payload);
      if (item) {
        item.retryCount++;
      }
    },
    markSyncFailed: (state, action: PayloadAction<string>) => {
      if (!state.failedSyncs.includes(action.payload)) {
        state.failedSyncs.push(action.payload);
      }
    },
    clearFailedSyncs: (state) => {
      state.failedSyncs = [];
    },
    clearSyncQueue: (state) => {
      state.syncQueue = [];
      state.failedSyncs = [];
    },
    // Optimistic update actions
    addOptimisticAction: (state, action: PayloadAction<OfflineAction>) => {
      // Add to queue for later sync when online
      if (!state.isOnline) {
        state.syncQueue.push(action.payload);
      }
    },
  },
});

export const {
  setOnlineStatus,
  addToSyncQueue,
  removeFromSyncQueue,
  setSyncing,
  incrementRetryCount,
  markSyncFailed,
  clearFailedSyncs,
  clearSyncQueue,
  addOptimisticAction,
} = offlineSlice.actions;

export default offlineSlice.reducer;