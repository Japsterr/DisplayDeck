import { PasswordResetForm } from '@/components/auth/PasswordResetForm';
import { PublicRoute } from '@/components/auth/ProtectedRoute';

export function PasswordResetPage() {
  return (
    <PublicRoute>
      <PasswordResetForm />
    </PublicRoute>
  );
}