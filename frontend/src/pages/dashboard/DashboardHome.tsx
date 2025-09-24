import { useQuery } from '@tanstack/react-query';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { apiService, type Display, type Menu } from '@/services/api';
import { useAuth } from '@/contexts/AuthContext';
import { 
  Building, 
  BookOpen, 
  Monitor, 
  TrendingUp, 
  Activity,
  Plus,
  ArrowRight,
  AlertCircle,
  CheckCircle,
  Clock,
  Eye
} from 'lucide-react';
import { Link } from 'react-router-dom';

export function DashboardHome() {
  const { user } = useAuth();

  // Fetch dashboard data - for now, we'll use empty arrays since we don't have user-specific methods
  const { data: businesses = [], isLoading: businessesLoading } = useQuery({
    queryKey: ['businesses'],
    queryFn: () => apiService.getBusinesses(),
  });

  // Since we don't have user-specific methods yet, we'll use empty arrays
  const displays: Display[] = [];
  const menus: Menu[] = [];
  const displaysLoading = false;
  const menusLoading = false;

  // Calculate statistics
  const stats = {
    totalBusinesses: businesses?.length || 0,
    totalMenus: menus?.length || 0,
    totalDisplays: displays?.length || 0,
    activeDisplays: displays?.filter((d: Display) => d.is_active && d.is_paired)?.length || 0,
    recentMenus: menus?.filter((m: Menu) => {
      const createdAt = new Date(m.created_at);
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);
      return createdAt > weekAgo;
    })?.length || 0,
  };

  const isLoading = businessesLoading || displaysLoading || menusLoading;

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
            <p className="text-gray-600">Welcome back!</p>
          </div>
        </div>
        
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          {[...Array(4)].map((_, i) => (
            <Card key={i} className="animate-pulse">
              <CardContent className="p-6">
                <div className="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
                <div className="h-8 bg-gray-200 rounded w-1/2"></div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Welcome Section */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">
            Welcome back, {user?.first_name || 'User'}!
          </h1>
          <p className="text-gray-600">
            Here's what's happening with your digital menus today.
          </p>
        </div>
      </div>

      {/* Quick Stats */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center">
              <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                <Building className="h-6 w-6 text-blue-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Businesses</p>
                <p className="text-2xl font-bold text-gray-900">{stats.totalBusinesses}</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center">
              <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
                <BookOpen className="h-6 w-6 text-green-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Menus</p>
                <p className="text-2xl font-bold text-gray-900">{stats.totalMenus}</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center">
              <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
                <Monitor className="h-6 w-6 text-purple-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Displays</p>
                <p className="text-2xl font-bold text-gray-900">{stats.totalDisplays}</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center">
              <div className="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center">
                <Activity className="h-6 w-6 text-orange-600" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-600">Active Displays</p>
                <p className="text-2xl font-bold text-gray-900">{stats.activeDisplays}</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Quick Actions */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <Plus className="h-5 w-5 mr-2" />
              Quick Actions
            </CardTitle>
            <CardDescription>
              Get started with common tasks
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <Link to="/businesses/new">
              <Button variant="outline" className="w-full justify-start">
                <Building className="h-4 w-4 mr-2" />
                Create Business
              </Button>
            </Link>
            <Link to="/menus/new">
              <Button variant="outline" className="w-full justify-start">
                <BookOpen className="h-4 w-4 mr-2" />
                Create Menu
              </Button>
            </Link>
            <Link to="/displays">
              <Button variant="outline" className="w-full justify-start">
                <Monitor className="h-4 w-4 mr-2" />
                Add Display
              </Button>
            </Link>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <TrendingUp className="h-5 w-5 mr-2" />
              Recent Activity
            </CardTitle>
            <CardDescription>
              Latest updates and changes
            </CardDescription>
          </CardHeader>
          <CardContent>
            {stats.recentMenus > 0 ? (
              <div className="space-y-3">
                <div className="flex items-center text-sm text-gray-600">
                  <CheckCircle className="h-4 w-4 mr-2 text-green-500" />
                  <span>{stats.recentMenus} menu(s) created this week</span>
                </div>
                <div className="flex items-center text-sm text-gray-600">
                  <Activity className="h-4 w-4 mr-2 text-blue-500" />
                  <span>{stats.activeDisplays} displays active</span>
                </div>
              </div>
            ) : (
              <div className="text-center py-6">
                <Clock className="h-8 w-8 text-gray-400 mx-auto mb-2" />
                <p className="text-sm text-gray-500">No recent activity</p>
                <p className="text-xs text-gray-400 mt-1">
                  Create your first menu to see activity here
                </p>
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <AlertCircle className="h-5 w-5 mr-2" />
              System Status
            </CardTitle>
            <CardDescription>
              Overall system health
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">API Status</span>
                <div className="flex items-center">
                  <div className="w-2 h-2 bg-green-500 rounded-full mr-2"></div>
                  <span className="text-sm text-green-600">Operational</span>
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">Displays Online</span>
                <span className="text-sm font-medium text-gray-900">
                  {stats.activeDisplays}/{stats.totalDisplays}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">Menu Updates</span>
                <div className="flex items-center">
                  <div className="w-2 h-2 bg-green-500 rounded-full mr-2"></div>
                  <span className="text-sm text-green-600">Synced</span>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Recent Items */}
      {(businesses && businesses.length > 0) && (
        <div className="grid gap-6 lg:grid-cols-2">
          {/* Recent Businesses */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <div>
                <CardTitle>Recent Businesses</CardTitle>
                <CardDescription>
                  Your latest business locations
                </CardDescription>
              </div>
              <Link to="/businesses">
                <Button variant="ghost" size="sm">
                  View all
                  <ArrowRight className="h-4 w-4 ml-1" />
                </Button>
              </Link>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {businesses.slice(0, 3).map((business) => (
                  <div key={business.id} className="flex items-center space-x-3">
                    <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                      <Building className="h-5 w-5 text-blue-600" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-900 truncate">
                        {business.name}
                      </p>
                      <p className="text-xs text-gray-500">
                        {business.city || 'No location set'}
                      </p>
                    </div>
                    <Link to={`/businesses/${business.id}`}>
                      <Button variant="ghost" size="sm">
                        <Eye className="h-4 w-4" />
                      </Button>
                    </Link>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          {/* Recent Menus */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <div>
                <CardTitle>Recent Menus</CardTitle>
                <CardDescription>
                  Recently created or updated menus
                </CardDescription>
              </div>
              <Link to="/menus">
                <Button variant="ghost" size="sm">
                  View all
                  <ArrowRight className="h-4 w-4 ml-1" />
                </Button>
              </Link>
            </CardHeader>
            <CardContent>
              {menus && menus.length > 0 ? (
                <div className="space-y-3">
                  {menus.slice(0, 3).map((menu: Menu) => (
                    <div key={menu.id} className="flex items-center space-x-3">
                      <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
                        <BookOpen className="h-5 w-5 text-green-600" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium text-gray-900 truncate">
                          {menu.name}
                        </p>
                        <p className="text-xs text-gray-500">
                          Version {menu.version} • {menu.categories?.length || 0} categories
                        </p>
                      </div>
                      <Link to={`/menus/${menu.id}`}>
                        <Button variant="ghost" size="sm">
                          <Eye className="h-4 w-4" />
                        </Button>
                      </Link>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-6">
                  <BookOpen className="h-8 w-8 text-gray-400 mx-auto mb-2" />
                  <p className="text-sm text-gray-500">No menus yet</p>
                  <Link to="/menus/new">
                    <Button size="sm" className="mt-2">
                      Create your first menu
                    </Button>
                  </Link>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      )}

      {/* Getting Started */}
      {(!businesses || businesses.length === 0) && (
        <Card>
          <CardHeader>
            <CardTitle>Welcome to DisplayDeck! 🎉</CardTitle>
            <CardDescription>
              Let's get you started with your first digital menu system
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid gap-4 md:grid-cols-3">
              <div className="text-center p-6 border border-gray-200 rounded-lg">
                <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                  <Building className="h-6 w-6 text-blue-600" />
                </div>
                <h3 className="font-medium text-gray-900 mb-2">1. Create Business</h3>
                <p className="text-sm text-gray-600 mb-4">
                  Set up your business profile with location details
                </p>
                <Link to="/businesses/new">
                  <Button size="sm">Get Started</Button>
                </Link>
              </div>
              
              <div className="text-center p-6 border border-gray-200 rounded-lg">
                <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                  <BookOpen className="h-6 w-6 text-green-600" />
                </div>
                <h3 className="font-medium text-gray-900 mb-2">2. Build Menu</h3>
                <p className="text-sm text-gray-600 mb-4">
                  Create your digital menu with items and categories
                </p>
                <Button size="sm" variant="outline" disabled>
                  Create Business First
                </Button>
              </div>
              
              <div className="text-center p-6 border border-gray-200 rounded-lg">
                <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mx-auto mb-4">
                  <Monitor className="h-6 w-6 text-purple-600" />
                </div>
                <h3 className="font-medium text-gray-900 mb-2">3. Setup Display</h3>
                <p className="text-sm text-gray-600 mb-4">
                  Connect your display devices and assign menus
                </p>
                <Button size="sm" variant="outline" disabled>
                  Build Menu First
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}