import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { DashboardLayout } from '@/components/layout/DashboardLayout';
import { BusinessDashboard } from '@/components/business/BusinessDashboard';

export function BusinessesPage() {
  return (
    <ProtectedRoute>
      <DashboardLayout>
        <BusinessDashboard />
      </DashboardLayout>
    </ProtectedRoute>
  );
}