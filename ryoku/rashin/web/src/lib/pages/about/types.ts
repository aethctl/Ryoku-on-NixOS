import type { ManifestInfo } from "$lib/pages/agents/types";

export interface AboutInfo {
  version: string;
  port: number;
  vault: string;
  hermes: {
    installed: boolean;
    version: string;
    configured: boolean;
    provider: string;
    model: string;
  };
  prowl: { installed: boolean };
}

export type AboutManifest = ManifestInfo;
