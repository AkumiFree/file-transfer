import type { ServerEndpoints } from './protocol.js';

const API_PREFIX = '/api/v1';

export interface EndpointResolverOptions {
  secureWebsocket?: boolean;
}

export function normalizeServerUrl(input: string): string {
  const trimmed = input.trim();
  if (!trimmed) throw new Error('Server URL is required.');

  let url: URL;
  try {
    url = new URL(trimmed);
  } catch {
    throw new Error('Enter a valid server URL.');
  }

  if (url.username || url.password || url.search || url.hash) {
    throw new Error('Server URL must not contain credentials, query parameters, or a fragment.');
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') {
    throw new Error('Server URL must use http:// or https://.');
  }

  url.pathname = url.pathname.replace(/\/+$/, '');
  if (url.pathname === '') url.pathname = '/';
  return url.toString().replace(/\/$/, '');
}

export function resolveEndpoints(input: string, options: EndpointResolverOptions = {}): ServerEndpoints {
  const origin = normalizeServerUrl(input);
  const websocketProtocol = options.secureWebsocket ?? origin.startsWith('https://') ? 'wss' : 'ws';
  const parsed = new URL(origin);
  const websocketPath = `${parsed.pathname.replace(/\/+$/, '')}/ws`;
  const websocketHost = parsed.host;

  return {
    origin,
    apiBase: `${origin}${API_PREFIX}`,
    health: `${origin}${API_PREFIX}/health`,
    auth: `${origin}${API_PREFIX}/auth`,
    users: `${origin}${API_PREFIX}/users`,
    friends: `${origin}${API_PREFIX}/friends`,
    chat: `${origin}${API_PREFIX}/chat`,
    transfers: `${origin}${API_PREFIX}/transfers`,
    releases: `${origin}${API_PREFIX}/releases`,
    websocket: `${websocketProtocol}://${websocketHost}${websocketPath}`,
  };
}

export function joinApiPath(endpoints: Pick<ServerEndpoints, 'apiBase'>, path: string): string {
  return `${endpoints.apiBase}/${path.replace(/^\/+/, '')}`.replace(/\/$/, '');
}
