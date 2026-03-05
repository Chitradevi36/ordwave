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
import { StatusPill } from '../components/StatusPill';
import { AppBar } from '../components/AppBar';

const API_BASE = 'http://localhost:3001/api/v1';

interface TripStop {
  id: number;
  sequence: number;
  status: string;
  sales_order: {
    id: number;
    order_number: string;
    customer: { name: string; address?: string };
    total_amount: number;
  };
}

interface Trip {
  id: number;
  trip_number: string;
  trip_date: string;
  status: string;
  stops_count: number;
  branch: { name: string };
  vehicle: { registration_number: string } | null;
  stops?: TripStop[];
}

interface TripDetailScreenProps {
  trip: Trip;
  onBack: () => void;
  onCompleteStop: (stop: TripStop, trip: Trip) => void;
}

export default function TripDetailScreen({ trip: initialTrip, onBack, onCompleteStop }: TripDetailScreenProps) {
  const [trip, setTrip]         = useState<Trip>(initialTrip);
  const [stops, setStops]       = useState<TripStop[]>([]);
  const [loading, setLoading]   = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const loadStops = useCallback(async (isRefresh = false) => {
    try {
      const token  = await AsyncStorage.getItem('auth_token');
      const orgId  = await AsyncStorage.getItem('organization_id');
      if (!token || !orgId) return;

      if (!isRefresh) setLoading(true);

      const res  = await fetch(`${API_BASE}/delivery_trips/${trip.id}/trip_stops`, {
        headers: {
          Authorization:      `Bearer ${token}`,
          'X-Organization-Id': orgId,
        },
      });

      const json = await res.json();
      if (res.ok) {
        setStops(json.data ?? []);
      }
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [trip.id]);

  useEffect(() => { void loadStops(); }, [loadStops]);

  const completedCount = stops.filter((s) =>
    ['delivered', 'partial_delivery', 'failed', 'skipped'].includes(s.status)
  ).length;

  const statusColor = (status: string) => {
    const map: Record<string, string> = {
      pending:          colors.textSecondary,
      delivered:        '#16A34A',
      partial_delivery: colors.warning,
      failed:           colors.danger,
      skipped:          colors.textSecondary,
    };
    return map[status] ?? colors.textSecondary;
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <AppBar title={trip.trip_number} leftAction={<TouchableOpacity onPress={onBack}><Text style={styles.backBtn}>‹ Back</Text></TouchableOpacity>} />
        <ActivityIndicator style={{ marginTop: 60 }} color={colors.primary} />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <AppBar title={trip.trip_number} leftAction={<TouchableOpacity onPress={onBack}><Text style={styles.backBtn}>‹ Back</Text></TouchableOpacity>} />

      <ScrollView
        contentContainerStyle={styles.scroll}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={() => { setRefreshing(true); void loadStops(true); }} />
        }
      >
        {/* Trip meta */}
        <Card style={styles.metaCard}>
          <View style={styles.metaRow}>
            <Text style={styles.metaLabel}>Date</Text>
            <Text style={styles.metaValue}>
              {new Date(trip.trip_date).toLocaleDateString('en-IN')}
            </Text>
          </View>
          <View style={styles.metaRow}>
            <Text style={styles.metaLabel}>Vehicle</Text>
            <Text style={styles.metaValue}>
              {trip.vehicle?.registration_number ?? '—'}
            </Text>
          </View>
          <View style={[styles.metaRow, { borderBottomWidth: 0 }]}>
            <Text style={styles.metaLabel}>Progress</Text>
            <Text style={styles.metaValue}>
              {completedCount} / {stops.length} stops
            </Text>
          </View>
        </Card>

        {/* Progress bar */}
        <View style={styles.progressTrack}>
          <View
            style={[
              styles.progressFill,
              { width: stops.length > 0 ? `${(completedCount / stops.length) * 100}%` as any : '0%' },
            ]}
          />
        </View>

        {/* Stops */}
        <Text style={styles.sectionTitle}>Stops</Text>
        {stops.length === 0 ? (
          <Text style={styles.emptyText}>No stops on this trip.</Text>
        ) : (
          stops.map((stop) => {
            const pending = stop.status === 'pending';
            const tripDispatched = trip.status === 'dispatched';

            return (
              <TouchableOpacity
                key={stop.id}
                onPress={() => pending && tripDispatched && onCompleteStop(stop, trip)}
                activeOpacity={pending && tripDispatched ? 0.7 : 1}
              >
                <Card style={[styles.stopCard, !pending && styles.stopCardDone]}>
                  <View style={styles.stopRow}>
                    <View style={styles.seqBadge}>
                      <Text style={styles.seqText}>{stop.sequence}</Text>
                    </View>
                    <View style={styles.stopInfo}>
                      <Text style={styles.customerName} numberOfLines={1}>
                        {stop.sales_order.customer.name}
                      </Text>
                      <Text style={styles.orderNumber}>{stop.sales_order.order_number}</Text>
                      {stop.sales_order.customer.address ? (
                        <Text style={styles.address} numberOfLines={2}>
                          {stop.sales_order.customer.address}
                        </Text>
                      ) : null}
                    </View>
                    <View style={styles.stopRight}>
                      <Text style={styles.amount}>
                        ₹{Number(stop.sales_order.total_amount).toLocaleString('en-IN', {
                          maximumFractionDigits: 0,
                        })}
                      </Text>
                      <Text style={[styles.stopStatus, { color: statusColor(stop.status) }]}>
                        {stop.status.replace(/_/g, ' ')}
                      </Text>
                      {pending && tripDispatched && (
                        <Text style={styles.tapHint}>Tap to complete →</Text>
                      )}
                    </View>
                  </View>
                </Card>
              </TouchableOpacity>
            );
          })
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  backBtn: { color: colors.white, fontSize: 16, paddingRight: spacing.sm },
  container:  { flex: 1, backgroundColor: colors.backgroundSubtle },
  scroll:     { padding: spacing.lg, paddingBottom: 40 },
  metaCard:   { marginBottom: spacing.md },
  metaRow:    { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: spacing.sm, borderBottomWidth: 1, borderBottomColor: colors.border },
  metaLabel:  { ...typography.bodySmall },
  metaValue:  { ...typography.label },
  progressTrack: { height: 6, backgroundColor: colors.border, borderRadius: borderRadius.full, marginBottom: spacing.lg, overflow: 'hidden' },
  progressFill:  { height: '100%', backgroundColor: colors.accent, borderRadius: borderRadius.full },
  sectionTitle:  { ...typography.h3, marginBottom: spacing.sm },
  emptyText:     { ...typography.body, color: colors.textSecondary, textAlign: 'center', paddingVertical: spacing.xl },
  stopCard:      { marginBottom: spacing.sm },
  stopCardDone:  { opacity: 0.7 },
  stopRow:       { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.sm },
  seqBadge:      { width: 28, height: 28, borderRadius: borderRadius.full, backgroundColor: colors.primary, alignItems: 'center', justifyContent: 'center' },
  seqText:       { color: colors.white, fontSize: 12, fontWeight: '700' },
  stopInfo:      { flex: 1, minWidth: 0 },
  customerName:  { ...typography.label, marginBottom: 2 },
  orderNumber:   { ...typography.bodySmall, fontFamily: 'monospace' },
  address:       { ...typography.bodySmall, marginTop: 2 },
  stopRight:     { alignItems: 'flex-end', minWidth: 80 },
  amount:        { ...typography.label, tabularNums: true } as any,
  stopStatus:    { fontSize: 11, fontWeight: '500', textTransform: 'capitalize', marginTop: 2 },
  tapHint:       { fontSize: 10, color: colors.accent, marginTop: 4 },
});
