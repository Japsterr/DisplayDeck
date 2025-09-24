import { Routes, Route, Navigate } from 'react-router-dom';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { PublicRoute } from '@/components/auth/PublicRoute';

// Public pages
import { LandingPage } from '@/pages/public/LandingPage';

// Auth pages
import { LoginPage } from '@/pages/auth/LoginPage';
import { RegisterPage } from '@/pages/auth/RegisterPage';
import { PasswordResetPage } from '@/pages/auth/PasswordResetPage';

// Protected pages
import { DashboardPage } from '@/pages/dashboard/DashboardPage';
import { BusinessesPage } from '@/pages/business/BusinessesPage';
import { MenusPage } from '@/pages/menus/MenusPage';
import { DisplaysPage } from '@/pages/displays/DisplaysPage';
import { TeamPage } from '@/pages/TeamPage';
import { SettingsPage } from '@/pages/SettingsPage';

export function AppRoutes() {
  return (
    <Routes>
      {/* Public routes */}
      <Route 
        path="/" 
        element={
          <PublicRoute>
            <LandingPage />
          </PublicRoute>
        } 
      />
      
      {/* Auth routes */}
      <Route 
        path="/login" 
        element={
          <PublicRoute>
            <LoginPage />
          </PublicRoute>
        } 
      />
      <Route 
        path="/register" 
        element={
          <PublicRoute>
            <RegisterPage />
          </PublicRoute>
        } 
      />
      <Route 
        path="/reset-password" 
        element={
          <PublicRoute>
            <PasswordResetPage />
          </PublicRoute>
        } 
      />

      {/* Protected routes */}
      <Route 
        path="/dashboard" 
        element={
          <ProtectedRoute>
            <DashboardPage />
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/businesses" 
        element={
          <ProtectedRoute>
            <BusinessesPage />
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/businesses/:id" 
        element={
          <ProtectedRoute>
            <BusinessesPage />
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/menus" 
        element={
          <ProtectedRoute>
            <MenusPage />
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/menus/:id" 
        element={
          <ProtectedRoute>
            <MenusPage />
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/displays" 
        element={
          <ProtectedRoute>
            <DisplaysPage />
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/displays/:id" 
        element={
          <ProtectedRoute>
            <DisplaysPage />
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/team" 
        element={
          <ProtectedRoute>
            <TeamPage />
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/settings" 
        element={
          <ProtectedRoute>
            <SettingsPage />
          </ProtectedRoute>
        } 
      />
      
      {/* Catch all route - redirect to dashboard if authenticated, otherwise landing page */}
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  );
}