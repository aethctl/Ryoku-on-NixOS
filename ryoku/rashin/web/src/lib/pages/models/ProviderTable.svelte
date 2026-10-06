<script lang="ts">
  import Card from "$lib/ui/Card.svelte";
  import Chip from "$lib/ui/Chip.svelte";
  import Empty from "$lib/ui/Empty.svelte";
  import Field from "$lib/ui/Field.svelte";
  import type { HarnessCredentials, ProviderInfo } from "./types";

  type Filter = "all" | "ready" | "routable" | "free" | "credits" | "paid";
  interface Props {
    providers: ProviderInfo[];
    harnesses: HarnessCredentials[];
    loading?: boolean;
    error?: string;
  }

  let { providers, harnesses, loading = false, error = "" }: Props = $props();
  let query = $state("");
  let filter = $state<Filter>("all");

  const credentials = $derived.by(() => {
    const labels = new Set<string>();
    for (const harness of harnesses) for (const credential of harness.creds || []) labels.add(credential.label.toUpperCase());
    return labels;
  });
  const filtered = $derived(providers.filter((provider) => matches(provider)));

  function onBox(provider: ProviderInfo): boolean {
    return Boolean(provider.env && credentials.has(provider.env.toUpperCase()));
  }

  function matches(provider: ProviderInfo): boolean {
    if (filter === "ready" && !onBox(provider)) return false;
    if (filter === "routable" && !provider.routable) return false;
    if (["free", "credits", "paid"].includes(filter) && provider.class !== filter) return false;
    const needle = query.trim().toLowerCase();
    if (!needle) return true;
    const haystack = [provider.name, provider.id, provider.class, provider.env, ...(provider.models || []), ...(provider.modalities || [])].join(" ").toLowerCase();
    return haystack.includes(needle);
  }

  function modelLabel(provider: ProviderInfo): string {
    if (provider.models?.length) return provider.models.join(", ");
    if (provider.freeModels) return `${provider.freeModels} free model${provider.freeModels === 1 ? "" : "s"}`;
    return provider.modalities?.join(" · ") || "Catalogue managed by provider";
  }

  function contextLabel(value?: number): string {
    if (!value) return "—";
    if (value >= 1_000_000) return `${Number((value / 1_000_000).toFixed(1))}M`;
    return `${Math.round(value / 1000)}k`;
  }

  function credsFor(provider: ProviderInfo): string {
    return provider.env && credentials.has(provider.env.toUpperCase()) ? provider.env : "—";
  }

  const FILTERS: { id: Filter; label: string }[] = [
    { id: "all", label: "All" },
    { id: "ready", label: "On this box" },
    { id: "routable", label: "Routable" },
    { id: "free", label: "Free" },
    { id: "credits", label: "Credits" },
    { id: "paid", label: "Paid" },
  ];
</script>

<Card title="Provider directory" gloss="提供者" lead="Models the local router knows how to reach." pad={false}>
  <div class="toolbar">
    <div class="filters" aria-label="Filter providers">
      {#each FILTERS as item (item.id)}
        <button type="button" aria-pressed={filter === item.id} onclick={() => filter = item.id}>
          <Chip tone={filter === item.id ? "plate" : "line"}>{item.label}</Chip>
        </button>
      {/each}
    </div>
    <Field label="Find provider" aria-label="Find provider" placeholder="Name, model or credential" bind:value={query} />
  </div>

  {#if loading}
    <div class="empty-wrap"><Empty title="Loading provider directory" body="Waiting for the daemon to start Prowl's provider API." /></div>
  {:else if error}
    <div class="empty-wrap"><Empty title="The provider directory is unavailable" body="The daemon could not start Prowl's provider API. Fast lane and chat model controls above still work; restore that API, then reload this sheet." /></div>
  {:else if providers.length === 0}
    <div class="empty-wrap"><Empty title="No providers reported" body="Prowl returned an empty model directory. Check its catalogue, then reload this sheet." /></div>
  {:else if filtered.length === 0}
    <div class="empty-wrap"><Empty title="Nothing matches" body="Clear the search or choose another state filter." /></div>
  {:else}
    <div class="table-wrap">
      <table class="data">
        <thead><tr><th>Provider</th><th>Models</th><th>Credentials</th><th>State</th><th class="r">Context</th></tr></thead>
        <tbody>
          {#each filtered as provider (provider.id)}
            <tr>
              <td><strong>{provider.name}</strong><span class="provider-id">{provider.id}</span></td>
              <td><span class="models">{modelLabel(provider)}</span></td>
              <td class="mono">{credsFor(provider)}</td>
              <td>
                <div class="states">
                  <Chip tone={onBox(provider) ? "plate" : "quiet"}>{onBox(provider) ? "On box" : provider.class || "Unknown"}</Chip>
                  <Chip tone={provider.routable ? "line" : "quiet"}>{provider.health || provider.state || (provider.routable ? "Routable" : "Directory only")}</Chip>
                </div>
              </td>
              <td class="r mono">{contextLabel(provider.maxContext)}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</Card>

<style>
  .toolbar { display: flex; align-items: end; gap: var(--s4); justify-content: space-between; padding: var(--s4) var(--s5); border-bottom: 1px solid var(--line-soft); }
  .filters { display: flex; flex-wrap: wrap; gap: var(--s1); }
  .filters button { border-radius: 4px; }
  :global(.toolbar .field) { width: min(300px, 100%); }
  .table-wrap { overflow-x: auto; padding: var(--s2) var(--s5) var(--s4); }
  table { min-width: 760px; }
  strong { display: block; color: var(--ink); font-weight: 500; }
  .provider-id { color: var(--ink-faint); font-family: var(--mono); font-size: var(--f-micro); }
  .models { display: block; max-width: 34ch; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .states { display: flex; flex-wrap: wrap; gap: var(--s1); }
  .empty-wrap { padding: var(--s5); }
  @media (max-width: 760px) { .toolbar { align-items: stretch; flex-direction: column; } }
</style>
