import { configureStore, combineReducers } from '@reduxjs/toolkit';
import { persistStore, persistReducer, FLUSH, REHYDRATE, PAUSE, PERSIST, PURGE, REGISTER } from 'redux-persist';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Import slice reducers
import authSlice from './slices/authSlice';
import businessSlice from './slices/businessSlice';
import menuSlice from './slices/menuSlice';
import displaySlice from './slices/displaySlice';
import offlineSlice from './slices/offlineSlice';
import settingsSlice from './slices/settingsSlice';

// Root reducer
const rootReducer = combineReducers({
  auth: authSlice,
  business: businessSlice,
  menu: menuSlice,
  display: displaySlice,
  offline: offlineSlice,
  settings: settingsSlice,
});

// Persist config
const persistConfig = {
  key: 'root',
  version: 1,
  storage: AsyncStorage,
  // Only persist certain reducers
  whitelist: ['auth', 'business', 'menu', 'display', 'settings'],
  // Don't persist the offline queue as it's temporary
  blacklist: ['offline'],
};

// Create persisted reducer
const persistedReducer = persistReducer(persistConfig, rootReducer);

// Configure store
export const store = configureStore({
  reducer: persistedReducer,
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: [FLUSH, REHYDRATE, PAUSE, PERSIST, PURGE, REGISTER],
      },
    }),
  devTools: __DEV__, // Enable Redux DevTools in development
});

// Create persistor
export const persistor = persistStore(store);

// Types
export type RootState = ReturnType<typeof rootReducer>;
export type AppDispatch = typeof store.dispatch;

// Typed hooks
import { useDispatch, useSelector, TypedUseSelectorHook } from 'react-redux';

export const useAppDispatch = () => useDispatch<AppDispatch>();
export const useAppSelector: TypedUseSelectorHook<RootState> = useSelector;

// Reset store (for logout)
export const resetStore = () => {
  persistor.purge();
  // Restart persistence
  persistor.persist();
};