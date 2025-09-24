import { RegisterForm } from '@/components/auth/RegisterForm';
import { PublicRoute } from '@/components/auth/ProtectedRoute';

export function RegisterPage() {
  return (
    <PublicRoute>
      <RegisterForm />
    </PublicRoute>
  );
}