export interface AgentInfo {
  id: string;
  name: string;
  present: boolean;
  wired: boolean;
  file: string;
  skillWired: boolean;
}

export interface CredentialInfo {
  kind: string;
  label: string;
}

export interface MemoryInfo {
  name: string;
  path: string;
  kind: string;
  bytes?: number;
  entries?: number;
  modified?: string;
}

export interface HarnessInfo {
  id: string;
  name: string;
  present: boolean;
  home?: string;
  version?: string;
  model?: string;
  provider?: string;
  wired: boolean;
  skillCount: number;
  memories: MemoryInfo[];
  sessions: number;
  lastActive?: string;
  creds: CredentialInfo[];
  note?: string;
}

export interface ChatAgentInfo {
  id: string;
  name: string;
  available: boolean;
  recommended: boolean;
  active: boolean;
}

export interface ManifestItem {
  label: string;
  path: string;
  kind: string;
  owner: string;
  desc: string;
  exists: boolean;
}

export interface ManifestInfo {
  skill: ManifestItem;
  prowl: ManifestItem;
  vault: ManifestItem[];
  snippet: string;
}
