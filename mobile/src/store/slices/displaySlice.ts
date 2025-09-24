import { createSlice, PayloadAction } from '@reduxjs/toolkit';

export interface Display {
  id: string;
  name: string;
  location: string;
  business_id: string;
  is_paired: boolean;
  is_active: boolean;
  assigned_menu?: string;
  device_type: string;
  resolution: string;
  last_heartbeat?: string;
  created_at: string;
}

interface DisplayState {
  displays: Display[];
  loading: boolean;
  error: string | null;
  lastSync: string | null;
  onlineCount: number;
  offlineCount: number;
}

const initialState: DisplayState = {
  displays: [],
  loading: false,
  error: null,
  lastSync: null,
  onlineCount: 0,
  offlineCount: 0,
};

const displaySlice = createSlice({
  name: 'display',
  initialState,
  reducers: {
    setLoading: (state, action: PayloadAction<boolean>) => {
      state.loading = action.payload;
      if (action.payload) {
        state.error = null;
      }
    },
    setError: (state, action: PayloadAction<string>) => {
      state.error = action.payload;
      state.loading = false;
    },
    setDisplays: (state, action: PayloadAction<Display[]>) => {
      state.displays = action.payload;
      state.loading = false;
      state.error = null;
      state.lastSync = new Date().toISOString();
      
      // Update counts
      const now = new Date();
      state.onlineCount = action.payload.filter(display => {
        if (!display.last_heartbeat) return false;
        const lastSeen = new Date(display.last_heartbeat);
        const minutesSince = (now.getTime() - lastSeen.getTime()) / (1000 * 60);
        return display.is_paired && minutesSince < 15; // Online if heartbeat within 15 minutes
      }).length;
      state.offlineCount = action.payload.length - state.onlineCount;
    },
    addDisplay: (state, action: PayloadAction<Display>) => {
      state.displays.push(action.payload);
      // Update counts if needed
      if (action.payload.is_paired) {
        state.onlineCount++;
      } else {
        state.offlineCount++;
      }
    },
    updateDisplay: (state, action: PayloadAction<Display>) => {
      const index = state.displays.findIndex(d => d.id === action.payload.id);
      if (index !== -1) {
        const oldDisplay = state.displays[index];
        state.displays[index] = action.payload;
        
        // Update counts if status changed
        const wasOnline = oldDisplay.is_paired && oldDisplay.last_heartbeat;
        const isOnline = action.payload.is_paired && action.payload.last_heartbeat;
        
        if (wasOnline !== isOnline) {
          if (isOnline) {
            state.onlineCount++;
            state.offlineCount--;
          } else {
            state.onlineCount--;
            state.offlineCount++;
          }
        }
      }
    },
    deleteDisplay: (state, action: PayloadAction<string>) => {
      const display = state.displays.find(d => d.id === action.payload);
      if (display) {
        if (display.is_paired) {
          state.onlineCount--;
        } else {
          state.offlineCount--;
        }
      }
      state.displays = state.displays.filter(d => d.id !== action.payload);
    },
    updateDisplayHeartbeat: (state, action: PayloadAction<{
      displayId: string;
      heartbeat: string;
    }>) => {
      const display = state.displays.find(d => d.id === action.payload.displayId);
      if (display) {
        const wasOnline = display.is_paired && display.last_heartbeat;
        display.last_heartbeat = action.payload.heartbeat;
        const isOnline = display.is_paired && display.last_heartbeat;
        
        // Update counts if status changed
        if (wasOnline !== isOnline) {
          if (isOnline) {
            state.onlineCount++;
            state.offlineCount--;
          } else {
            state.onlineCount--;
            state.offlineCount++;
          }
        }
      }
    },
    pairDisplay: (state, action: PayloadAction<string>) => {
      const display = state.displays.find(d => d.id === action.payload);
      if (display && !display.is_paired) {
        display.is_paired = true;
        display.last_heartbeat = new Date().toISOString();
        state.onlineCount++;
        state.offlineCount--;
      }
    },
    unpairDisplay: (state, action: PayloadAction<string>) => {
      const display = state.displays.find(d => d.id === action.payload);
      if (display && display.is_paired) {
        display.is_paired = false;
        display.last_heartbeat = undefined;
        state.onlineCount--;
        state.offlineCount++;
      }
    },
  },
});

export const {
  setLoading,
  setError,
  setDisplays,
  addDisplay,
  updateDisplay,
  deleteDisplay,
  updateDisplayHeartbeat,
  pairDisplay,
  unpairDisplay,
} = displaySlice.actions;

export default displaySlice.reducer;