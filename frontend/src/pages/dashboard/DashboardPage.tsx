import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { DashboardLayout } from '@/components/layout/DashboardLayout';
import { DashboardHome } from '@/pages/dashboard/DashboardHome';

export function DashboardPage() {
  return (
    <ProtectedRoute>
      <DashboardLayout>
        <DashboardHome />
      </DashboardLayout>
    </ProtectedRoute>
  );
}