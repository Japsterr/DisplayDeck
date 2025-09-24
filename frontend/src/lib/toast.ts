// Simple toast utility for now - can be replaced with a proper toast library later
export interface ToastOptions {
  title: string;
  description?: string;
  variant?: 'default' | 'destructive';
}

export function toast(options: ToastOptions) {
  // For now, just use console and alert - can be replaced with proper toast component later
  if (options.variant === 'destructive') {
    console.error(`${options.title}: ${options.description}`);
    alert(`Error: ${options.title}\n${options.description}`);
  } else {
    console.log(`${options.title}: ${options.description}`);
    alert(`${options.title}\n${options.description}`);
  }
}