import React, { useContext, useEffect, useState } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createDrawerNavigator } from '@react-navigation/drawer';
import { NavigationProp } from '@react-navigation/native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as SecureStore from 'expo-secure-store';
import { ActivityIndicator, View } from 'react-native';

// Import screens (we'll create these)
import LoginScreen from '../screens/Auth/LoginScreen';
import DashboardScreen from '../screens/Dashboard/DashboardScreen';
import DisplayScreen from '../screens/Displays/DisplayScreen';
import MenuScreen from '../screens/Menus/MenuScreen';
import ProfileScreen from '../screens/Profile/ProfileScreen';

// Types
export type AuthStackParamList = {
  Login: undefined;
  Register: undefined;
  ForgotPassword: undefined;
};

export type MainDrawerParamList = {
  Dashboard: undefined;
  Displays: undefined;
  Menus: undefined;
  Profile: undefined;
};

export type RootStackParamList = {
  Auth: NavigationProp<AuthStackParamList>;
  Main: NavigationProp<MainDrawerParamList>;
} & AuthStackParamList & MainDrawerParamList;

// Create navigators
const Stack = createNativeStackNavigator<RootStackParamList>();
const AuthStack = createNativeStackNavigator<AuthStackParamList>();
const MainDrawer = createDrawerNavigator<MainDrawerParamList>();

// Auth Context
interface AuthContextType {
  isAuthenticated: boolean;
  user: any | null;
  login: (token: string, refreshToken: string, user: any) => Promise<void>;
  logout: () => Promise<void>;
  loading: boolean;
}

const AuthContext = React.createContext<AuthContextType>({
  isAuthenticated: false,
  user: null,
  login: async () => {},
  logout: async () => {},
  loading: true,
});

export const useAuth = () => useContext(AuthContext);

// Auth Provider Component
export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [user, setUser] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkAuthState();
  }, []);

  const checkAuthState = async () => {
    try {
      const token = await SecureStore.getItemAsync('access_token');
      const userData = await AsyncStorage.getItem('user_data');
      
      if (token && userData) {
        setIsAuthenticated(true);
        setUser(JSON.parse(userData));
      }
    } catch (error) {
      console.error('Error checking auth state:', error);
    } finally {
      setLoading(false);
    }
  };

  const login = async (token: string, refreshToken: string, userData: any) => {
    try {
      await SecureStore.setItemAsync('access_token', token);
      await SecureStore.setItemAsync('refresh_token', refreshToken);
      await AsyncStorage.setItem('user_data', JSON.stringify(userData));
      
      setIsAuthenticated(true);
      setUser(userData);
    } catch (error) {
      console.error('Error saving auth data:', error);
      throw error;
    }
  };

  const logout = async () => {
    try {
      await SecureStore.deleteItemAsync('access_token');
      await SecureStore.deleteItemAsync('refresh_token');
      await AsyncStorage.removeItem('user_data');
      
      setIsAuthenticated(false);
      setUser(null);
    } catch (error) {
      console.error('Error clearing auth data:', error);
    }
  };

  const value = {
    isAuthenticated,
    user,
    login,
    logout,
    loading,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}

// Auth Stack Navigator
function AuthStackNavigator() {
  return (
    <AuthStack.Navigator 
      screenOptions={{ 
        headerShown: false,
        animation: 'slide_from_right',
      }}
    >
      <AuthStack.Screen name="Login" component={LoginScreen} />
    </AuthStack.Navigator>
  );
}

// Main Drawer Navigator
function MainDrawerNavigator() {
  return (
    <MainDrawer.Navigator
      screenOptions={{
        drawerType: 'slide',
        drawerStyle: {
          backgroundColor: '#f8f9fa',
          width: 280,
        },
        drawerLabelStyle: {
          fontSize: 16,
          fontWeight: '500',
        },
        headerStyle: {
          backgroundColor: '#007bff',
        },
        headerTintColor: '#fff',
        headerTitleStyle: {
          fontWeight: 'bold',
        },
      }}
    >
      <MainDrawer.Screen 
        name="Dashboard" 
        component={DashboardScreen}
        options={{
          title: 'Dashboard',
          drawerLabel: 'Dashboard',
        }}
      />
      <MainDrawer.Screen 
        name="Displays" 
        component={DisplayScreen}
        options={{
          title: 'Display Management',
          drawerLabel: 'Displays',
        }}
      />
      <MainDrawer.Screen 
        name="Menus" 
        component={MenuScreen}
        options={{
          title: 'Menu Management',
          drawerLabel: 'Menus',
        }}
      />
      <MainDrawer.Screen 
        name="Profile" 
        component={ProfileScreen}
        options={{
          title: 'Profile',
          drawerLabel: 'Profile',
        }}
      />
    </MainDrawer.Navigator>
  );
}

// Loading Screen Component
function LoadingScreen() {
  return (
    <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' }}>
      <ActivityIndicator size="large" color="#007bff" />
    </View>
  );
}

// Root Navigator Component
function RootNavigator() {
  const { isAuthenticated, loading } = useAuth();

  if (loading) {
    return <LoadingScreen />;
  }

  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      {isAuthenticated ? (
        <Stack.Screen name="Main" component={MainDrawerNavigator} />
      ) : (
        <Stack.Screen name="Auth" component={AuthStackNavigator} />
      )}
    </Stack.Navigator>
  );
}

// Main App Navigation Component
export default function AppNavigation() {
  return (
    <NavigationContainer>
      <AuthProvider>
        <RootNavigator />
      </AuthProvider>
    </NavigationContainer>
  );
}

// Navigation utilities
export const navigationRef = React.createRef<any>();

export function navigate(name: string, params?: object) {
  navigationRef.current?.navigate(name, params);
}

export function goBack() {
  navigationRef.current?.goBack();
}

export function resetToScreen(name: string) {
  navigationRef.current?.reset({
    index: 0,
    routes: [{ name }],
  });
}