<script lang="ts">
  import Button from "$lib/ui/Button.svelte";
  import Card from "$lib/ui/Card.svelte";
  import Chip from "$lib/ui/Chip.svelte";
  import Fold from "$lib/ui/Fold.svelte";
  import type { ManifestInfo, ManifestItem } from "./types";

  interface Props { manifest: ManifestInfo | null }
  let { manifest }: Props = $props();
  let copied = $state(false);

  const paths = $derived(manifest ? [manifest.skill, manifest.prowl, ...(manifest.vault || [])] : []);

  async function copy() {
    if (!manifest?.snippet) return;
    try {
      await navigator.clipboard.writeText(manifest.snippet);
      copied = true;
      setTimeout(() => copied = false, 1400);
    } catch {
      copied = false;
    }
  }

  function owner(item: ManifestItem): string {
    if (item.owner === "generated") return "Rashin writes";
    if (item.owner === "yours") return "Agent writes";
    return item.owner;
  }
</script>

{#if manifest}
  <Card title="Agent map" gloss="経路" lead="The machine context any harness can read.">
    {#snippet tools()}
      <Button variant={copied ? "plate" : "line"} size="sm" onclick={() => void copy()}>{copied ? "Copied" : "Copy agent snippet"}</Button>
    {/snippet}
    <Fold>
      {#snippet summary()}<span>{paths.length} exposed paths · skill, maps, memory and code search</span>{/snippet}
      <div class="paths">
        {#each paths as item (item.path)}
          <div class:missing={!item.exists}>
            <span class="path-name">{item.label}</span>
            <Chip tone={item.exists ? "quiet" : "alert"}>{item.exists ? owner(item) : "Missing"}</Chip>
            <code>{item.path || "Not installed"}</code>
            <p>{item.desc}</p>
          </div>
        {/each}
      </div>
    </Fold>
  </Card>
{/if}

<style>
  .paths { display: grid; gap: 0; margin-top: var(--s3); border-top: 1px solid var(--line-soft); }
  .paths > div { display: grid; grid-template-columns: 128px auto minmax(180px, 1fr); align-items: center; gap: var(--s3); min-height: var(--row-h); border-bottom: 1px solid var(--line-soft); }
  .path-name { color: var(--ink); font-weight: 500; }
  code { overflow: hidden; color: var(--ink-mute); font-size: var(--f-micro); text-overflow: ellipsis; white-space: nowrap; }
  p { display: none; }
  .missing { opacity: 0.7; }
  @media (max-width: 720px) {
    .paths > div { grid-template-columns: 1fr auto; padding: var(--s2) 0; }
    code { grid-column: 1 / -1; }
  }
</style>
