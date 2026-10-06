<script lang="ts">
  import Page from "$lib/app/Page.svelte";
  import { api } from "$lib/api/client";
  import { loadHarnesses } from "$lib/pages/skills/harnesses";
  import HarnessLedger from "$lib/pages/agents/HarnessLedger.svelte";
  import ChatAgentPicker from "$lib/pages/agents/ChatAgentPicker.svelte";
  import ManifestCard from "$lib/pages/agents/ManifestCard.svelte";
  import type { AgentInfo, ChatAgentInfo, HarnessInfo, ManifestInfo } from "$lib/pages/agents/types";

  let harnesses = $state<HarnessInfo[]>([]);
  let agents = $state<AgentInfo[]>([]);
  let chatAgents = $state<ChatAgentInfo[]>([]);
  let manifest = $state<ManifestInfo | null>(null);
  let ledgerError = $state("");
  let chatError = $state("");
  let actionError = $state("");
  let busyId = $state("");
  let switching = $state(false);

  const activeId = $derived(chatAgents.find((agent) => agent.active)?.id ?? "");

  async function load() {
    const [harnessResult, agentResult, chatResult, manifestResult] = await Promise.allSettled([
      loadHarnesses(),
      api.agents(),
      api.chatAgents(),
      api.manifest(),
    ]);
    if (harnessResult.status === "fulfilled") {
      harnesses = harnessResult.value as unknown as HarnessInfo[];
      ledgerError = "";
    } else ledgerError = "The daemon did not answer.";
    if (agentResult.status === "fulfilled") agents = agentResult.value as unknown as AgentInfo[];
    if (chatResult.status === "fulfilled") {
      chatAgents = chatResult.value as unknown as ChatAgentInfo[];
      chatError = "";
    } else chatError = "The daemon did not answer.";
    if (manifestResult.status === "fulfilled") manifest = manifestResult.value as unknown as ManifestInfo;
  }

  async function setWire(id: string, wired: boolean) {
    if (busyId) return;
    busyId = id;
    actionError = "";
    try {
      await (wired ? api.unwire(id) : api.wire(id));
    } catch {
      actionError = "The wiring change did not complete. Check the daemon and try again.";
    } finally {
      try {
        agents = await api.agents() as unknown as AgentInfo[];
      } catch {
        actionError = "The agent state could not be refreshed.";
      } finally {
        busyId = "";
      }
    }
  }

  async function switchAgent(id: string) {
    if (switching) return;
    switching = true;
    try {
      await api.setChatAgent(id);
      chatAgents = await api.chatAgents() as unknown as ChatAgentInfo[];
    } catch {
      chatError = "The chat agent did not change. Check the daemon and try again.";
    } finally {
      switching = false;
    }
  }

  $effect(() => { void load(); });
</script>

<Page title="Agents" gloss="五人衆" lead="Every harness on the machine, what it knows, and the one answering chat now.">
  <div class="agents-layout">
    <section class="ledger-section">
      <header>
        <div>
          <h2>Harness ledger</h2>
          <span class="t-jp">台帳</span>
        </div>
        <p>{harnesses.filter((harness) => harness.present).length} installed · {agents.filter((agent) => agent.wired).length} wired</p>
      </header>
      {#if actionError}<p class="action-error" role="alert">{actionError}</p>{/if}
      <HarnessLedger {harnesses} {agents} {activeId} {busyId} error={ledgerError} onwire={(id, wired) => void setWire(id, wired)} />
    </section>

    <div class="lower-grid">
      <ChatAgentPicker agents={chatAgents} busy={switching} error={chatError} onswitch={(id) => void switchAgent(id)} />
      <ManifestCard {manifest} />
    </div>
  </div>
</Page>

<style>
  .agents-layout { display: grid; gap: var(--s5); align-content: start; }
  .ledger-section > header { display: flex; align-items: end; justify-content: space-between; gap: var(--s4); margin-bottom: var(--s3); }
  .ledger-section > header > div { display: flex; align-items: baseline; gap: var(--s2); }
  h2 { color: var(--ink); font-size: var(--f-row); font-weight: 500; }
  .ledger-section > header p { color: var(--ink-faint); font-family: var(--mono); font-size: var(--f-micro); }
  .action-error { margin-bottom: var(--s3); color: var(--alert); font-size: var(--f-small); }
  .lower-grid { display: grid; grid-template-columns: minmax(280px, 0.8fr) minmax(420px, 1.2fr); gap: var(--s4); align-items: start; }
  @media (max-width: 980px) { .lower-grid { grid-template-columns: 1fr; } }
  @media (max-width: 560px) { .ledger-section > header { align-items: flex-start; flex-direction: column; } }
</style>
