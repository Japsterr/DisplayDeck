import React, { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { apiService } from '@/services/api';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Eye, EyeOff, ArrowLeft } from 'lucide-react';
import { toast } from '@/lib/toast';

interface ResetRequestFormData {
  email: string;
}

interface ResetConfirmFormData {
  new_password: string;
  new_password_confirm: string;
}

interface FormErrors {
  email?: string;
  new_password?: string;
  new_password_confirm?: string;
  submit?: string;
}

export function PasswordResetForm() {
  const [searchParams] = useSearchParams();
  const token = searchParams.get('token');
  const isConfirmMode = !!token;

  const [requestData, setRequestData] = useState<ResetRequestFormData>({
    email: '',
  });

  const [confirmData, setConfirmData] = useState<ResetConfirmFormData>({
    new_password: '',
    new_password_confirm: '',
  });

  const [errors, setErrors] = useState<FormErrors>({});
  const [isLoading, setIsLoading] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  const validateRequestForm = (): boolean => {
    const newErrors: FormErrors = {};

    if (!requestData.email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(requestData.email)) {
      newErrors.email = 'Please enter a valid email address';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const validateConfirmForm = (): boolean => {
    const newErrors: FormErrors = {};

    if (!confirmData.new_password) {
      newErrors.new_password = 'Password is required';
    } else if (confirmData.new_password.length < 8) {
      newErrors.new_password = 'Password must be at least 8 characters long';
    } else if (!/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/.test(confirmData.new_password)) {
      newErrors.new_password = 'Password must contain at least one uppercase letter, one lowercase letter, and one number';
    }

    if (!confirmData.new_password_confirm) {
      newErrors.new_password_confirm = 'Please confirm your password';
    } else if (confirmData.new_password !== confirmData.new_password_confirm) {
      newErrors.new_password_confirm = 'Passwords do not match';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleRequestInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setRequestData(prev => ({ ...prev, [name]: value }));
    
    if (errors[name as keyof FormErrors]) {
      setErrors(prev => ({ ...prev, [name]: undefined }));
    }
  };

  const handleConfirmInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setConfirmData(prev => ({ ...prev, [name]: value }));
    
    if (errors[name as keyof FormErrors]) {
      setErrors(prev => ({ ...prev, [name]: undefined }));
    }
  };

  const handleRequestSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateRequestForm()) {
      return;
    }

    setIsLoading(true);
    try {
      setErrors({});
      await apiService.requestPasswordReset(requestData);
      setIsSuccess(true);
      toast({
        title: 'Success',
        description: 'Password reset link has been sent to your email.',
      });
    } catch (error) {
      setErrors({
        submit: error instanceof Error ? error.message : 'Failed to send reset email. Please try again.',
      });
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to send reset email.',
        variant: 'destructive',
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleConfirmSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateConfirmForm()) {
      return;
    }

    if (!token) {
      setErrors({ submit: 'Invalid or missing reset token' });
      return;
    }

    setIsLoading(true);
    try {
      setErrors({});
      await apiService.confirmPasswordReset({
        token,
        ...confirmData,
      });
      setIsSuccess(true);
      toast({
        title: 'Success',
        description: 'Your password has been reset successfully. You can now log in with your new password.',
      });
    } catch (error) {
      setErrors({
        submit: error instanceof Error ? error.message : 'Failed to reset password. Please try again.',
      });
      toast({
        title: 'Error',
        description: error instanceof Error ? error.message : 'Failed to reset password.',
        variant: 'destructive',
      });
    } finally {
      setIsLoading(false);
    }
  };

  if (isSuccess) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-md w-full space-y-8">
          <Card>
            <CardHeader className="text-center">
              <CardTitle className="text-green-600">
                {isConfirmMode ? 'Password Reset Complete' : 'Reset Link Sent'}
              </CardTitle>
              <CardDescription>
                {isConfirmMode
                  ? 'Your password has been successfully reset.'
                  : 'We have sent a password reset link to your email.'}
              </CardDescription>
            </CardHeader>
            <CardContent className="text-center space-y-4">
              <p className="text-sm text-gray-600">
                {isConfirmMode
                  ? 'You can now log in with your new password.'
                  : 'Please check your email and click on the link to reset your password.'}
              </p>
              <Link to="/login">
                <Button className="w-full">
                  Go to Login
                </Button>
              </Link>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
            {isConfirmMode ? 'Reset your password' : 'Forgot your password?'}
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600">
            {isConfirmMode
              ? 'Enter your new password below'
              : 'Enter your email address and we\'ll send you a link to reset your password.'
            }
          </p>
        </div>

        <Card>
          <CardHeader>
            <div className="flex items-center space-x-2">
              <Link to="/login" className="text-gray-400 hover:text-gray-600">
                <ArrowLeft className="h-4 w-4" />
              </Link>
              <CardTitle>
                {isConfirmMode ? 'Set New Password' : 'Reset Password'}
              </CardTitle>
            </div>
            <CardDescription>
              {isConfirmMode
                ? 'Please enter your new password'
                : 'We\'ll email you a reset link'}
            </CardDescription>
          </CardHeader>
          <CardContent>
            {isConfirmMode ? (
              <form onSubmit={handleConfirmSubmit} className="space-y-4">
                {errors.submit && (
                  <div className="bg-red-50 border border-red-200 text-red-600 px-4 py-3 rounded-md text-sm">
                    {errors.submit}
                  </div>
                )}

                <div>
                  <label htmlFor="new_password" className="block text-sm font-medium text-gray-700">
                    New password
                  </label>
                  <div className="relative">
                    <Input
                      id="new_password"
                      name="new_password"
                      type={showPassword ? 'text' : 'password'}
                      autoComplete="new-password"
                      value={confirmData.new_password}
                      onChange={handleConfirmInputChange}
                      className={errors.new_password ? 'border-red-500 focus:border-red-500 pr-10' : 'pr-10'}
                      placeholder="Enter your new password"
                    />
                    <button
                      type="button"
                      className="absolute inset-y-0 right-0 pr-3 flex items-center"
                      onClick={() => setShowPassword(!showPassword)}
                    >
                      {showPassword ? (
                        <EyeOff className="h-4 w-4 text-gray-400 hover:text-gray-600" />
                      ) : (
                        <Eye className="h-4 w-4 text-gray-400 hover:text-gray-600" />
                      )}
                    </button>
                  </div>
                  {errors.new_password && (
                    <p className="mt-1 text-sm text-red-600">{errors.new_password}</p>
                  )}
                </div>

                <div>
                  <label htmlFor="new_password_confirm" className="block text-sm font-medium text-gray-700">
                    Confirm new password
                  </label>
                  <div className="relative">
                    <Input
                      id="new_password_confirm"
                      name="new_password_confirm"
                      type={showConfirmPassword ? 'text' : 'password'}
                      autoComplete="new-password"
                      value={confirmData.new_password_confirm}
                      onChange={handleConfirmInputChange}
                      className={errors.new_password_confirm ? 'border-red-500 focus:border-red-500 pr-10' : 'pr-10'}
                      placeholder="Confirm your new password"
                    />
                    <button
                      type="button"
                      className="absolute inset-y-0 right-0 pr-3 flex items-center"
                      onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                    >
                      {showConfirmPassword ? (
                        <EyeOff className="h-4 w-4 text-gray-400 hover:text-gray-600" />
                      ) : (
                        <Eye className="h-4 w-4 text-gray-400 hover:text-gray-600" />
                      )}
                    </button>
                  </div>
                  {errors.new_password_confirm && (
                    <p className="mt-1 text-sm text-red-600">{errors.new_password_confirm}</p>
                  )}
                </div>

                <Button
                  type="submit"
                  className="w-full"
                  disabled={isLoading}
                >
                  {isLoading ? 'Resetting password...' : 'Reset password'}
                </Button>
              </form>
            ) : (
              <form onSubmit={handleRequestSubmit} className="space-y-4">
                {errors.submit && (
                  <div className="bg-red-50 border border-red-200 text-red-600 px-4 py-3 rounded-md text-sm">
                    {errors.submit}
                  </div>
                )}

                <div>
                  <label htmlFor="email" className="block text-sm font-medium text-gray-700">
                    Email address
                  </label>
                  <Input
                    id="email"
                    name="email"
                    type="email"
                    autoComplete="email"
                    value={requestData.email}
                    onChange={handleRequestInputChange}
                    className={errors.email ? 'border-red-500 focus:border-red-500' : ''}
                    placeholder="Enter your email address"
                  />
                  {errors.email && (
                    <p className="mt-1 text-sm text-red-600">{errors.email}</p>
                  )}
                </div>

                <Button
                  type="submit"
                  className="w-full"
                  disabled={isLoading}
                >
                  {isLoading ? 'Sending reset link...' : 'Send reset link'}
                </Button>
              </form>
            )}
          </CardContent>
        </Card>

        <div className="text-center">
          <Link
            to="/login"
            className="text-sm text-blue-600 hover:text-blue-500"
          >
            Back to login
          </Link>
        </div>
      </div>
    </div>
  );
}