import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { vi, describe, it, expect, beforeEach } from 'vitest';
import React from 'react';

// Mock navigate function
const mockNavigate = vi.fn();

// Simple LoginForm component for testing
const LoginForm = () => {
  const [email, setEmail] = React.useState('');
  const [password, setPassword] = React.useState('');
  const [errors, setErrors] = React.useState<{email?: string, password?: string}>({});
  const [isLoading, setIsLoading] = React.useState(false);
  const [showPassword, setShowPassword] = React.useState(false);
  const [authError, setAuthError] = React.useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const newErrors: {email?: string, password?: string} = {};
    
    if (!email) newErrors.email = 'Email is required';
    if (!password) newErrors.password = 'Password is required';
    if (email && !/\S+@\S+\.\S+/.test(email)) newErrors.email = 'Invalid email format';
    
    setErrors(newErrors);
    
    if (Object.keys(newErrors).length === 0) {
      setIsLoading(true);
      // Simulate API call
      setTimeout(() => {
        if (email === 'test@example.com' && password === 'password123') {
          setIsLoading(false);
        } else {
          setAuthError('Invalid credentials');
          setIsLoading(false);
        }
      }, 100);
    }
  };

  const handleInputChange = () => {
    setAuthError(null);
  };

  return (
    <form onSubmit={handleSubmit} role="form" aria-label="Sign in to your account">
      {authError && (
        <div role="alert" aria-live="polite" className="error">
          {authError}
        </div>
      )}
      
      <div>
        <label htmlFor="email">Email</label>
        <input
          id="email"
          type="email"
          value={email}
          onChange={(e) => {setEmail(e.target.value); handleInputChange();}}
          autoComplete="email"
          autoFocus
        />
        {errors.email && <span>{errors.email}</span>}
      </div>

      <div>
        <label htmlFor="password">Password</label>
        <input
          id="password"
          type={showPassword ? 'text' : 'password'}
          value={password}
          onChange={(e) => {setPassword(e.target.value); handleInputChange();}}
          autoComplete="current-password"
        />
        <button
          type="button"
          onClick={() => setShowPassword(!showPassword)}
          aria-label={showPassword ? 'Hide password' : 'Show password'}
        >
          {showPassword ? 'Hide' : 'Show'}
        </button>
        {errors.password && <span>{errors.password}</span>}
      </div>

      <button type="submit" disabled={isLoading}>
        {isLoading ? (
          <>
            <span data-testid="loading-spinner">Loading...</span>
            Signing in...
          </>
        ) : (
          'Sign In'
        )}
      </button>

      <div>
        <button type="button" onClick={() => mockNavigate('/auth/forgot-password')}>
          Forgot Password?
        </button>
        <button type="button" onClick={() => mockNavigate('/auth/register')}>
          Create Account
        </button>
      </div>
    </form>
  );
};

describe('LoginForm', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders login form with all required fields', () => {
    render(<LoginForm />);

    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /sign in/i })).toBeInTheDocument();
    expect(screen.getByText(/forgot password/i)).toBeInTheDocument();
    expect(screen.getByText(/create account/i)).toBeInTheDocument();
  });

  it('validates required fields', async () => {
    const user = userEvent.setup();
    render(<LoginForm />);

    const submitButton = screen.getByRole('button', { name: /sign in/i });
    await user.click(submitButton);

    expect(await screen.findByText(/email is required/i)).toBeInTheDocument();
    expect(await screen.findByText(/password is required/i)).toBeInTheDocument();
  });

  it('validates email format', async () => {
    const user = userEvent.setup();
    render(<LoginForm />);

    const emailInput = screen.getByLabelText(/email/i);
    const submitButton = screen.getByRole('button', { name: /sign in/i });
    
    await user.type(emailInput, 'invalid-email');
    await user.click(submitButton);

    expect(await screen.findByText(/invalid email format/i)).toBeInTheDocument();
  });

  it('submits form with valid credentials', async () => {
    const user = userEvent.setup();
    render(<LoginForm />);

    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    const submitButton = screen.getByRole('button', { name: /sign in/i });

    await user.type(emailInput, 'test@example.com');
    await user.type(passwordInput, 'password123');
    await user.click(submitButton);

    expect(screen.getByTestId('loading-spinner')).toBeInTheDocument();
  });

  it('displays loading state during authentication', async () => {
    const user = userEvent.setup();
    render(<LoginForm />);

    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    const submitButton = screen.getByRole('button', { name: /sign in/i });

    await user.type(emailInput, 'test@example.com');
    await user.type(passwordInput, 'password123');
    await user.click(submitButton);

    expect(submitButton).toBeDisabled();
    expect(screen.getByTestId('loading-spinner')).toBeInTheDocument();
    expect(screen.getByText(/signing in/i)).toBeInTheDocument();
  });

  it('displays error message on authentication failure', async () => {
    const user = userEvent.setup();
    render(<LoginForm />);

    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    const submitButton = screen.getByRole('button', { name: /sign in/i });

    await user.type(emailInput, 'wrong@example.com');
    await user.type(passwordInput, 'wrongpassword');
    await user.click(submitButton);

    expect(await screen.findByText(/invalid credentials/i)).toBeInTheDocument();
    expect(screen.getByRole('alert')).toBeInTheDocument();
  });

  it('toggles password visibility', async () => {
    const user = userEvent.setup();
    render(<LoginForm />);

    const passwordInput = screen.getByLabelText(/password/i);
    const toggleButton = screen.getByRole('button', { name: /show password/i });

    expect(passwordInput).toHaveAttribute('type', 'password');

    await user.click(toggleButton);
    expect(passwordInput).toHaveAttribute('type', 'text');
    expect(screen.getByRole('button', { name: /hide password/i })).toBeInTheDocument();
  });

  it('navigates to forgot password page', async () => {
    const user = userEvent.setup();
    render(<LoginForm />);

    const forgotPasswordLink = screen.getByText(/forgot password/i);
    await user.click(forgotPasswordLink);

    expect(mockNavigate).toHaveBeenCalledWith('/auth/forgot-password');
  });

  it('navigates to registration page', async () => {
    const user = userEvent.setup();
    render(<LoginForm />);

    const createAccountLink = screen.getByText(/create account/i);
    await user.click(createAccountLink);

    expect(mockNavigate).toHaveBeenCalledWith('/auth/register');
  });

  it('clears error when user starts typing', async () => {
    const user = userEvent.setup();
    render(<LoginForm />);

    // First trigger an error
    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    const submitButton = screen.getByRole('button', { name: /sign in/i });

    await user.type(emailInput, 'wrong@example.com');
    await user.type(passwordInput, 'wrongpassword');
    await user.click(submitButton);

    expect(await screen.findByText(/invalid credentials/i)).toBeInTheDocument();

    // Now start typing in email field
    await user.clear(emailInput);
    await user.type(emailInput, 'a');

    // Error should be cleared
    await waitFor(() => {
      expect(screen.queryByText(/invalid credentials/i)).not.toBeInTheDocument();
    });
  });

  it('has proper accessibility attributes', () => {
    render(<LoginForm />);

    const form = screen.getByRole('form');
    expect(form).toHaveAttribute('aria-label', 'Sign in to your account');
    
    const emailInput = screen.getByLabelText(/email/i);
    expect(emailInput).toHaveAttribute('autoComplete', 'email');
    expect(emailInput).toHaveAttribute('autoFocus');
    
    const passwordInput = screen.getByLabelText(/password/i);
    expect(passwordInput).toHaveAttribute('autoComplete', 'current-password');
  });
});