<script lang="ts">
  import Page from "$lib/app/Page.svelte";
  import { api } from "$lib/api/client";
  import { chat } from "$lib/chat/store.svelte";
  import { loadHarnesses } from "$lib/pages/skills/harnesses";
  import ProviderTable from "$lib/pages/models/ProviderTable.svelte";
  import QuickLane from "$lib/pages/models/QuickLane.svelte";
  import ChatModels from "$lib/pages/models/ChatModels.svelte";
  import type { HarnessCredentials, ProviderInfo, QuickInfo } from "$lib/pages/models/types";

  let providers = $state<ProviderInfo[]>([]);
  let harnesses = $state<HarnessCredentials[]>([]);
  let quick = $state<QuickInfo | null>(null);
  let providersLoading = $state(true);
  let providersError = $state("");
  let quickError = $state("");
  let quickBusy = $state(false);

  function providerRows(payload: unknown): ProviderInfo[] {
    if (Array.isArray(payload)) return payload as ProviderInfo[];
    if (payload && typeof payload === "object" && Array.isArray((payload as { providers?: unknown }).providers)) {
      return (payload as { providers: ProviderInfo[] }).providers;
    }
    return [];
  }

  async function loadProviders() {
    providersLoading = true;
    try {
      providers = providerRows(await api.providers());
      providersError = "";
    } catch {
      providersError = "Prowl did not answer.";
    } finally {
      providersLoading = false;
    }
  }

  async function loadHarnessData() {
    try {
      harnesses = await loadHarnesses() as unknown as HarnessCredentials[];
    } catch {
      harnesses = [];
    }
  }

  async function loadQuick() {
    try {
      quick = await api.quick() as unknown as QuickInfo;
      quickError = "";
    } catch {
      quickError = "The daemon did not answer.";
    }
  }

  async function setQuick(provider: string) {
    if (quickBusy) return;
    quickBusy = true;
    try {
      await api.setQuick(provider);
      quick = await api.quick() as unknown as QuickInfo;
      quickError = "";
    } catch {
      quickError = "The fast lane did not change. Check credentials and try again.";
    } finally {
      quickBusy = false;
    }
  }

  $effect(() => {
    void loadProviders();
    void loadHarnessData();
    void loadQuick();
  });
</script>

<Page title="Models" gloss="モデル" lead="Direct providers, agent models and the route between a question and an answer.">
  <div class="models-layout">
    <div class="route-grid">
      <QuickLane {quick} busy={quickBusy} error={quickError} onset={(provider) => void setQuick(provider)} />
      <ChatModels
        models={chat.state.models}
        current={chat.state.currentModel}
        agent={chat.state.agent}
        connected={chat.connected}
        onchange={(id) => chat.setModel(id)}
      />
    </div>
    <ProviderTable {providers} {harnesses} loading={providersLoading} error={providersError} />
  </div>
</Page>

<style>
  .models-layout { display: grid; gap: var(--s4); align-content: start; }
  .route-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: var(--s4); align-items: start; }
  @media (max-width: 1040px) { .route-grid { grid-template-columns: 1fr; } }
</style>
