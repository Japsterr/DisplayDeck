import * as LocalAuthentication from 'expo-local-authentication';
import * as SecureStore from 'expo-secure-store';
import { Alert } from 'react-native';

export interface BiometricAuthResult {
  success: boolean;
  error?: string;
  biometricType?: string;
}

export interface BiometricCapabilities {
  isAvailable: boolean;
  hasHardware: boolean;
  isEnrolled: boolean;
  supportedTypes: string[];
}

class BiometricAuthService {
  private isInitialized = false;
  private capabilities: BiometricCapabilities | null = null;

  async initialize(): Promise<void> {
    if (this.isInitialized) return;

    try {
      this.capabilities = await this.checkCapabilities();
      this.isInitialized = true;
      console.log('BiometricAuthService initialized:', this.capabilities);
    } catch (error) {
      console.error('Failed to initialize BiometricAuthService:', error);
      throw error;
    }
  }

  async checkCapabilities(): Promise<BiometricCapabilities> {
    try {
      const hasHardware = await LocalAuthentication.hasHardwareAsync();
      const isEnrolled = await LocalAuthentication.isEnrolledAsync();
      const supportedTypes = await LocalAuthentication.supportedAuthenticationTypesAsync();
      
      const supportedTypeNames = supportedTypes.map(type => {
        switch (type) {
          case LocalAuthentication.AuthenticationType.FINGERPRINT:
            return 'Fingerprint';
          case LocalAuthentication.AuthenticationType.FACIAL_RECOGNITION:
            return 'Face ID';
          case LocalAuthentication.AuthenticationType.IRIS:
            return 'Iris';
          default:
            return 'Biometric';
        }
      });

      return {
        isAvailable: hasHardware && isEnrolled,
        hasHardware,
        isEnrolled,
        supportedTypes: supportedTypeNames,
      };
    } catch (error) {
      console.error('Error checking biometric capabilities:', error);
      return {
        isAvailable: false,
        hasHardware: false,
        isEnrolled: false,
        supportedTypes: [],
      };
    }
  }

  async authenticate(
    promptMessage: string = 'Authenticate to continue',
    fallbackLabel: string = 'Use Passcode'
  ): Promise<BiometricAuthResult> {
    try {
      if (!this.capabilities?.isAvailable) {
        return {
          success: false,
          error: 'Biometric authentication is not available',
        };
      }

      const result = await LocalAuthentication.authenticateAsync({
        promptMessage,
        fallbackLabel,
        disableDeviceFallback: false,
        cancelLabel: 'Cancel',
      });

      if (result.success) {
        return {
          success: true,
          biometricType: this.capabilities.supportedTypes[0] || 'Biometric',
        };
      } else {
        let errorMessage = 'Authentication failed';
        
        if (result.error === 'authentication_canceled') {
          errorMessage = 'Authentication was cancelled';
        } else if (result.error === 'user_cancel') {
          errorMessage = 'User cancelled authentication';
        } else if (result.error === 'system_cancel') {
          errorMessage = 'System cancelled authentication';
        } else if (result.error === 'passcode_not_set') {
          errorMessage = 'Passcode not set on device';
        } else if (result.error === 'biometric_not_available') {
          errorMessage = 'Biometric authentication not available';
        } else if (result.error === 'biometric_not_enrolled') {
          errorMessage = 'No biometrics enrolled on device';
        } else if (result.error === 'app_cancel') {
          errorMessage = 'App cancelled authentication';
        }

        return {
          success: false,
          error: errorMessage,
        };
      }
    } catch (error) {
      console.error('Biometric authentication error:', error);
      return {
        success: false,
        error: 'An unexpected error occurred during authentication',
      };
    }
  }

  async authenticateForLogin(): Promise<BiometricAuthResult> {
    return this.authenticate(
      'Sign in with biometrics',
      'Use your device passcode instead'
    );
  }

  async authenticateForSensitiveAction(action: string): Promise<BiometricAuthResult> {
    return this.authenticate(
      `Verify your identity to ${action}`,
      'Use passcode'
    );
  }

  async enableBiometricLogin(userId: string, credentials: any): Promise<boolean> {
    try {
      if (!this.capabilities?.isAvailable) {
        Alert.alert(
          'Biometric Login Unavailable',
          'Biometric authentication is not available on this device or no biometrics are enrolled.'
        );
        return false;
      }

      // First authenticate to ensure user can use biometrics
      const authResult = await this.authenticate(
        'Verify your identity to enable biometric login'
      );

      if (!authResult.success) {
        Alert.alert('Authentication Failed', authResult.error || 'Could not verify biometric authentication');
        return false;
      }

      // Store encrypted credentials for biometric login
      await SecureStore.setItemAsync(
        `biometric_credentials_${userId}`,
        JSON.stringify(credentials)
      );

      // Mark biometric as enabled
      await SecureStore.setItemAsync('biometric_login_enabled', 'true');

      return true;
    } catch (error) {
      console.error('Error enabling biometric login:', error);
      Alert.alert('Error', 'Failed to enable biometric login');
      return false;
    }
  }

  async disableBiometricLogin(userId: string): Promise<boolean> {
    try {
      await SecureStore.deleteItemAsync(`biometric_credentials_${userId}`);
      await SecureStore.deleteItemAsync('biometric_login_enabled');
      return true;
    } catch (error) {
      console.error('Error disabling biometric login:', error);
      return false;
    }
  }

  async isBiometricLoginEnabled(): Promise<boolean> {
    try {
      const enabled = await SecureStore.getItemAsync('biometric_login_enabled');
      return enabled === 'true';
    } catch (error) {
      console.error('Error checking biometric login status:', error);
      return false;
    }
  }

  async getBiometricCredentials(userId: string): Promise<any | null> {
    try {
      const credentialsStr = await SecureStore.getItemAsync(`biometric_credentials_${userId}`);
      return credentialsStr ? JSON.parse(credentialsStr) : null;
    } catch (error) {
      console.error('Error getting biometric credentials:', error);
      return null;
    }
  }

  async promptForBiometricSetup(): Promise<boolean> {
    return new Promise((resolve) => {
      if (!this.capabilities?.hasHardware) {
        resolve(false);
        return;
      }

      if (!this.capabilities.isEnrolled) {
        Alert.alert(
          'Biometric Setup Required',
          'No biometrics are enrolled on this device. Please set up Face ID, Touch ID, or fingerprint authentication in your device settings to enable biometric login.',
          [
            { text: 'Cancel', style: 'cancel', onPress: () => resolve(false) },
            { 
              text: 'Settings', 
              onPress: () => {
                // In a real app, you would open device settings
                resolve(false);
              }
            },
          ]
        );
        return;
      }

      Alert.alert(
        'Enable Biometric Login',
        `Enable ${this.capabilities.supportedTypes.join(' or ')} for faster, secure access to your account?`,
        [
          { text: 'Not Now', style: 'cancel', onPress: () => resolve(false) },
          { text: 'Enable', onPress: () => resolve(true) },
        ]
      );
    });
  }

  getCapabilities(): BiometricCapabilities | null {
    return this.capabilities;
  }

  isAvailable(): boolean {
    return this.capabilities?.isAvailable || false;
  }

  getSupportedTypes(): string[] {
    return this.capabilities?.supportedTypes || [];
  }

  // Security utilities
  async secureAction(
    action: () => Promise<void>,
    authPrompt: string = 'Verify your identity'
  ): Promise<boolean> {
    try {
      const authResult = await this.authenticate(authPrompt);
      
      if (authResult.success) {
        await action();
        return true;
      } else {
        Alert.alert('Authentication Required', authResult.error || 'Authentication failed');
        return false;
      }
    } catch (error) {
      console.error('Secure action error:', error);
      Alert.alert('Error', 'An error occurred while performing the secure action');
      return false;
    }
  }

  // Quick authentication for sensitive data access
  async quickAuth(): Promise<boolean> {
    if (!this.isAvailable()) {
      return false;
    }

    const result = await this.authenticate('Quick authentication required');
    return result.success;
  }

  // Continuous authentication (for sensitive screens)
  async setupContinuousAuth(
    onAuthRequired: () => void,
    intervalMinutes: number = 5
  ): Promise<() => void> {
    const interval = setInterval(async () => {
      const result = await this.quickAuth();
      if (!result) {
        onAuthRequired();
      }
    }, intervalMinutes * 60 * 1000);

    // Return cleanup function
    return () => clearInterval(interval);
  }
}

// Export singleton instance
export const biometricAuthService = new BiometricAuthService();

// Utility functions
export const authenticateUser = async (
  promptMessage?: string
): Promise<BiometricAuthResult> => {
  if (!biometricAuthService.isAvailable()) {
    return {
      success: false,
      error: 'Biometric authentication not available',
    };
  }
  
  return biometricAuthService.authenticate(promptMessage);
};

export const enableBiometrics = async (
  userId: string,
  credentials: any
): Promise<boolean> => {
  return biometricAuthService.enableBiometricLogin(userId, credentials);
};

export const disableBiometrics = async (userId: string): Promise<boolean> => {
  return biometricAuthService.disableBiometricLogin(userId);
};

export const isBiometricsEnabled = async (): Promise<boolean> => {
  return biometricAuthService.isBiometricLoginEnabled();
};

export default biometricAuthService;