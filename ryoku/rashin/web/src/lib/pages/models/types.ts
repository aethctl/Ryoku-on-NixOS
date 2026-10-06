export interface ProviderInfo {
  id: string;
  name: string;
  class?: string;
  models?: string[];
  freeModels?: number;
  maxContext?: number;
  friction?: string;
  routable?: boolean;
  env?: string;
  apiKeyUrl?: string;
  modalities?: string[];
  health?: string;
  state?: string;
}

export interface QuickInfo {
  provider: string;
  model: string;
  endpoint: string;
  label: string;
  available: string[];
  ready: string[];
  sessionLane: boolean;
  reason?: string;
}

export interface HarnessCredentials {
  creds?: { kind: string; label: string }[];
}
