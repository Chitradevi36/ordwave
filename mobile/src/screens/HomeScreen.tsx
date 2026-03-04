import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  SafeAreaView,
  ScrollView,
  ActivityIndicator,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { colors, spacing, typography, borderRadius } from '../theme';
import { Card } from '../components/Card';
import { Badge } from '../components/Badge';

interface HomeScreenProps {
  onLogout: () => void;
}

interface UserData {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  full_name: string;
  plan: string;
}

interface OrganizationData {
  id: number;
  name: string;
}

interface MembershipData {
  role: string;
  branch_name: string;
}

export default function HomeScreen({ onLogout }: HomeScreenProps) {
  const [user, setUser] = useState<UserData | null>(null);
  const [organization, setOrganization] = useState<OrganizationData | null>(null);
  const [membership, setMembership] = useState<MembershipData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadUserData();
  }, []);

  const loadUserData = async () => {
    try {
      const userJson = await AsyncStorage.getItem('user');
      if (userJson) {
        const userData = JSON.parse(userJson);
        setUser(userData);
        
        // TODO: Fetch organization and membership from API
        // For now, use mock data
        setOrganization({
          id: 1,
          name: 'Demo Distributors Ltd',
          plan: 'growth',
        });
        setMembership({
          role: 'owner',
          branch_name: 'Head Office',
        });
      }
    } catch (error) {
      console.error('Failed to load user data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    try {
      const token = await AsyncStorage.getItem('auth_token');
      
      // Call logout endpoint
      await fetch('http://localhost:3000/api/v1/auth/logout', {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      // Clear local storage
      await AsyncStorage.multiRemove(['auth_token', 'user']);
      
      onLogout();
    } catch (error) {
      console.error('Logout error:', error);
      onLogout(); // Logout anyway
    }
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={colors.primary} />
      </View>
    );
  }

  if (!user) {
    return (
      <View style={styles.errorContainer}>
        <Text style={styles.errorText}>Failed to load user data</Text>
        <TouchableOpacity style={styles.button} onPress={onLogout}>
          <Text style={styles.buttonText}>Back to Login</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.scrollView} contentContainerStyle={styles.scrollContent}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.title}>Welcome back!</Text>
          <Text style={styles.subtitle}>{user.full_name}</Text>
        </View>

        {/* User Info Card */}
        <Card style={styles.card}>
          <Text style={styles.cardTitle}>Your Profile</Text>
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Email:</Text>
            <Text style={styles.infoValue}>{user.email}</Text>
          </View>
          <View style={styles.infoRow}>
            <Text style={styles.infoLabel}>Name:</Text>
            <Text style={styles.infoValue}>{user.full_name}</Text>
          </View>
        </Card>

        {/* Organization Card */}
        {organization && (
          <Card style={styles.card}>
            <Text style={styles.cardTitle}>Organization</Text>
            <View style={styles.infoRow}>
              <Text style={styles.infoLabel}>Name:</Text>
              <Text style={styles.infoValue}>{organization.name}</Text>
            </View>
            <View style={styles.infoRow}>
              <Text style={styles.infoLabel}>Plan:</Text>
              <Badge variant="info">{user?.plan}</Badge>
            </View>
          </Card>
        )}

        {/* Membership Card */}
        {membership && (
          <Card style={styles.card}>
            <Text style={styles.cardTitle}>Your Role</Text>
            <View style={styles.infoRow}>
              <Text style={styles.infoLabel}>Role:</Text>
              <Badge variant="success">{membership.role}</Badge>
            </View>
            <View style={styles.infoRow}>
              <Text style={styles.infoLabel}>Branch:</Text>
              <Text style={styles.infoValue}>{membership.branch_name}</Text>
            </View>
          </Card>
        )}

        {/* Logout Button */}
        <TouchableOpacity style={styles.logoutButton} onPress={handleLogout}>
          <Text style={styles.logoutButtonText}>Logout</Text>
        </TouchableOpacity>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.backgroundSubtle,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: spacing.lg,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: colors.backgroundSubtle,
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.xl,
    backgroundColor: colors.backgroundSubtle,
  },
  errorText: {
    ...typography.body,
    color: colors.danger,
    marginBottom: spacing.lg,
    textAlign: 'center',
  },
  header: {
    marginBottom: spacing.xl,
  },
  title: {
    ...typography.h1,
    marginBottom: spacing.xs,
  },
  subtitle: {
    ...typography.body,
    color: colors.textSecondary,
  },
  card: {
    marginBottom: spacing.lg,
  },
  cardTitle: {
    ...typography.h3,
    marginBottom: spacing.md,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  infoLabel: {
    ...typography.label,
    color: colors.textSecondary,
  },
  infoValue: {
    ...typography.body,
    fontWeight: '500',
  },
  button: {
    backgroundColor: colors.primary,
    borderRadius: borderRadius.md,
    padding: spacing.lg,
    alignItems: 'center',
    minWidth: 200,
  },
  buttonText: {
    ...typography.label,
    color: colors.white,
    fontSize: 16,
    fontWeight: '600',
  },
  logoutButton: {
    backgroundColor: colors.danger,
    borderRadius: borderRadius.md,
    padding: spacing.lg,
    alignItems: 'center',
    marginTop: spacing.lg,
  },
  logoutButtonText: {
    ...typography.label,
    color: colors.white,
    fontSize: 16,
    fontWeight: '600',
  },
});
