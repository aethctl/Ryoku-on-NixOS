<script lang="ts">
  import { onMount } from "svelte";
  import { api } from "$lib/api/client";
  import Page from "$lib/app/Page.svelte";
  import type { PromptImage } from "$lib/chat/protocol";
  import type { ChatLane, ChatStore } from "$lib/chat/store.svelte";
  import type { RecentAsk } from "$lib/pages/ask/RecentAsks.svelte";
  import { readAskStream } from "$lib/pages/ask/askstream";
  import ApprovalDock from "./ApprovalDock.svelte";
  import Composer from "./Composer.svelte";
  import Inspector from "./Inspector.svelte";
  import SessionsPane from "./SessionsPane.svelte";
  import Transcript from "./Transcript.svelte";
  import Icon from "$lib/ui/Icon.svelte";
  import Kbd from "$lib/ui/Kbd.svelte";

  interface Props {
    store: ChatStore;
    lane: ChatLane;
  }

  let { store, lane }: Props = $props();

  const preferenceKey = (name: string) => `rashin.${lane}.${name}`;
  let sessionsOpen = $state(localStorage.getItem(preferenceKey("sessions-open")) !== "0");
  let inspectorOpen = $state(localStorage.getItem(preferenceKey("inspector-open")) !== "0");
  let sendMode = $state<"agent" | "quick">("agent");
  let composerField: HTMLTextAreaElement | undefined = $state();
  let lastSessionStamp = "";
  let quickRunning = $state(false);
  let quickStatus = $state("");
  let quickError = $state("");
  let quickGeneration = 0;
  let recentAsks = $state<RecentAsk[]>([]);
  let recentError = $state("");

  const currentSession = $derived(store.state.history.find((session) => session.id === store.state.session.id));
  const title = $derived(lane === "ryoku" ? "Ryoku" : "Chat");
  const gloss = $derived(lane === "ryoku" ? "力" : "対話");

  function setSessionsOpen(open: boolean): void {
    sessionsOpen = open;
    localStorage.setItem(preferenceKey("sessions-open"), open ? "1" : "0");
  }

  function setInspectorOpen(open: boolean): void {
    inspectorOpen = open;
    localStorage.setItem(preferenceKey("inspector-open"), open ? "1" : "0");
  }

  function setSendMode(mode: "agent" | "quick"): void {
    sendMode = mode;
    localStorage.setItem(preferenceKey("send-mode"), mode);
    quickError = "";
  }

  async function loadRecent(): Promise<void> {
    if (lane !== "ryoku") return;
    try {
      const data = await api.askRecent() as unknown;
      recentAsks = Array.isArray(data) ? data as RecentAsk[] : [];
      recentError = "";
    } catch {
      recentError = "The daemon did not answer.";
    }
  }

  async function sendQuick(text: string, images: PromptImage[]): Promise<void> {
    const question = text.trim();
    if (!question || quickRunning) return;
    if (images.length > 0) {
      quickError = "Quick questions cannot include images. Switch to Agent to send them.";
      return;
    }

    const turn = ++quickGeneration;
    quickRunning = true;
    quickStatus = "waking the quick lane";
    quickError = "";
    store.setDraft("");
    try {
      const response = await api.ask(question);
      if (!response.body) throw new Error("The daemon returned no stream.");
      await readAskStream(response.body, (marker) => {
        if (turn !== quickGeneration) return;
        if (marker.kind === "working") quickStatus = marker.detail || "working";
        else if (marker.kind === "perm") quickStatus = marker.detail || "waiting for approval";
        else if (marker.kind === "answer") quickStatus = "answer received";
        else if (marker.kind === "error") quickError = marker.detail || "The quick answer stopped.";
      });
      await loadRecent();
    } catch (cause) {
      if (turn === quickGeneration) {
        quickError = cause instanceof Error ? cause.message : "The daemon did not answer. Try again.";
      }
    } finally {
      if (turn === quickGeneration) quickRunning = false;
    }
  }

  async function cancel(): Promise<void> {
    if (!quickRunning) {
      store.cancel();
      return;
    }
    ++quickGeneration;
    quickRunning = false;
    quickStatus = "";
    try {
      await api.askCancel();
      quickError = "Stopped.";
    } catch {
      quickError = "The stop request did not reach the daemon.";
    }
  }

  function send(text: string, images: PromptImage[]): void {
    if (lane === "ryoku" && sendMode === "quick") void sendQuick(text, images);
    else store.send(text, images);
  }

  function newChat(): void {
    store.newChat();
  }

  function recallAsk(ask: RecentAsk): void {
    store.setDraft(ask.q);
    composerField?.focus();
  }

  function handleShortcut(event: KeyboardEvent): void {
    if (event.key === "Escape" && (store.state.busy || quickRunning) && !event.defaultPrevented) {
      event.preventDefault();
      void cancel();
      return;
    }
    if (!event.ctrlKey || event.altKey || event.metaKey) return;
    const key = event.key.toLowerCase();
    if (!["n", "k", "b", "i"].includes(key)) return;
    event.preventDefault();
    if (key === "n") newChat();
    else if (key === "k") composerField?.focus();
    else if (key === "b") setSessionsOpen(!sessionsOpen);
    else setInspectorOpen(!inspectorOpen);
  }

  $effect(() => {
    const stamp = `${store.state.session.id}:${store.state.session.title}`;
    if (!stamp || stamp === ":" || stamp === lastSessionStamp) return;
    lastSessionStamp = stamp;
    store.loadSessions();
  });

  onMount(() => {
    if (lane === "ryoku" && localStorage.getItem(preferenceKey("send-mode")) === "quick") sendMode = "quick";
    store.loadSessions();
    void loadRecent();
    window.addEventListener("keydown", handleShortcut);
    return () => window.removeEventListener("keydown", handleShortcut);
  });
</script>

<Page {title} {gloss} bare>
  <div class="workspace">
    {#if sessionsOpen}
      <SessionsPane
        {lane}
        sessions={store.state.history}
        currentId={store.state.session.id}
        {recentAsks}
        {recentError}
        onnew={newChat}
        onswitch={(id) => store.switchSession(id)}
        oncollapse={() => setSessionsOpen(false)}
        onrecall={recallAsk}
      />
    {/if}

    <section class="conversation" aria-label={lane === "ryoku" ? "Chat with the Needle" : `Chat with ${store.state.agent || "Hermes"}`}>
      {#if !sessionsOpen || !inspectorOpen}
        <div class="pane-reveals">
          {#if !sessionsOpen}
            <button type="button" onclick={() => setSessionsOpen(true)}>
              <Icon name="sidebar" size={14} />
              Conversations
              <Kbd keys={["Ctrl", "B"]} />
            </button>
          {/if}
          <span></span>
          {#if !inspectorOpen}
            <button type="button" onclick={() => setInspectorOpen(true)}>
              Inspector
              <Kbd keys={["Ctrl", "I"]} />
              <Icon name="sliders" size={14} />
            </button>
          {/if}
        </div>
      {/if}

      <div class="transcript-wrap">
        <Transcript
          {lane}
          items={store.state.items}
          seed={store.state.session.id || "the needle"}
          harnessName={store.state.agent}
          permissions={store.state.permissions}
          banner={store.state.banner}
          replaying={store.state.replaying}
          busy={store.state.busy || quickRunning}
          onnew={newChat}
          onanswer={(requestId, optionId) => store.answerPermission(requestId, optionId)}
          onsuggest={(text) => {
            store.setDraft(text);
            composerField?.focus();
          }}
        />
      </div>

      {#if store.state.permissions.length > 0}
        <div class="dock-wrap">
          <ApprovalDock
            permissions={store.state.permissions}
            onanswer={(requestId, optionId) => store.answerPermission(requestId, optionId)}
          />
        </div>
      {/if}

      <Composer
        {lane}
        bind:focusTarget={composerField}
        draft={store.draft}
        busy={store.state.busy || quickRunning}
        connected={store.connected}
        activity={store.state.activity}
        commands={store.state.commands}
        models={store.state.models}
        currentModel={store.state.currentModel}
        agent={store.state.agent}
        approvals={store.state.approvals}
        waiting={store.state.permissions.length > 0}
        usage={store.state.usage}
        {sendMode}
        {quickRunning}
        {quickStatus}
        {quickError}
        ondraft={(value) => store.setDraft(value)}
        onsend={send}
        oncancel={() => void cancel()}
        onmodel={(id) => store.setModel(id)}
        onapprovals={(mode) => store.setApprovals(mode)}
        onmode={setSendMode}
      />
    </section>

    {#if inspectorOpen}
      <Inspector
        session={store.state.session}
        cwd={currentSession?.cwd}
        agent={store.state.agent}
        currentModel={store.state.currentModel}
        models={store.state.models}
        usage={store.state.usage}
        items={store.state.items}
        busy={store.state.busy || quickRunning}
        permissions={store.state.permissions}
        commands={store.state.commands}
        oncollapse={() => setInspectorOpen(false)}
      />
    {/if}
  </div>
</Page>

<style>
  .workspace { position: relative; display: grid; grid-template-columns: auto minmax(0, 1fr) auto; height: 100%; min-height: 0; overflow: hidden; }
  .conversation { display: flex; min-width: 0; min-height: 0; flex-direction: column; background: var(--paper); }
  .transcript-wrap { position: relative; display: flex; flex: 1; min-height: 0; }
  .dock-wrap { flex: none; padding: 0 var(--s5) var(--s3); }
  .pane-reveals { display: grid; grid-template-columns: auto 1fr auto; align-items: center; min-height: 44px; padding: var(--s2) var(--s3); border-bottom: 1px solid var(--line-soft); }
  .pane-reveals button { display: inline-flex; align-items: center; gap: var(--s2); min-height: 28px; padding: 0 var(--s2); border-radius: var(--radius); color: var(--ink-mute); font-size: var(--f-small); transition: color var(--t-fast) var(--ease), background-color var(--t-fast) var(--ease); }
  .pane-reveals button:hover { color: var(--ink); background: var(--tint5); }

  @container (max-width: 1050px) {
    .workspace { grid-template-columns: minmax(0, 1fr); }
    .workspace :global(.sessions), .workspace :global(.inspector) { position: absolute; inset-block: 0; z-index: 20; border-color: var(--line-strong); }
    .workspace :global(.sessions) { left: 0; }
    .workspace :global(.inspector) { right: 0; }
  }
</style>
