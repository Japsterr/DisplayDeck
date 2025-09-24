import { useQuery } from '@tanstack/react-query';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { apiService } from '@/services/api';
import { BusinessList } from './BusinessList';
import { Building, Menu, Monitor, TrendingUp, Clock } from 'lucide-react';

interface BusinessStats {
  totalBusinesses: number;
  totalMenus: number;
  totalDisplays: number;
  totalViews: number;
}

export function BusinessDashboard() {
  const { data: businesses, isLoading: businessesLoading } = useQuery({
    queryKey: ['businesses'],
    queryFn: () => apiService.getBusinesses(),
  });

  // Calculate stats from businesses data
  const stats: BusinessStats = {
    totalBusinesses: businesses?.length || 0,
    totalMenus: 0, // Will be populated when menu API is integrated
    totalDisplays: 0, // Will be populated when display API is integrated
    totalViews: 0, // Will be populated when analytics API is integrated
  };

  if (businessesLoading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Stats Overview */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Businesses</CardTitle>
            <Building className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.totalBusinesses}</div>
            <p className="text-xs text-muted-foreground">
              {stats.totalBusinesses === 0 ? 'No businesses yet' : 'Active locations'}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Menus</CardTitle>
            <Menu className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.totalMenus}</div>
            <p className="text-xs text-muted-foreground">
              {stats.totalMenus === 0 ? 'No menus created' : 'Published menus'}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Connected Displays</CardTitle>
            <Monitor className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.totalDisplays}</div>
            <p className="text-xs text-muted-foreground">
              {stats.totalDisplays === 0 ? 'No displays connected' : 'Active displays'}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Menu Views</CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.totalViews}</div>
            <p className="text-xs text-muted-foreground">
              {stats.totalViews === 0 ? 'No views tracked' : 'This month'}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Quick Actions */}
      {stats.totalBusinesses === 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Get Started</CardTitle>
            <CardDescription>
              Welcome to DisplayDeck! Follow these steps to set up your digital menu system.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid gap-4 md:grid-cols-3">
              <div className="border-2 border-dashed border-gray-200 rounded-lg p-6 text-center">
                <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                  <Building className="h-6 w-6 text-blue-600" />
                </div>
                <h3 className="font-medium text-gray-900 mb-2">1. Create Business</h3>
                <p className="text-sm text-gray-500 mb-4">Set up your first business location</p>
                <Button size="sm" className="w-full">
                  Add Business
                </Button>
              </div>

              <div className="border-2 border-dashed border-gray-200 rounded-lg p-6 text-center opacity-50">
                <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                  <Menu className="h-6 w-6 text-green-600" />
                </div>
                <h3 className="font-medium text-gray-900 mb-2">2. Create Menu</h3>
                <p className="text-sm text-gray-500 mb-4">Design your digital menu</p>
                <Button size="sm" className="w-full" disabled>
                  Create Menu
                </Button>
              </div>

              <div className="border-2 border-dashed border-gray-200 rounded-lg p-6 text-center opacity-50">
                <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                  <Monitor className="h-6 w-6 text-purple-600" />
                </div>
                <h3 className="font-medium text-gray-900 mb-2">3. Connect Display</h3>
                <p className="text-sm text-gray-500 mb-4">Add a display device</p>
                <Button size="sm" className="w-full" disabled>
                  Connect Display
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Recent Activity */}
      {stats.totalBusinesses > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <Clock className="h-5 w-5 mr-2" />
              Recent Activity
            </CardTitle>
            <CardDescription>
              Latest updates across your businesses
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="text-center py-8">
              <p className="text-gray-500">No recent activity to show</p>
              <p className="text-sm text-gray-400 mt-2">
                Activity will appear here once you start using your menus and displays
              </p>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Business List */}
      <BusinessList />
    </div>
  );
}