<script lang="ts">
  import Card from "$lib/ui/Card.svelte";
  import Button from "$lib/ui/Button.svelte";
  import Chip from "$lib/ui/Chip.svelte";
  import Empty from "$lib/ui/Empty.svelte";
  import Field from "$lib/ui/Field.svelte";
  import type { CodeStatus, ProwlHit, ProwlReport } from "./types";
  import { formatTokens, repoName } from "./types";

  interface Props {
    report: ProwlReport | null;
    status: CodeStatus | null;
    loading: boolean;
    error?: string;
    hits: ProwlHit[] | null;
    searching: boolean;
    searchError?: string;
    onsearch: (query: string) => void;
  }

  let { report, status, loading, error, hits, searching, searchError, onsearch }: Props = $props();
  let query = $state("");
  const saved = $derived(report?.savings?.savedTokens ?? 0);

  function submit(event: SubmitEvent): void {
    event.preventDefault();
    const next = query.trim();
    if (next) onsearch(next);
  }
</script>

<Card title="Code intelligence" gloss="索引" lead="Measured context the index kept out of agent prompts." class="code-card">
  {#snippet tools()}
    {#if report?.repo}<Chip mono>{repoName(report.repo)}{status?.serving ? " · live" : " · cached"}</Chip>{/if}
  {/snippet}

  {#if loading}
    <p class="loading">Reading the code index…</p>
  {:else if error}
    <Empty title="Code intelligence is unavailable" body={`${error} Check that Prowl is installed, then reload this sheet.`} icon="search" />
  {:else if !report?.installed}
    <Empty title="Prowl is not installed" body="Install Prowl to measure how much indexed answers save." icon="search" />
  {:else}
    {#if !report.indexed}
      <div class="index-note"><strong>No live index yet</strong><span>Run <code>prowl init</code> in {repoName(report.repo) || "the repository"}. The measured ledger stays visible while the report catches up.</span></div>
    {/if}
    <div class="saved">
      <strong>{formatTokens(saved)}</strong>
      <span>{saved ? "tokens saved by indexed answers" : "No measured savings yet. Indexed answers record themselves here."}</span>
    </div>

    <div class="ledger" aria-label="Code intelligence measurements">
      <div><strong>{report.savings?.queries ?? 0}</strong><span>Indexed answers</span></div>
      <div><strong>{formatTokens(report.savings?.answerTokens ?? 0)}</strong><span>Answer tokens</span></div>
      <div><strong>{report.symbols ?? 0}</strong><span>Symbols mapped</span></div>
    </div>

    <div class="signals">
      <Chip tone={(report.doctor?.errors ?? 0) > 0 ? "alert" : "line"}>Errors {report.doctor?.errors ?? 0}</Chip>
      <Chip tone={(report.doctor?.warns ?? 0) > 0 ? "quiet" : "line"}>Warnings {report.doctor?.warns ?? 0}</Chip>
      <Chip>{status?.serving ? "Live index" : "Cached report"}</Chip>
    </div>

    {#if report.hotspots?.length}
      <div class="hotspots">
        <p class="t-label">Dependency hotspots</p>
        {#each report.hotspots.slice(0, 5) as hotspot (hotspot.file)}
          <div><code title={hotspot.file}>{hotspot.file}</code><strong>{hotspot.in}</strong></div>
        {/each}
      </div>
    {/if}

    <form class="search" onsubmit={submit}>
      <Field label="Search the indexed source" placeholder="Describe a symbol or behavior" bind:value={query} autocomplete="off" />
      <Button type="submit" variant="plate" icon="search" armed={!!query.trim()} busy={searching}>Search</Button>
    </form>

    {#if searchError}
      <p class="search-error">{searchError} Try a shorter query or check the Prowl service.</p>
    {:else if hits !== null}
      <div class="results" aria-live="polite">
        {#if hits.length}
          {#each hits as hit (`${hit.file}:${hit.line}:${hit.text}`)}
            <article>
              <p><code>{hit.file}:{hit.line}</code></p>
              <span>{hit.text}</span>
            </article>
          {/each}
        {:else}
          <Empty title="No cited matches" body="Try a symbol name or a more specific behavior." icon="search" />
        {/if}
      </div>
    {/if}
  {/if}
</Card>

<style>
  :global(.code-card) { min-height: 100%; }
  .loading { color: var(--ink-mute); }
  .saved { display: flex; align-items: baseline; gap: var(--s4); padding-bottom: var(--s5); border-bottom: 1px solid var(--line-soft); }
  .saved strong { flex: none; font-family: var(--display); font-size: clamp(46px, 6vw, 76px); font-weight: 300; line-height: .9; letter-spacing: -.04em; color: var(--ink); font-variant-numeric: tabular-nums; }
  .saved span { max-width: 27ch; color: var(--ink-mute); font-size: var(--f-small); }
  .ledger { display: grid; grid-template-columns: repeat(3, 1fr); margin: var(--s5) 0; border-block: 1px solid var(--line-soft); }
  .ledger div { display: flex; flex-direction: column; gap: var(--s1); padding: var(--s3) var(--s4); border-right: 1px solid var(--line-soft); }
  .ledger div:first-child { padding-left: 0; }
  .ledger div:last-child { border-right: 0; }
  .ledger strong { color: var(--ink); font-size: 18px; font-weight: 500; }
  .ledger span { color: var(--ink-faint); font-family: var(--mono); font-size: var(--f-tiny); letter-spacing: var(--track-label); text-transform: uppercase; }
  .index-note { display: flex; align-items: baseline; gap: var(--s3); margin-bottom: var(--s4); padding: var(--s3); border: 1px solid var(--line-soft); border-radius: var(--radius); }
  .index-note strong { flex: none; color: var(--ink); font-size: var(--f-small); font-weight: 500; }
  .index-note span { color: var(--ink-mute); font-size: var(--f-small); }
  .index-note code { color: var(--ink); font-size: var(--f-micro); }
  .signals { display: flex; flex-wrap: wrap; gap: var(--s2); }
  .hotspots { margin-top: var(--s5); }
  .hotspots > p { margin-bottom: var(--s2); }
  .hotspots div { display: flex; align-items: baseline; gap: var(--s4); padding: var(--s2) 0; border-bottom: 1px solid var(--line-soft); }
  .hotspots code { min-width: 0; flex: 1; overflow: hidden; color: var(--ink-mute); font-size: var(--f-micro); text-overflow: ellipsis; white-space: nowrap; }
  .hotspots strong { color: var(--ink); font-size: var(--f-small); font-weight: 500; }
  .search { display: grid; grid-template-columns: 1fr auto; align-items: end; gap: var(--s2); margin-top: var(--s5); padding-top: var(--s5); border-top: 1px solid var(--line-soft); }
  .search-error { margin-top: var(--s3); color: var(--alert); font-size: var(--f-small); }
  .results { display: flex; flex-direction: column; gap: var(--s2); margin-top: var(--s4); }
  .results article { padding: var(--s3); border: 1px solid var(--line-soft); border-radius: var(--radius); background: var(--tint5); }
  .results code { color: var(--ink); font-size: var(--f-micro); }
  .results span { display: block; margin-top: var(--s1); color: var(--ink-mute); font-size: var(--f-small); line-height: 1.45; }
  @media (max-width: 580px) {
    .saved { align-items: flex-start; flex-direction: column; }
    .ledger { grid-template-columns: 1fr; }
    .ledger div { border-right: 0; border-bottom: 1px solid var(--line-soft); padding-inline: 0; }
    .ledger div:last-child { border-bottom: 0; }
    .search { grid-template-columns: 1fr; }
  }
</style>
