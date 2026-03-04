// @ts-nocheck — tsconfig resolution handled by Expo CLI; run via `npx expo start`
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  Alert,
  Switch,
} from 'react-native';
import { AppBar, Card, ListItem } from '../components';
import { colors, spacing, typography, borderRadius, shadows } from '../theme';

// ─── Types ──────────────────────────────────────────────────────────────────
interface UserProfile {
  id: number;
  full_name: string;
  email: string;
  phone: string | null;
}

interface OrgInfo {
  id: number;
  name: string;
  plan: string;
  contact_email: string;
  city: string;
  state: string;
}

interface MembershipInfo {
  role: { name: string };
  branch: { name: string } | null;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
const BASE_URL = process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:3000';

async function apiFetch(path: string, token: string, orgId: string) {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: {
      Authorization:       `Bearer ${token}`,
      'X-Organization-Id': orgId,
      'Content-Type':      'application/json',
    },
  });
  return res.json();
}

// ─── SettingsScreen ───────────────────────────────────────────────────────────
export default function SettingsScreen({ navigation }: { navigation: any }) {
  const [profile, setProfile]         = useState<UserProfile | null>(null);
  const [org, setOrg]                 = useState<OrgInfo | null>(null);
  const [membership, setMembership]   = useState<MembershipInfo | null>(null);
  const [notifications, setNotifications] = useState(true);
  const [loading, setLoading]         = useState(true);

  // In a real app these come from secure storage / auth context
  const token = '';  // TODO: pull from AsyncStorage / AuthContext
  const orgId = '';  // TODO: pull from AsyncStorage / AuthContext

  useEffect(() => {
    const loadData = async () => {
      try {
        const [profileJson, orgJson] = await Promise.all([
          apiFetch('/api/v1/profile', token, orgId),
          orgId ? apiFetch(`/api/v1/organizations/${orgId}`, token, orgId) : Promise.resolve(null),
        ]);
        if (profileJson?.data) setProfile(profileJson.data);
        if (orgJson?.data)     setOrg(orgJson.data);
      } finally {
        setLoading(false);
      }
    };
    loadData();
  }, [token, orgId]);

  const handleLogout = () => {
    Alert.alert(
      'Log Out',
      'Are you sure you want to log out?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Log Out',
          style: 'destructive',
          onPress: async () => {
            await fetch(`${BASE_URL}/api/v1/auth/logout`, {
              method:  'DELETE',
              headers: { Authorization: `Bearer ${token}` },
            });
            navigation?.reset({ index: 0, routes: [{ name: 'Login' }] });
          },
        },
      ]
    );
  };

  const initials = profile
    ? `${profile.full_name.split(' ')[0]?.[0] ?? ''}${profile.full_name.split(' ')[1]?.[0] ?? ''}`.toUpperCase()
    : '?';

  return (
    <View style={styles.container}>
      <AppBar title="Settings" />

      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>

        {/* ── Profile Card ───────────────────────────────────────────────── */}
        <Card style={styles.profileCard}>
          <View style={styles.avatarRow}>
            <View style={styles.avatar}>
              <Text style={styles.avatarText}>{initials}</Text>
            </View>
            <View style={styles.profileInfo}>
              <Text style={styles.profileName}>{profile?.full_name ?? '—'}</Text>
              <Text style={styles.profileEmail}>{profile?.email ?? '—'}</Text>
              {membership && (
                <View style={styles.rolePill}>
                  <Text style={styles.rolePillText}>
                    {membership.role.name.replace(/_/g, ' ')}
                    {membership.branch ? `  ·  ${membership.branch.name}` : ''}
                  </Text>
                </View>
              )}
            </View>
          </View>
        </Card>

        {/* ── Organization ───────────────────────────────────────────────── */}
        {org && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Organization</Text>
            <Card>
              <ListItem title="Name"          subtitle={org.name}          showDivider />
              <ListItem title="Plan"          subtitle={org.plan.charAt(0).toUpperCase() + org.plan.slice(1)} showDivider />
              <ListItem title="Location"      subtitle={[org.city, org.state].filter(Boolean).join(', ') || '—'} showDivider />
              <ListItem title="Contact Email" subtitle={org.contact_email || '—'} showDivider={false} />
            </Card>
          </View>
        )}

        {/* ── Account ────────────────────────────────────────────────────── */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Account</Text>
          <Card>
            <ListItem
              title="Edit Profile"
              onPress={() => navigation?.navigate('EditProfile')}
              showDivider
            />
            <ListItem
              title="Change Password"
              onPress={() => navigation?.navigate('ChangePassword')}
              showDivider
            />
            <ListItem
              title="Push Notifications"
              showDivider={false}
              rightElement={
                <Switch
                  value={notifications}
                  onValueChange={setNotifications}
                  trackColor={{ false: colors.border, true: colors.accent }}
                  thumbColor={colors.white}
                />
              }
            />
          </Card>
        </View>

        {/* ── App Info ───────────────────────────────────────────────────── */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>App</Text>
          <Card>
            <ListItem title="Version"        subtitle="1.0.0" showDivider />
            <ListItem title="Help & Support"  onPress={() => {}} showDivider />
            <ListItem title="Privacy Policy"  onPress={() => {}} showDivider={false} />
          </Card>
        </View>

        {/* ── Log Out ────────────────────────────────────────────────────── */}
        <TouchableOpacity style={styles.logoutBtn} onPress={handleLogout} activeOpacity={0.7}>
          <Text style={styles.logoutText}>Log Out</Text>
        </TouchableOpacity>

      </ScrollView>
    </View>
  );
}

// ─── Styles ──────────────────────────────────────────────────────────────────
const styles = StyleSheet.create({
  container: {
    flex:            1,
    backgroundColor: colors.backgroundSubtle,
  },
  scroll: {
    padding:       spacing.lg,
    paddingBottom: spacing.xxl,
  },
  profileCard: {
    marginBottom: spacing.lg,
  },
  avatarRow: {
    flexDirection: 'row',
    alignItems:    'center',
    gap:           spacing.md,
  },
  avatar: {
    width:           56,
    height:          56,
    borderRadius:    28,
    backgroundColor: colors.primary,
    alignItems:      'center',
    justifyContent:  'center',
  },
  avatarText: {
    ...typography.h3,
    color: colors.white,
  },
  profileInfo: {
    flex: 1,
  },
  profileName: {
    ...typography.h3,
  },
  profileEmail: {
    ...typography.bodySmall,
    marginTop: 2,
  },
  rolePill: {
    marginTop:       spacing.xs,
    alignSelf:       'flex-start',
    backgroundColor: colors.accent + '20',
    borderRadius:    borderRadius.full,
    paddingHorizontal: spacing.sm,
    paddingVertical:   2,
  },
  rolePillText: {
    ...typography.bodySmall,
    color:      colors.primary,
    fontWeight: '500' as const,
    textTransform: 'capitalize' as const,
  },
  section: {
    marginBottom: spacing.lg,
  },
  sectionTitle: {
    ...typography.label,
    color:        colors.textSecondary,
    textTransform:'uppercase' as const,
    letterSpacing: 0.5,
    marginBottom:  spacing.sm,
  },
  logoutBtn: {
    marginTop:       spacing.sm,
    borderRadius:    borderRadius.lg,
    backgroundColor: '#FEF2F2',
    paddingVertical: spacing.md,
    alignItems:      'center',
    ...shadows.sm,
  },
  logoutText: {
    ...typography.body,
    color:      '#DC2626',
    fontWeight: '600' as const,
  },
});
