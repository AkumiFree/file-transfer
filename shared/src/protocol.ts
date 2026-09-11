export const APP_NAME = 'FileTransfer' as const;
export const APP_VERSION = '0.1.0' as const;
export const API_PREFIX = '/api/v1' as const;

export const languages = [
  { code: 'en', label: 'English', nativeLabel: 'English' },
  { code: 'vi', label: 'Vietnamese', nativeLabel: 'Tiếng Việt' },
  { code: 'zh-Hans', label: '中文（简体）', nativeLabel: '中文（简体）' },
  { code: 'zh-Hant', label: '中文（繁體）', nativeLabel: '中文（繁體）' },
  { code: 'ja', label: '日本語', nativeLabel: '日本語' },
] as const;

export type AppLanguage = (typeof languages)[number]['code'];

export interface ServerEndpoints {
  origin: string;
  apiBase: string;
  health: string;
  auth: string;
  users: string;
  friends: string;
  chat: string;
  transfers: string;
  releases: string;
  websocket: string;
}

export interface TransferMetadata {
  transferId: string;
  fileId: string;
  filename: string;
  size: number;
  mimeType: string;
  chunkSize: number;
  totalChunks: number;
  sha256: string;
  sender: string;
  receiver: string;
  status: 'created' | 'uploading' | 'uploaded' | 'downloading' | 'completed' | 'failed' | 'cancelled';
  createdAt: string;
  expiresAt?: string;
}

export interface TransferChunk {
  transferId: string;
  index: number;
  size: number;
  sha256?: string;
}

export interface User {
  id: string;
  email: string;
  displayName: string;
  createdAt: string;
}

export interface Friend {
  id: string;
  userId: string;
  displayName: string;
  email: string;
  online: boolean;
  lastSeen?: string;
}

export interface ChatMessage {
  id: string;
  conversationId: string;
  senderId: string;
  receiverId: string;
  body: string;
  createdAt: string;
  readAt?: string;
  deliveryState: 'sending' | 'sent' | 'delivered' | 'read' | 'failed';
}

export interface HealthStatus {
  status: 'ok' | 'degraded';
  version: string;
  database: 'online' | 'offline';
  storage: 'online' | 'offline';
  websocket: 'available' | 'unavailable';
  checkedAt: string;
}

export interface ConnectionCheck {
  server: 'online' | 'offline';
  api: 'online' | 'offline';
  chat: 'available' | 'unavailable';
  fileTransfer: 'available' | 'unavailable';
  message?: string;
}

export interface RegisterInput {
  email: string;
  password: string;
  displayName: string;
}

export interface LoginInput {
  email: string;
  password: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
}

export interface ApiErrorBody {
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
}
