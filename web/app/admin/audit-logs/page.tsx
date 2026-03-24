'use client';

import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { format } from 'date-fns';
import { ChevronRight, Calendar, Filter, Download, Search } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { apiClient } from '@/lib/api/client';

interface AuditLog {
  id: string;
  action_type: string;
  resource_type: string;
  resource_name: string;
  admin_user: {
    id: string;
    email: string;
    name: string;
  };
  changes: Record<string, [string, string]>;
  reason?: string;
  created_at: string;
  status: string;
}

interface PaginationMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
}

const ACTION_TYPE_COLORS = {
  create: 'bg-green-100 text-green-800',
  update: 'bg-blue-100 text-blue-800',
  delete: 'bg-red-100 text-red-800',
  restore: 'bg-purple-100 text-purple-800',
  approve: 'bg-yellow-100 text-yellow-800',
  reject: 'bg-orange-100 text-orange-800',
};

export default function AdminAuditLogsPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [pagination, setPagination] = useState<PaginationMeta | null>(null);
  const [filters, setFilters] = useState({
    action_type: searchParams.get('action_type') || '',
    resource_type: searchParams.get('resource_type') || '',
    search: searchParams.get('search') || '',
    start_date: searchParams.get('start_date') || '',
    end_date: searchParams.get('end_date') || '',
    page: parseInt(searchParams.get('page') || '1'),
  });

  useEffect(() => {
    fetchLogs();
  }, [filters]);

  const fetchLogs = async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams();
      
      if (filters.action_type) params.append('action_type', filters.action_type);
      if (filters.resource_type) params.append('resource_type', filters.resource_type);
      if (filters.start_date) params.append('start_date', filters.start_date);
      if (filters.end_date) params.append('end_date', filters.end_date);
      params.append('page', filters.page.toString());

      const response = await apiClient.get(`/admin/audit_logs?${params.toString()}`);
      
      setLogs(response.data.data || []);
      setPagination(response.data.meta || {});
    } catch (error) {
      console.error('Failed to fetch audit logs:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleFilterChange = (key: string, value: string) => {
    setFilters(prev => ({
      ...prev,
      [key]: value,
      page: 1, // Reset to first page when filters change
    }));
  };

  const handleExportCSV = async () => {
    try {
      const params = new URLSearchParams();
      if (filters.action_type) params.append('action_type', filters.action_type);
      if (filters.resource_type) params.append('resource_type', filters.resource_type);
      if (filters.start_date) params.append('start_date', filters.start_date);
      if (filters.end_date) params.append('end_date', filters.end_date);
      params.append('format', 'csv');

      window.location.href = `/api/v1/admin/audit_logs?${params.toString()}`;
    } catch (error) {
      console.error('Failed to export:', error);
    }
  };

  const getActionColor = (actionType: string) => {
    return (
      ACTION_TYPE_COLORS[actionType as keyof typeof ACTION_TYPE_COLORS] ||
      'bg-gray-100 text-gray-800'
    );
  };

  const formatChangeValue = (value: any) => {
    if (value === null) return '(empty)';
    if (typeof value === 'object') return JSON.stringify(value);
    return String(value);
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-6 py-6">
          <h1 className="text-3xl font-bold text-gray-900">Audit Logs</h1>
          <p className="text-gray-600 mt-1">Track all administrative actions and changes</p>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-6 py-8">
        {/* Filters */}
        <div className="bg-white rounded-lg shadow-sm p-6 mb-8">
          <div className="flex items-center gap-2 mb-4">
            <Filter className="h-5 w-5 text-gray-600" />
            <h2 className="font-semibold text-gray-900">Filters</h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
            {/* Action Type Filter */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Action Type
              </label>
              <select
                value={filters.action_type}
                onChange={(e) => handleFilterChange('action_type', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">All Actions</option>
                <option value="create">Create</option>
                <option value="update">Update</option>
                <option value="delete">Delete</option>
                <option value="restore">Restore</option>
              </select>
            </div>

            {/* Resource Type Filter */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Resource Type
              </label>
              <select
                value={filters.resource_type}
                onChange={(e) => handleFilterChange('resource_type', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">All Resources</option>
                <option value="User">User</option>
                <option value="Organization">Organization</option>
                <option value="Settings">Settings</option>
                <option value="Permission">Permission</option>
              </select>
            </div>

            {/* Start Date */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Start Date
              </label>
              <Input
                type="date"
                value={filters.start_date}
                onChange={(e) => handleFilterChange('start_date', e.target.value)}
                className="w-full"
              />
            </div>

            {/* End Date */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                End Date
              </label>
              <Input
                type="date"
                value={filters.end_date}
                onChange={(e) => handleFilterChange('end_date', e.target.value)}
                className="w-full"
              />
            </div>

            {/* Export Button */}
            <div className="flex items-end">
              <Button
                onClick={handleExportCSV}
                variant="outline"
                className="w-full flex items-center justify-center gap-2"
              >
                <Download className="h-4 w-4" />
                Export CSV
              </Button>
            </div>
          </div>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
          {pagination && (
            <>
              <div className="bg-white rounded-lg shadow-sm p-6">
                <p className="text-sm text-gray-600">Total Records</p>
                <p className="text-2xl font-bold text-gray-900">{pagination.total_count}</p>
              </div>
              <div className="bg-white rounded-lg shadow-sm p-6">
                <p className="text-sm text-gray-600">Current Page</p>
                <p className="text-2xl font-bold text-gray-900">
                  {pagination.current_page} of {pagination.total_pages}
                </p>
              </div>
              <div className="bg-white rounded-lg shadow-sm p-6">
                <p className="text-sm text-gray-600">Records Per Page</p>
                <p className="text-2xl font-bold text-gray-900">{pagination.per_page}</p>
              </div>
              <div className="bg-white rounded-lg shadow-sm p-6">
                <p className="text-sm text-gray-600">Showing</p>
                <p className="text-2xl font-bold text-gray-900">
                  {logs.length}
                </p>
              </div>
            </>
          )}
        </div>

        {/* Logs Table */}
        <div className="bg-white rounded-lg shadow-sm overflow-hidden">
          {loading ? (
            <div className="p-8 text-center text-gray-500">
              <p>Loading audit logs...</p>
            </div>
          ) : logs.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              <p>No audit logs found matching your filters</p>
            </div>
          ) : (
            <>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead className="bg-gray-50 border-b border-gray-200">
                    <tr>
                      <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                        Action
                      </th>
                      <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                        Resource
                      </th>
                      <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                        Admin User
                      </th>
                      <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                        Changes
                      </th>
                      <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">
                        Date/Time
                      </th>
                      <th className="px-6 py-3 text-right text-sm font-semibold text-gray-900">
                        Details
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200">
                    {logs.map((log) => (
                      <tr key={log.id} className="hover:bg-gray-50 transition-colors">
                        <td className="px-6 py-4">
                          <span className={`px-3 py-1 rounded-full text-xs font-semibold ${getActionColor(log.action_type)}`}>
                            {log.action_type.toUpperCase()}
                          </span>
                        </td>
                        <td className="px-6 py-4">
                          <div>
                            <p className="text-sm font-medium text-gray-900">
                              {log.resource_type}
                            </p>
                            <p className="text-xs text-gray-600">
                              {log.resource_name}
                            </p>
                          </div>
                        </td>
                        <td className="px-6 py-4">
                          <div>
                            <p className="text-sm font-medium text-gray-900">
                              {log.admin_user.name}
                            </p>
                            <p className="text-xs text-gray-600">
                              {log.admin_user.email}
                            </p>
                          </div>
                        </td>
                        <td className="px-6 py-4">
                          <div className="text-sm text-gray-600 max-w-xs">
                            {Object.entries(log.changes).length > 0 ? (
                              <ul className="space-y-1">
                                {Object.entries(log.changes).slice(0, 2).map(([key, [oldVal, newVal]]) => (
                                  <li key={key} className="text-xs">
                                    <span className="font-medium">{key}:</span>{' '}
                                    <span className="text-red-600">
                                      {formatChangeValue(oldVal)}
                                    </span>
                                    {' → '}
                                    <span className="text-green-600">
                                      {formatChangeValue(newVal)}
                                    </span>
                                  </li>
                                ))}
                                {Object.entries(log.changes).length > 2 && (
                                  <li className="text-xs text-gray-500">
                                    +{Object.entries(log.changes).length - 2} more changes
                                  </li>
                                )}
                              </ul>
                            ) : (
                              <span className="text-gray-500 italic">No changes tracked</span>
                            )}
                          </div>
                        </td>
                        <td className="px-6 py-4 text-sm text-gray-600">
                          {format(new Date(log.created_at), 'MMM dd, yyyy HH:mm:ss')}
                        </td>
                        <td className="px-6 py-4 text-right">
                          <button
                            onClick={() => router.push(`/admin/audit-logs/${log.id}`)}
                            className="text-blue-600 hover:text-blue-800 transition-colors"
                          >
                            <ChevronRight className="h-5 w-5" />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* Pagination */}
              {pagination && pagination.total_pages > 1 && (
                <div className="border-t border-gray-200 px-6 py-4 flex items-center justify-between">
                  <Button
                    variant="outline"
                    onClick={() => 
                      handleFilterChange('page', Math.max(1, filters.page - 1).toString())
                    }
                    disabled={filters.page === 1}
                  >
                    Previous
                  </Button>
                  
                  <div className="flex items-center gap-2">
                    {Array.from({ length: pagination.total_pages }, (_, i) => i + 1)
                      .filter(p => Math.abs(p - filters.page) <= 2 || p === 1 || p === pagination.total_pages)
                      .map((page, idx, arr) => (
                        <div key={page}>
                          {idx > 0 && arr[idx - 1] !== page - 1 && (
                            <span className="px-2 text-gray-500">...</span>
                          )}
                          <button
                            onClick={() => handleFilterChange('page', page.toString())}
                            className={`px-3 py-1 rounded-lg transition-colors ${
                              filters.page === page
                                ? 'bg-blue-600 text-white'
                                : 'text-gray-700 hover:bg-gray-100'
                            }`}
                          >
                            {page}
                          </button>
                        </div>
                      ))}
                  </div>

                  <Button
                    variant="outline"
                    onClick={() =>
                      handleFilterChange('page', Math.min(pagination.total_pages, filters.page + 1).toString())
                    }
                    disabled={filters.page === pagination.total_pages}
                  >
                    Next
                  </Button>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
