import { StatusBar } from 'expo-status-bar';
import { StyleSheet, View } from 'react-native';

import AppNavigation from './src/navigation/AppNavigation';

export default function App() {
  return (
    <View style={styles.container}>
      <StatusBar style="auto" />
      <AppNavigation />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
