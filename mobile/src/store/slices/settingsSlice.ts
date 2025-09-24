import { createSlice, PayloadAction } from '@reduxjs/toolkit';

interface AppSettings {
  theme: 'light' | 'dark' | 'system';
  language: string;
  autoSync: boolean;
  syncFrequency: number; // minutes
  notifications: {
    displayAlerts: boolean;
    menuUpdates: boolean;
    systemNotifications: boolean;
    soundEnabled: boolean;
  };
  display: {
    keepScreenOn: boolean;
    showDebugInfo: boolean;
    refreshInterval: number; // seconds
  };
  security: {
    biometricEnabled: boolean;
    sessionTimeout: number; // minutes
    requireAuth: boolean;
  };
  backup: {
    autoBackup: boolean;
    backupFrequency: 'daily' | 'weekly' | 'monthly';
    lastBackup: string | null;
  };
}

interface SettingsState {
  settings: AppSettings;
  loading: boolean;
  error: string | null;
}

const defaultSettings: AppSettings = {
  theme: 'system',
  language: 'en',
  autoSync: true,
  syncFrequency: 15,
  notifications: {
    displayAlerts: true,
    menuUpdates: true,
    systemNotifications: true,
    soundEnabled: true,
  },
  display: {
    keepScreenOn: false,
    showDebugInfo: false,
    refreshInterval: 30,
  },
  security: {
    biometricEnabled: false,
    sessionTimeout: 30,
    requireAuth: true,
  },
  backup: {
    autoBackup: true,
    backupFrequency: 'weekly',
    lastBackup: null,
  },
};

const initialState: SettingsState = {
  settings: defaultSettings,
  loading: false,
  error: null,
};

const settingsSlice = createSlice({
  name: 'settings',
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
    updateSettings: (state, action: PayloadAction<Partial<AppSettings>>) => {
      state.settings = { ...state.settings, ...action.payload };
      state.error = null;
    },
    updateNotificationSettings: (state, action: PayloadAction<Partial<AppSettings['notifications']>>) => {
      state.settings.notifications = { ...state.settings.notifications, ...action.payload };
    },
    updateDisplaySettings: (state, action: PayloadAction<Partial<AppSettings['display']>>) => {
      state.settings.display = { ...state.settings.display, ...action.payload };
    },
    updateSecuritySettings: (state, action: PayloadAction<Partial<AppSettings['security']>>) => {
      state.settings.security = { ...state.settings.security, ...action.payload };
    },
    updateBackupSettings: (state, action: PayloadAction<Partial<AppSettings['backup']>>) => {
      state.settings.backup = { ...state.settings.backup, ...action.payload };
    },
    setTheme: (state, action: PayloadAction<'light' | 'dark' | 'system'>) => {
      state.settings.theme = action.payload;
    },
    setLanguage: (state, action: PayloadAction<string>) => {
      state.settings.language = action.payload;
    },
    toggleAutoSync: (state) => {
      state.settings.autoSync = !state.settings.autoSync;
    },
    setSyncFrequency: (state, action: PayloadAction<number>) => {
      state.settings.syncFrequency = action.payload;
    },
    toggleBiometric: (state) => {
      state.settings.security.biometricEnabled = !state.settings.security.biometricEnabled;
    },
    setSessionTimeout: (state, action: PayloadAction<number>) => {
      state.settings.security.sessionTimeout = action.payload;
    },
    updateLastBackup: (state, action: PayloadAction<string>) => {
      state.settings.backup.lastBackup = action.payload;
    },
    resetToDefaults: (state) => {
      state.settings = defaultSettings;
    },
  },
});

export const {
  setLoading,
  setError,
  updateSettings,
  updateNotificationSettings,
  updateDisplaySettings,
  updateSecuritySettings,
  updateBackupSettings,
  setTheme,
  setLanguage,
  toggleAutoSync,
  setSyncFrequency,
  toggleBiometric,
  setSessionTimeout,
  updateLastBackup,
  resetToDefaults,
} = settingsSlice.actions;

export default settingsSlice.reducer;