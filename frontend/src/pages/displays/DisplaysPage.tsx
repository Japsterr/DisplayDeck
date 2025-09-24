import { useQuery } from '@tanstack/react-query';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { DashboardLayout } from '@/components/layout/DashboardLayout';
import { DisplayList } from '@/components/displays/DisplayList';
import { apiService } from '@/services/api';

export function DisplaysPage() {
  const { data: businesses = [], isLoading } = useQuery({
    queryKey: ['businesses'],
    queryFn: () => apiService.getBusinesses(),
  });

  if (isLoading) {
    return (
      <ProtectedRoute>
        <DashboardLayout>
          <div className="flex items-center justify-center min-h-[400px]">
            <div className="text-center">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
              <p className="mt-4 text-gray-600">Loading...</p>
            </div>
          </div>
        </DashboardLayout>
      </ProtectedRoute>
    );
  }

  return (
    <ProtectedRoute>
      <DashboardLayout>
        <DisplayList businesses={businesses} />
      </DashboardLayout>
    </ProtectedRoute>
  );
}