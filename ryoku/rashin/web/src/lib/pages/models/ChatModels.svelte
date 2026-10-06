<script lang="ts">
  import Card from "$lib/ui/Card.svelte";
  import Chip from "$lib/ui/Chip.svelte";
  import Empty from "$lib/ui/Empty.svelte";
  import Select from "$lib/ui/Select.svelte";
  import type { ModelInfo } from "$lib/chat/protocol";

  interface Props {
    models: ModelInfo[];
    current: string;
    agent: string;
    connected: boolean;
    onchange: (id: string) => void;
  }

  let { models, current, agent, connected, onchange }: Props = $props();
  const options = $derived(models.map((model) => ({ value: model.id, label: model.name || model.id, hint: model.id })));
  const currentModel = $derived(models.find((model) => model.id === current));
</script>

<Card title="Chat model" gloss="対話" lead="The model advertised by the active agent session.">
  {#snippet tools()}<Chip tone={connected ? "line" : "quiet"}>{connected ? "Connected" : "Connecting"}</Chip>{/snippet}
  {#if models.length === 0}
    <Empty title="Waiting for chat models" body="Open Chat or wait for the active agent to finish starting." />
  {:else}
    <div class="current">
      <div>
        <span class="t-label">Current model</span>
        <strong>{currentModel?.name || current || "Agent default"}</strong>
        <p>{currentModel?.description || "Model choice belongs to this running agent session."}</p>
      </div>
      <div class="agent">
        <span class="t-label">Agent</span>
        <p>{agent || "Starting"}</p>
      </div>
    </div>
    <div class="picker">
      <Select label="Set chat model" options={options} value={current} placeholder="Choose model" disabled={!connected} onchange={onchange} />
      <span>{models.length} available</span>
    </div>
  {/if}
</Card>

<style>
  .current { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: var(--s5); }
  .current > div:first-child { min-width: 0; }
  strong { display: block; margin-top: var(--s1); overflow: hidden; color: var(--ink); font-family: var(--display); font-size: 24px; font-weight: 400; text-overflow: ellipsis; white-space: nowrap; }
  .current p { margin-top: var(--s1); color: var(--ink-mute); font-size: var(--f-small); }
  .agent { min-width: 120px; padding-left: var(--s4); border-left: 1px solid var(--line-soft); }
  .agent p { color: var(--ink); font-size: var(--f-row); }
  .picker { display: flex; align-items: center; gap: var(--s3); margin-top: var(--s5); padding-top: var(--s4); border-top: 1px solid var(--line-soft); }
  .picker span { color: var(--ink-faint); font-family: var(--mono); font-size: var(--f-micro); }
  @media (max-width: 560px) { .current { grid-template-columns: 1fr; } .agent { padding: var(--s3) 0 0; border: 0; border-top: 1px solid var(--line-soft); } }
</style>
