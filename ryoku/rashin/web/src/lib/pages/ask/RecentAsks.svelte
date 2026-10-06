<script lang="ts">
  import Empty from "$lib/ui/Empty.svelte";
  import Fold from "$lib/ui/Fold.svelte";

  export interface RecentAsk {
    at: string;
    kind?: string;
    q: string;
    a: string;
  }

  interface Props {
    asks: RecentAsk[];
    error?: string;
    onrecall: (ask: RecentAsk) => void;
  }

  let { asks, error = "", onrecall }: Props = $props();

  function ago(value: string): string {
    const elapsed = (Date.now() - new Date(value).getTime()) / 1000;
    if (!Number.isFinite(elapsed) || elapsed < 0) return "recently";
    if (elapsed < 90) return "moments ago";
    if (elapsed < 3600) return `${Math.round(elapsed / 60)} min ago`;
    if (elapsed < 86400) return `${Math.round(elapsed / 3600)} h ago`;
    return `${Math.round(elapsed / 86400)} d ago`;
  }
</script>

<section class="recent" aria-label="Recent asks">
  <Fold>
    {#snippet summary()}
      <span class="fold-title">Recent asks <span>{asks.length}</span></span>
    {/snippet}
    <div class="recent-body">
      {#if error}
        <Empty title="Recent asks are unavailable" body="Start the Rashin daemon, then return here to load the shared history." />
      {:else if asks.length === 0}
        <Empty title="No recent asks" body="Finished quick answers will appear here." />
      {:else}
        <div class="plates">
          {#each asks as ask (ask.at + ask.q)}
            <button class="plate" type="button" onclick={() => onrecall(ask)}>
              <span class="question">{ask.q}</span>
              <time datetime={ask.at}>{ago(ask.at)}</time>
            </button>
          {/each}
        </div>
      {/if}
    </div>
  </Fold>
</section>

<style>
  .recent { min-width: 0; padding-top: var(--s3); border-top: 1px solid var(--line-soft); }
  .fold-title { display: flex; justify-content: space-between; width: 100%; }
  .fold-title span { color: var(--ink-faint); font-family: var(--mono); }
  .recent-body { padding-top: var(--s2); }
  .question { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  time { flex: none; font-family: var(--mono); font-size: var(--f-tiny); letter-spacing: var(--track-label); text-transform: uppercase; color: var(--ink-faint); }
</style>
