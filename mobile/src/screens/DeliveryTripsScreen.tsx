import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  SafeAreaView,
  ScrollView,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { colors, spacing, typography, borderRadius } from '../theme';
import { Card } from '../components/Card';
import { AppBar } from '../components/AppBar';

const API_BASE = 'http://localhost:3001/api/v1';

export interface Trip {
  id: number;
  trip_number: string;
  trip_date: string;
  status: string;
  stops_count: number;
  branch: { name: string };
  vehicle: { registration_number: string; vehicle_type: string } | null;
  driver: { id: number; name: string } | null;
  dispatched_at: string | null;
}

interface DeliveryTripsScreenProps {
  onSelectTrip: (trip: Trip) => void;
}

const STATUS_COLOR: Record<string, string> = {
  draft:      colors.textSecondary,
  planned:    '#2563EB',
  dispatched: colors.warning,
  completed:  '#16A34A',
  cancelled:  colors.textSecondary,
};

export default function DeliveryTripsScreen({ onSelectTrip }: DeliveryTripsScreenProps) {
  const [trips, setTrips]       = useState<Trip[]>([]);
  const [loading, setLoading]   = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [filter, setFilter]     = useState<'today' | 'all'>('today');

  const loadTrips = useCallback(async (isRefresh = false) => {
    try {
      const token  = await AsyncStorage.getItem('auth_token');
      const orgId  = await AsyncStorage.getItem('organization_id');
      if (!token || !orgId) return;

      if (!isRefresh) setLoading(true);

      const today = new Date().toISOString().slice(0, 10);
      const qp    = new URLSearchParams({
        per_page: '50',
        status:   'dispatched',
      });
      if (filter === 'today') {
        qp.set('from_date', today);
        qp.set('to_date',   today);
      }

      const res  = await fetch(`${API_BASE}/delivery_trips?${qp}`, {
        headers: {
          Authorization:      `Bearer ${token}`,
          'X-Organization-Id': orgId,
        },
      });

      const json = await res.json();
      if (res.ok) setTrips(json.data ?? []);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [filter]);

  useEffect(() => { void loadTrips(); }, [loadTrips]);

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <AppBar title="My Trips" />
        <ActivityIndicator style={{ marginTop: 60 }} color={colors.primary} />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <AppBar title="My Trips" />

      {/* Filter toggle */}
      <View style={styles.filterRow}>
        {(['today', 'all'] as const).map((f) => (
          <TouchableOpacity
            key={f}
            style={[styles.filterBtn, filter === f && styles.filterBtnActive]}
            onPress={() => setFilter(f)}
          >
            <Text style={[styles.filterText, filter === f && styles.filterTextActive]}>
              {f === 'today' ? "Today's" : 'All'}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <ScrollView
        contentContainerStyle={styles.scroll}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={() => { setRefreshing(true); void loadTrips(true); }}
          />
        }
      >
        {trips.length === 0 ? (
          <View style={styles.emptyContainer}>
            <Text style={styles.emptyTitle}>No trips found</Text>
            <Text style={styles.emptySubtitle}>
              {filter === 'today' ? "No dispatched trips for today." : "No dispatched trips."}
            </Text>
          </View>
        ) : (
          trips.map((trip) => (
            <TouchableOpacity key={trip.id} onPress={() => onSelectTrip(trip)} activeOpacity={0.8}>
              <Card style={styles.tripCard}>
                <View style={styles.tripHeader}>
                  <Text style={styles.tripNumber}>{trip.trip_number}</Text>
                  <View style={[styles.statusDot, { backgroundColor: STATUS_COLOR[trip.status] ?? colors.textSecondary }]} />
                  <Text style={[styles.statusText, { color: STATUS_COLOR[trip.status] ?? colors.textSecondary }]}>
                    {trip.status}
                  </Text>
                </View>

                <View style={styles.tripMeta}>
                  <Text style={styles.tripMetaText}>
                    {new Date(trip.trip_date).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' })}
                  </Text>
                  <Text style={styles.tripMetaDot}>·</Text>
                  <Text style={styles.tripMetaText}>{trip.branch.name}</Text>
                  {trip.vehicle && (
                    <>
                      <Text style={styles.tripMetaDot}>·</Text>
                      <Text style={styles.tripMetaText}>{trip.vehicle.registration_number}</Text>
                    </>
                  )}
                </View>

                <View style={styles.tripFooter}>
                  <Text style={styles.stopsCount}>
                    {trip.stops_count} stop{trip.stops_count !== 1 ? 's' : ''}
                  </Text>
                  <Text style={styles.tapPrompt}>View stops →</Text>
                </View>
              </Card>
            </TouchableOpacity>
          ))
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container:       { flex: 1, backgroundColor: colors.backgroundSubtle },
  scroll:          { padding: spacing.lg, paddingBottom: 40 },
  filterRow:       { flexDirection: 'row', paddingHorizontal: spacing.lg, paddingTop: spacing.md, gap: spacing.sm },
  filterBtn:       { paddingHorizontal: spacing.md, paddingVertical: spacing.xs, borderRadius: borderRadius.full, backgroundColor: colors.border },
  filterBtnActive: { backgroundColor: colors.primary },
  filterText:      { ...typography.bodySmall, fontWeight: '600' },
  filterTextActive: { color: colors.white },
  emptyContainer:  { alignItems: 'center', paddingTop: 80 },
  emptyTitle:      { ...typography.h3, marginBottom: spacing.sm },
  emptySubtitle:   { ...typography.body, color: colors.textSecondary, textAlign: 'center' },
  tripCard:        { marginBottom: spacing.md },
  tripHeader:      { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginBottom: spacing.xs },
  tripNumber:      { ...typography.h3, flex: 1 },
  statusDot:       { width: 8, height: 8, borderRadius: 4 },
  statusText:      { ...typography.bodySmall, fontWeight: '600', textTransform: 'capitalize' },
  tripMeta:        { flexDirection: 'row', alignItems: 'center', gap: spacing.xs, marginBottom: spacing.sm },
  tripMetaText:    { ...typography.bodySmall },
  tripMetaDot:     { ...typography.bodySmall, color: colors.border },
  tripFooter:      { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingTop: spacing.sm, borderTopWidth: 1, borderTopColor: colors.border },
  stopsCount:      { ...typography.label },
  tapPrompt:       { ...typography.bodySmall, color: colors.accent, fontWeight: '600' },
});
