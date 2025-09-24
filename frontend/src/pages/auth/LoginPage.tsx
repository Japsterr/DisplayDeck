import { LoginForm } from '@/components/auth/LoginForm';
import { PublicRoute } from '@/components/auth/ProtectedRoute';

export function LoginPage() {
  return (
    <PublicRoute>
      <LoginForm />
    </PublicRoute>
  );
}