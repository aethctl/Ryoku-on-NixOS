<script lang="ts">
  import Button from "$lib/ui/Button.svelte";
  import Card from "$lib/ui/Card.svelte";
  import Chip from "$lib/ui/Chip.svelte";
  import Empty from "$lib/ui/Empty.svelte";
  import Select from "$lib/ui/Select.svelte";
  import type { QuickInfo } from "./types";

  interface Props {
    quick: QuickInfo | null;
    busy?: boolean;
    error?: string;
    onset: (provider: string) => void;
  }

  let { quick, busy = false, error = "", onset }: Props = $props();
  const options = $derived((quick?.available || []).map((provider) => ({
    value: provider,
    label: provider,
    hint: quick?.ready.includes(provider) ? "ready" : "needs credentials",
  })));
  const selected = $derived(quick?.provider || "");
</script>

<Card title="Fast lane" gloss="即答" lead="The direct provider for short asks before a full agent wakes.">
  {#snippet tools()}
    {#if quick}<Chip tone={quick.sessionLane ? "quiet" : "plate"}>{quick.sessionLane ? "Session lane" : "Ready"}</Chip>{/if}
  {/snippet}
  {#if error}
    <Empty title="Fast lane state is unavailable" body="Start the Rashin daemon, then return here to inspect the active route." />
  {:else if quick}
    <div class="route">
      <div class="route-main">
        <span class="t-label">Current route</span>
        <strong>{quick.provider || "Follow Hermes"}</strong>
        <p>{quick.model || "The chat agent chooses the model"}</p>
      </div>
      <dl>
        <div><dt>Endpoint</dt><dd>{quick.endpoint || "Shared agent session"}</dd></div>
        <div><dt>Ready here</dt><dd>{quick.ready.length ? quick.ready.join(", ") : "No direct providers"}</dd></div>
      </dl>
    </div>
    {#if quick.reason}<p class="reason">{quick.reason}</p>{/if}
    <div class="actions">
      <Select label="Set fast lane provider" options={options} value={selected} placeholder="Choose provider" disabled={busy} onchange={(value) => onset(value)} />
      <Button variant="line" armed={Boolean(quick.provider)} busy={busy} onclick={() => onset("auto")}>Follow Hermes</Button>
    </div>
  {/if}
</Card>

<style>
  .route { display: grid; grid-template-columns: minmax(150px, 0.7fr) minmax(220px, 1.3fr); gap: var(--s5); }
  .route-main { display: flex; flex-direction: column; gap: var(--s1); }
  .route-main strong { color: var(--ink); font-family: var(--display); font-size: 24px; font-weight: 400; line-height: 1.2; }
  .route-main p { color: var(--ink-mute); font-size: var(--f-small); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  dl { display: grid; gap: var(--s2); margin: 0; }
  dl div { display: grid; grid-template-columns: 88px minmax(0, 1fr); gap: var(--s3); }
  dt { color: var(--ink-faint); font-size: var(--f-small); }
  dd { margin: 0; overflow: hidden; color: var(--ink-dim); font-family: var(--mono); font-size: var(--f-micro); text-overflow: ellipsis; white-space: nowrap; }
  .reason { margin-top: var(--s4); padding-top: var(--s3); border-top: 1px solid var(--line-soft); color: var(--ink-mute); font-size: var(--f-small); }
  .actions { display: flex; align-items: center; gap: var(--s2); margin-top: var(--s4); }
  @media (max-width: 560px) { .route { grid-template-columns: 1fr; } .actions { align-items: stretch; flex-direction: column; } }
</style>
