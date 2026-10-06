<script lang="ts">
  import Button from "$lib/ui/Button.svelte";
  import Card from "$lib/ui/Card.svelte";
  import Chip from "$lib/ui/Chip.svelte";
  import Empty from "$lib/ui/Empty.svelte";
  import type { AgentInfo, HarnessInfo } from "./types";

  interface Props {
    harnesses: HarnessInfo[];
    agents: AgentInfo[];
    activeId?: string;
    busyId?: string;
    error?: string;
    onwire: (id: string, wired: boolean) => void;
  }

  let { harnesses, agents, activeId = "", busyId = "", error = "", onwire }: Props = $props();

  const agentById = $derived(new Map(agents.map((agent) => [agent.id, agent])));

  function ago(value?: string): string {
    if (!value) return "No recent session";
    const elapsed = (Date.now() - new Date(value).getTime()) / 1000;
    if (!Number.isFinite(elapsed) || elapsed < 0) return "Activity unknown";
    if (elapsed < 90) return "Active moments ago";
    if (elapsed < 3600) return `Active ${Math.round(elapsed / 60)} min ago`;
    if (elapsed < 86400) return `Active ${Math.round(elapsed / 3600)} h ago`;
    return `Active ${Math.round(elapsed / 86400)} d ago`;
  }

  function credentials(harness: HarnessInfo): string {
    return harness.creds?.map((cred) => cred.label).join(", ") || "No credentials detected";
  }
</script>

{#if error}
  <Empty title="The harness ledger is unavailable" body="Start the Rashin daemon, then return here to scan the installed agents." />
{:else if harnesses.length === 0}
  <Empty title="No agent harnesses found" body="Install a supported coding agent, then refresh this sheet." />
{:else}
  <div class="ledger">
    {#each harnesses as harness (harness.id)}
      {@const agent = agentById.get(harness.id)}
      <Card class="harness {harness.id === activeId ? 'active' : ''}">
        {#snippet tools()}
          <div class="badges">
            {#if harness.id === activeId}<Chip tone="plate">Chat active</Chip>{/if}
            {#if harness.wired}<Chip tone="line">Wired</Chip>{/if}
            <Chip tone={harness.present ? "line" : "quiet"}>{harness.present ? "Installed" : "Absent"}</Chip>
          </div>
        {/snippet}
        <div class="identity">
          <div>
            <h3>{harness.name}</h3>
            <p class="t-mono">{harness.version || harness.id}</p>
          </div>
          {#if agent && (agent.wired || agent.present)}
            <Button
              variant={agent.wired ? "line" : "plate"}
              size="sm"
              busy={busyId === harness.id}
              onclick={() => onwire(harness.id, agent.wired)}
            >{agent.wired ? "Unwire" : "Wire"}</Button>
          {/if}
        </div>

        <div class="facts">
          <div><span class="t-label">Model</span><strong>{harness.model || "Default"}</strong><small>{harness.provider || "provider follows agent"}</small></div>
          <div><span class="t-label">Knowledge</span><strong>{harness.skillCount || 0} skills · {harness.memories?.length || 0} memories</strong><small>{harness.sessions || 0} sessions · {ago(harness.lastActive)}</small></div>
        </div>

        <dl>
          <div><dt>Home</dt><dd>{harness.home || "Not installed"}</dd></div>
          {#if agent}<div><dt>Instructions</dt><dd>{agent.file}</dd></div>{/if}
          <div><dt>Credentials</dt><dd>{credentials(harness)}</dd></div>
        </dl>
        {#if harness.note}<p class="note">{harness.note}</p>{/if}
      </Card>
    {/each}
  </div>
{/if}

<style>
  .ledger { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 360px), 1fr)); gap: var(--s4); }
  :global(.harness.active) { border-color: var(--line-strong); }
  .badges { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: var(--s1); }
  .identity { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--s4); }
  h3 { color: var(--ink); font-size: 18px; font-weight: 500; }
  .identity .t-mono { margin-top: var(--s1); color: var(--ink-faint); font-size: var(--f-micro); }
  .facts { display: grid; grid-template-columns: 1fr 1.4fr; gap: var(--s4); margin-top: var(--s5); padding: var(--s4) 0; border-block: 1px solid var(--line-soft); }
  .facts > div { display: flex; flex-direction: column; min-width: 0; gap: var(--s1); }
  .facts strong { color: var(--ink); font-size: var(--f-small); font-weight: 500; }
  .facts small { color: var(--ink-faint); font-size: var(--f-micro); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  dl { display: grid; gap: var(--s2); margin: var(--s4) 0 0; }
  dl div { display: grid; grid-template-columns: 92px minmax(0, 1fr); gap: var(--s3); }
  dt { color: var(--ink-faint); font-size: var(--f-small); }
  dd { margin: 0; overflow: hidden; color: var(--ink-dim); font-family: var(--mono); font-size: var(--f-micro); text-overflow: ellipsis; white-space: nowrap; }
  .note { margin-top: var(--s3); color: var(--ink-mute); font-size: var(--f-small); }
  @media (max-width: 540px) { .facts { grid-template-columns: 1fr; } }
</style>
