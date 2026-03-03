import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { View, Text, StyleSheet } from 'react-native';
import { colors, typography, spacing } from './src/theme';
import { StatusBar } from 'expo-status-bar';

// Tab icons using text for now (no vector icons to avoid install)
function TabIcon({ label, focused }: { label: string; focused: boolean }) {
  return (
    <Text style={{ fontSize: 10, color: focused ? colors.accent : colors.textSecondary, marginTop: 2 }}>
      {label}
    </Text>
  );
}

// Placeholder screens
function OrdersScreen() {
  return (
    <View style={styles.screen}>
      <Text style={styles.screenTitle}>Orders</Text>
      <Text style={styles.screenSub}>View and manage distributor orders</Text>
    </View>
  );
}

function OutletsScreen() {
  return (
    <View style={styles.screen}>
      <Text style={styles.screenTitle}>Outlets</Text>
      <Text style={styles.screenSub}>Manage your outlet network</Text>
    </View>
  );
}

function CollectionsScreen() {
  return (
    <View style={styles.screen}>
      <Text style={styles.screenTitle}>Collections</Text>
      <Text style={styles.screenSub}>Credit collections and payments</Text>
    </View>
  );
}

function TripsScreen() {
  return (
    <View style={styles.screen}>
      <Text style={styles.screenTitle}>Trips</Text>
      <Text style={styles.screenSub}>Driver trip management and POD</Text>
    </View>
  );
}

function ProfileScreen() {
  return (
    <View style={styles.screen}>
      <Text style={styles.screenTitle}>Profile</Text>
      <Text style={styles.screenSub}>Account and settings</Text>
    </View>
  );
}

const Tab = createBottomTabNavigator();

export default function App() {
  return (
    <SafeAreaProvider>
      <NavigationContainer>
        <Tab.Navigator
          screenOptions={{
            headerStyle: { backgroundColor: colors.primary },
            headerTintColor: colors.white,
            headerTitleStyle: { fontWeight: '700' },
            tabBarActiveTintColor: colors.primary,
            tabBarInactiveTintColor: colors.textSecondary,
            tabBarStyle: {
              borderTopColor: colors.border,
              backgroundColor: colors.background,
              paddingBottom: spacing.sm,
              height: 60,
            },
          }}
        >
          <Tab.Screen
            name="Orders"
            component={OrdersScreen}
            options={{
              title: 'Orders',
              tabBarLabel: 'Orders',
            }}
          />
          <Tab.Screen
            name="Outlets"
            component={OutletsScreen}
            options={{
              title: 'Outlets',
              tabBarLabel: 'Outlets',
            }}
          />
          <Tab.Screen
            name="Collections"
            component={CollectionsScreen}
            options={{
              title: 'Collections',
              tabBarLabel: 'Collections',
            }}
          />
          <Tab.Screen
            name="Trips"
            component={TripsScreen}
            options={{
              title: 'Trips',
              tabBarLabel: 'Trips',
            }}
          />
          <Tab.Screen
            name="Profile"
            component={ProfileScreen}
            options={{
              title: 'Profile',
              tabBarLabel: 'Profile',
            }}
          />
        </Tab.Navigator>
        <StatusBar style="light" backgroundColor={colors.primary} />
      </NavigationContainer>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.backgroundSubtle,
    padding: spacing.xl,
  },
  screenTitle: {
    ...typography.h2,
    marginBottom: spacing.sm,
  },
  screenSub: {
    ...typography.body,
    color: colors.textSecondary,
    textAlign: 'center',
  },
});
