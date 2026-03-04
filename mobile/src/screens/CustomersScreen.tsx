import React, { useState, useEffect, useCallback } from 'react';
import {
  View, Text, StyleSheet, FlatList, TouchableOpacity,
  SafeAreaView, TextInput, ActivityIndicator, ScrollView,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { colors, spacing, typography, borderRadius, shadows } from '../theme';
import { Card } from '../components/Card';
import { StatusPill } from '../components/StatusPill';

// ─── Types ────────────────────────────────────────────────────────────────────
interface Customer {
  id: number;
  name: string;
  code: string;
  channel: string;
  tier: string;
  status: string;
  phone: string | null;
  route: { id: number; name: string } | null;
  credit_account: {
    available_credit: number;
    overdue_amount: number;
  } | null;
}

interface CustomersScreenProps {
  onSelectCustomer?: (id: number) => void;
}

const CHANNEL_LABELS: Record<string, string> = {
  general_trade: 'General Trade',
  modern_trade: 'Modern Trade',
  horeca: 'HoReCa',
  pharmacy: 'Pharmacy',
  electronics: 'Electronics',
  wholesale: 'Wholesale',
  distributor: 'Distributor',
};

const CHANNELS = ['general_trade', 'modern_trade', 'horeca', 'pharmacy', 'electronics', 'wholesale', 'distributor'];

// ─── Customer Card ────────────────────────────────────────────────────────────
function CustomerCard({ customer, onPress }: { customer: Customer; onPress: () => void }) {
  const hasOverdue  = (customer.credit_account?.overdue_amount ?? 0) > 0;
  const isBlocked   = customer.status === 'blocked';

  return (
    <TouchableOpacity onPress={onPress} activeOpacity={0.7}>
      <Card style={[styles.customerCard, isBlocked && styles.customerCardBlocked]}>
        <View style={styles.cardTop}>
          <View style={styles.cardInfo}>
            <Text style={styles.customerName}>{customer.name}</Text>
            <Text style={styles.customerCode}>{customer.code}</Text>
          </View>
          <View style={styles.badgeRow}>
            {isBlocked && (
              <StatusPill label="Blocked" variant="danger" />
            )}
            <StatusPill
              label={customer.tier.charAt(0).toUpperCase() + customer.tier.slice(1)}
              variant={customer.tier === 'platinum' ? 'info' : customer.tier === 'gold' ? 'warning' : 'neutral'}
            />
          </View>
        </View>

        <View style={styles.cardMeta}>
          <Text style={styles.metaText}>
            {CHANNEL_LABELS[customer.channel] ?? customer.channel}
          </Text>
          {customer.route && (
            <Text style={styles.metaText}> · {customer.route.name}</Text>
          )}
        </View>

        {customer.credit_account && (
          <View style={styles.creditRow}>
            <Text style={styles.creditLabel}>Available</Text>
            <Text style={styles.creditValue}>
              ₹{customer.credit_account.available_credit.toLocaleString('en-IN')}
            </Text>
            {hasOverdue && (
              <Text style={styles.overdueText}>
                {' '}· ₹{customer.credit_account.overdue_amount.toLocaleString('en-IN')} overdue
              </Text>
            )}
          </View>
        )}
      </Card>
    </TouchableOpacity>
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────
export default function CustomersScreen({ onSelectCustomer }: CustomersScreenProps) {
  const [customers,     setCustomers]     = useState<Customer[]>([]);
  const [loading,       setLoading]       = useState(false);
  const [search,        setSearch]        = useState('');
  const [channel,       setChannel]       = useState('');
  const [statusFilter,  setStatusFilter]  = useState('');
  const [page,          setPage]          = useState(1);
  const [hasMore,       setHasMore]       = useState(true);

  const fetchCustomers = useCallback(async (reset = false) => {
    setLoading(true);
    try {
      const token = await AsyncStorage.getItem('auth_token');
      const orgId = await AsyncStorage.getItem('org_id');
      if (!token || !orgId) return;

      const currentPage = reset ? 1 : page;
      const qs = new URLSearchParams({ page: String(currentPage), per_page: '20' });
      if (search)        qs.set('q', search);
      if (channel)       qs.set('channel', channel);
      if (statusFilter)  qs.set('status', statusFilter);

      const res  = await fetch(`http://localhost:3001/api/v1/customers?${qs}`, {
        headers: { Authorization: `Bearer ${token}`, 'X-Organization-Id': orgId },
      });
      const json = await res.json();

      if (res.ok) {
        const newData: Customer[] = json.data ?? [];
        setCustomers(reset ? newData : (prev: Customer[]) => [...prev, ...newData]);
        setHasMore(currentPage < (json.meta?.total_pages ?? 1));
        if (reset) setPage(1);
      }
    } finally {
      setLoading(false);
    }
  }, [page, search, channel, statusFilter]);

  useEffect(() => {
    fetchCustomers(true);
  }, [search, channel, statusFilter]); // eslint-disable-line react-hooks/exhaustive-deps

  const loadMore = () => {
    if (!loading && hasMore) {
      setPage((p: number) => p + 1);
      fetchCustomers();
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Customers</Text>
      </View>

      {/* Search */}
      <View style={styles.searchContainer}>
        <TextInput
          style={styles.searchInput}
          placeholder="Search by name, code, phone…"
          placeholderTextColor={colors.textSecondary}
          value={search}
          onChangeText={(t) => setSearch(t)}
          returnKeyType="search"
        />
      </View>

      {/* Channel filter chips */}
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.chipsContainer}
      >
        <TouchableOpacity
          style={[styles.chip, channel === '' && styles.chipActive]}
          onPress={() => setChannel('')}
        >
          <Text style={[styles.chipText, channel === '' && styles.chipTextActive]}>All</Text>
        </TouchableOpacity>
        {CHANNELS.map((c) => (
          <TouchableOpacity
            key={c}
            style={[styles.chip, channel === c && styles.chipActive]}
            onPress={() => setChannel(c === channel ? '' : c)}
          >
            <Text style={[styles.chipText, channel === c && styles.chipTextActive]}>
              {CHANNEL_LABELS[c]}
            </Text>
          </TouchableOpacity>
        ))}
        <TouchableOpacity
          style={[styles.chip, statusFilter === 'blocked' && styles.chipActive]}
          onPress={() => setStatusFilter(statusFilter === 'blocked' ? '' : 'blocked')}
        >
          <Text style={[styles.chipText, statusFilter === 'blocked' && styles.chipTextActive]}>Blocked</Text>
        </TouchableOpacity>
      </ScrollView>

      {/* List */}
      {loading && customers.length === 0 ? (
        <View style={styles.centered}>
          <ActivityIndicator size="large" color={colors.accent} />
        </View>
      ) : (
        <FlatList
          data={customers}
          keyExtractor={(item) => String(item.id)}
          contentContainerStyle={styles.list}
          onEndReached={loadMore}
          onEndReachedThreshold={0.4}
          ListEmptyComponent={
            <View style={styles.centered}>
              <Text style={styles.emptyText}>No customers found.</Text>
            </View>
          }
          ListFooterComponent={
            loading ? <ActivityIndicator style={{ marginVertical: spacing.lg }} color={colors.accent} /> : null
          }
          renderItem={({ item }) => (
            <CustomerCard
              customer={item}
              onPress={() => onSelectCustomer?.(item.id)}
            />
          )}
        />
      )}
    </SafeAreaView>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────
const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.backgroundSubtle,
  },
  header: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
    paddingBottom: spacing.sm,
  },
  title: {
    ...typography.h2,
  },
  searchContainer: {
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.sm,
  },
  searchInput: {
    height: 40,
    borderRadius: borderRadius.md,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.background,
    paddingHorizontal: spacing.md,
    fontSize: 14,
    color: colors.textPrimary,
  },
  chipsContainer: {
    paddingHorizontal: spacing.lg,
    gap: spacing.sm,
    paddingBottom: spacing.md,
  },
  chip: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: borderRadius.full,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.background,
    marginRight: spacing.sm,
  },
  chipActive: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  chipText: {
    fontSize: 12,
    fontWeight: '500',
    color: colors.textSecondary,
  },
  chipTextActive: {
    color: colors.white,
  },
  list: {
    padding: spacing.lg,
    paddingTop: spacing.sm,
  },
  customerCard: {
    marginBottom: spacing.md,
    ...shadows.sm,
  },
  customerCardBlocked: {
    borderColor: colors.danger,
    opacity: 0.85,
  },
  cardTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: spacing.xs,
  },
  badgeRow: {
    flexDirection: 'row',
    gap: spacing.xs,
    alignItems: 'center',
  },
  cardInfo: {
    flex: 1,
    marginRight: spacing.sm,
  },
  customerName: {
    ...typography.label,
    fontSize: 15,
    fontWeight: '600',
  },
  customerCode: {
    ...typography.bodySmall,
    marginTop: 2,
  },
  cardMeta: {
    flexDirection: 'row',
    marginBottom: spacing.sm,
  },
  metaText: {
    ...typography.bodySmall,
  },
  creditRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingTop: spacing.sm,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  creditLabel: {
    ...typography.bodySmall,
    marginRight: spacing.xs,
  },
  creditValue: {
    fontSize: 13,
    fontWeight: '600',
    color: colors.primary,
  },
  overdueText: {
    fontSize: 12,
    color: colors.danger,
  },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.xl,
  },
  emptyText: {
    ...typography.body,
    color: colors.textSecondary,
    textAlign: 'center',
  },
});
