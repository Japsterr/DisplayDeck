import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { DashboardLayout } from '@/components/layout/DashboardLayout';
import { MenuDashboard } from '@/components/menu/MenuDashboard';

export function MenusPage() {
  return (
    <ProtectedRoute>
      <DashboardLayout>
        <MenuDashboard />
      </DashboardLayout>
    </ProtectedRoute>
  );
}