// WebSocket client for real-time updates
import { toast } from '@/lib/toast';

export interface WebSocketMessage {
  type: string;
  data: any;
  timestamp: string;
}

export interface MenuUpdateMessage extends WebSocketMessage {
  type: 'menu_updated';
  data: {
    menu_id: string;
    business_id: string;
    changes: any;
  };
}

export interface DisplayStatusMessage extends WebSocketMessage {
  type: 'display_status';
  data: {
    display_id: string;
    status: 'online' | 'offline';
    last_heartbeat: string;
  };
}

export interface PriceUpdateMessage extends WebSocketMessage {
  type: 'price_updated';
  data: {
    menu_id: string;
    item_id: string;
    new_price: number;
    old_price: number;
  };
}

type MessageHandler = (message: WebSocketMessage) => void;

export class WebSocketService {
  private ws: WebSocket | null = null;
  private url: string;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 1000;
  private messageHandlers: Set<MessageHandler> = new Set();
  private isConnecting = false;
  private shouldReconnect = true;

  constructor(url?: string) {
    // Use environment variable or default WebSocket URL
    this.url = url || this.getWebSocketUrl();
  }

  private getWebSocketUrl(): string {
    const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:8000';
    const wsUrl = apiUrl.replace('http://', 'ws://').replace('https://', 'wss://');
    return `${wsUrl}/ws/`;
  }

  private getAuthToken(): string | null {
    return localStorage.getItem('access_token');
  }

  public connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        resolve();
        return;
      }

      if (this.isConnecting) {
        // Already connecting, wait for current attempt
        setTimeout(() => {
          if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            resolve();
          } else {
            reject(new Error('Connection attempt failed'));
          }
        }, 5000);
        return;
      }

      this.isConnecting = true;
      const token = this.getAuthToken();
      
      if (!token) {
        this.isConnecting = false;
        reject(new Error('No authentication token available'));
        return;
      }

      // Add token as query parameter
      const wsUrl = `${this.url}?token=${encodeURIComponent(token)}`;
      
      try {
        this.ws = new WebSocket(wsUrl);
        
        this.ws.onopen = () => {
          console.log('WebSocket connected');
          this.isConnecting = false;
          this.reconnectAttempts = 0;
          this.sendPing(); // Send initial ping
          resolve();
        };

        this.ws.onmessage = (event) => {
          try {
            const message: WebSocketMessage = JSON.parse(event.data);
            this.handleMessage(message);
          } catch (error) {
            console.error('Failed to parse WebSocket message:', error);
          }
        };

        this.ws.onclose = (event) => {
          console.log('WebSocket closed:', event.code, event.reason);
          this.isConnecting = false;
          this.ws = null;
          
          if (this.shouldReconnect && event.code !== 1000) {
            this.scheduleReconnect();
          }
        };

        this.ws.onerror = (error) => {
          console.error('WebSocket error:', error);
          this.isConnecting = false;
          reject(error);
        };

      } catch (error) {
        this.isConnecting = false;
        reject(error);
      }
    });
  }

  public disconnect(): void {
    this.shouldReconnect = false;
    
    if (this.ws) {
      this.ws.close(1000, 'Client disconnecting');
      this.ws = null;
    }
  }

  public addMessageHandler(handler: MessageHandler): () => void {
    this.messageHandlers.add(handler);
    
    // Return cleanup function
    return () => {
      this.messageHandlers.delete(handler);
    };
  }

  public sendMessage(message: any): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({
        ...message,
        timestamp: new Date().toISOString(),
      }));
    } else {
      console.warn('WebSocket not connected, message not sent:', message);
    }
  }

  public joinRoom(roomId: string): void {
    this.sendMessage({
      type: 'join_room',
      room: roomId,
    });
  }

  public leaveRoom(roomId: string): void {
    this.sendMessage({
      type: 'leave_room',
      room: roomId,
    });
  }

  private handleMessage(message: WebSocketMessage): void {
    console.log('WebSocket message received:', message);

    // Handle specific message types
    switch (message.type) {
      case 'menu_updated':
        this.handleMenuUpdate(message as MenuUpdateMessage);
        break;
      case 'display_status':
        this.handleDisplayStatus(message as DisplayStatusMessage);
        break;
      case 'price_updated':
        this.handlePriceUpdate(message as PriceUpdateMessage);
        break;
      case 'pong':
        // Handle ping response
        break;
      case 'error':
        console.error('WebSocket server error:', message.data);
        toast({
          title: 'Connection Error',
          description: message.data.message || 'WebSocket connection error',
          variant: 'destructive',
        });
        break;
      default:
        console.log('Unhandled message type:', message.type);
    }

    // Notify all registered handlers
    this.messageHandlers.forEach(handler => {
      try {
        handler(message);
      } catch (error) {
        console.error('Error in message handler:', error);
      }
    });
  }

  private handleMenuUpdate(message: MenuUpdateMessage): void {
    const { menu_id, business_id, changes } = message.data;
    
    toast({
      title: 'Menu Updated',
      description: `Menu changes have been applied across all displays.`,
    });

    // Trigger React Query cache updates
    window.dispatchEvent(new CustomEvent('menu-updated', {
      detail: { menuId: menu_id, businessId: business_id, changes }
    }));
  }

  private handleDisplayStatus(message: DisplayStatusMessage): void {
    const { display_id, status } = message.data;
    
    // Only show notifications for offline displays
    if (status === 'offline') {
      toast({
        title: 'Display Offline',
        description: `Display ${display_id} has gone offline.`,
        variant: 'destructive',
      });
    }

    // Trigger React Query cache updates
    window.dispatchEvent(new CustomEvent('display-status-changed', {
      detail: message.data
    }));
  }

  private handlePriceUpdate(message: PriceUpdateMessage): void {
    const { new_price, old_price } = message.data;
    
    toast({
      title: 'Price Updated',
      description: `Item price updated from $${old_price} to $${new_price}`,
    });

    // Trigger React Query cache updates
    window.dispatchEvent(new CustomEvent('price-updated', {
      detail: message.data
    }));
  }

  private sendPing(): void {
    this.sendMessage({ type: 'ping' });
    
    // Schedule next ping
    setTimeout(() => {
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        this.sendPing();
      }
    }, 30000); // Ping every 30 seconds
  }

  private scheduleReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.log('Max reconnection attempts reached');
      toast({
        title: 'Connection Lost',
        description: 'Unable to maintain connection to server. Please refresh the page.',
        variant: 'destructive',
      });
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);
    
    console.log(`Scheduling reconnect attempt ${this.reconnectAttempts} in ${delay}ms`);
    
    setTimeout(() => {
      if (this.shouldReconnect) {
        this.connect().catch(error => {
          console.error('Reconnection failed:', error);
        });
      }
    }, delay);
  }

  public get isConnected(): boolean {
    return this.ws !== null && this.ws.readyState === WebSocket.OPEN;
  }

  public get connectionState(): string {
    if (!this.ws) return 'disconnected';
    
    switch (this.ws.readyState) {
      case WebSocket.CONNECTING: return 'connecting';
      case WebSocket.OPEN: return 'connected';
      case WebSocket.CLOSING: return 'closing';
      case WebSocket.CLOSED: return 'closed';
      default: return 'unknown';
    }
  }
}

// Global WebSocket service instance
export const webSocketService = new WebSocketService();

// Auto-connect when user is authenticated
export function initializeWebSocket(): void {
  const token = localStorage.getItem('access_token');
  
  if (token && !webSocketService.isConnected) {
    webSocketService.connect().catch(error => {
      console.error('Failed to initialize WebSocket connection:', error);
    });
  }
}

// Clean up WebSocket connection
export function cleanupWebSocket(): void {
  webSocketService.disconnect();
}