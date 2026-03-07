<script lang="ts">
  import { listenRuntimeMenuActions, invokeCommand as invoke } from "$lib/runtime-bridge";
  import { goto } from "$app/navigation";
  import { onMount } from "svelte";

  type Tab = "operations" | "knowledge" | "system" | "diagnostics";
  type Status = "new" | "active" | "blocked" | "done";

  type WorkItem = { id: string; title: string; owner: string; status: Status; estimateH: number };
  type DictTerm = { id: string; phrase: string; replacement: string; active: boolean };
  type Prompt = { id: string; name: string; content: string; updatedAt: string };
  type Settings = {
    theme: "clinic" | "slate" | "forest";
    language: string;
    autoSave: boolean;
    apiBaseUrl: string;
    apiEndpoint: string;
    apiKey: string;
  };
  type Account = { displayName: string; role: string; email: string; updatedAt: string };
  type LogEntry = { ts: string; level: string; message: string };

  const STORE_KEY = "astt_demo_a002_state_v3";
  const statusOrder: Status[] = ["new", "active", "blocked", "done"];

  const defaultItems: WorkItem[] = [
    { id: "W-001", title: "UI shell + navigation", owner: "adam", status: "done", estimateH: 2 },
    { id: "W-002", title: "Mock domain model", owner: "adam", status: "done", estimateH: 3 },
    { id: "W-003", title: "Quality gates wiring", owner: "qa", status: "active", estimateH: 4 },
    { id: "W-004", title: "Portable package checklist", owner: "qa", status: "active", estimateH: 3 },
    { id: "W-005", title: "Demo acceptance test", owner: "qa", status: "new", estimateH: 2 },
    { id: "W-006", title: "Cross-platform smoke", owner: "ops", status: "blocked", estimateH: 5 }
  ];

  const defaultDict: DictTerm[] = [
    { id: "D-001", phrase: "BP", replacement: "blood pressure", active: true },
    { id: "D-002", phrase: "HR", replacement: "heart rate", active: true }
  ];

  const defaultPrompts: Prompt[] = [
    {
      id: "P-001",
      name: "Clinical Summary",
      content: "Summarize findings and next steps in 5 bullets.",
      updatedAt: new Date().toISOString()
    }
  ];

  const defaultSettings: Settings = {
    theme: "clinic",
    language: "cs",
    autoSave: true,
    apiBaseUrl: "https://httpbin.org",
    apiEndpoint: "/get",
    apiKey: ""
  };

  const defaultAccount: Account = {
    displayName: "Demo User",
    role: "Physician",
    email: "demo@example.com",
    updatedAt: new Date().toISOString()
  };

  let isClient = false;
  let activeTab = $state<Tab>("operations");

  let items = $state<WorkItem[]>(defaultItems);
  let query = $state("");
  let filter = $state<Status | "all">("all");
  let capacityH = $state(16);
  let runtimeMessage = $state("Not checked yet.");

  let dictionary = $state<DictTerm[]>(defaultDict);
  let newPhrase = $state("");
  let newReplacement = $state("");

  let prompts = $state<Prompt[]>(defaultPrompts);
  let selectedPromptId = $state(defaultPrompts[0]?.id ?? "");
  let newPromptName = $state("");
  let newPromptContent = $state("");

  let settings = $state<Settings>(defaultSettings);
  let account = $state<Account>(defaultAccount);
  let apiStatus = $state("Not tested");
  let apiLatencyMs = $state(0);
  let apiPreview = $state("");
  let apiBusy = $state(false);

  let diagnostics = $state("Not checked yet.");
  let diagnosticsError = $state("");
  let logs = $state<LogEntry[]>([]);
  let logMessage = $state("");
  let logLevel = $state("INFO");
  let logFilePath = $state("");

  function applyTabFromUrl() {
    if (!isClient) return;
    const params = new URLSearchParams(window.location.search);
    const tab = params.get("tab");
    if (tab === "operations" || tab === "knowledge" || tab === "system" || tab === "diagnostics") {
      activeTab = tab;
    }
  }

  function newId(prefix: string): string {
    return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
  }

  function applyTheme() {
    if (!isClient) return;
    document.documentElement.setAttribute("data-demo-theme", settings.theme);
  }

  function persist() {
    if (!isClient || !settings.autoSave) return;
    localStorage.setItem(
      STORE_KEY,
      JSON.stringify({ items, dictionary, prompts, selectedPromptId, settings, account, capacityH })
    );
  }

  function load() {
    if (!isClient) return;
    const raw = localStorage.getItem(STORE_KEY);
    if (!raw) return;
    try {
      const v = JSON.parse(raw);
      if (Array.isArray(v.items)) items = v.items;
      if (Array.isArray(v.dictionary)) dictionary = v.dictionary;
      if (Array.isArray(v.prompts)) prompts = v.prompts;
      if (typeof v.selectedPromptId === "string") selectedPromptId = v.selectedPromptId;
      if (v.settings) settings = { ...defaultSettings, ...v.settings };
      if (v.account) account = { ...defaultAccount, ...v.account };
      if (typeof v.capacityH === "number") capacityH = v.capacityH;
    } catch {
      // ignore bad local storage state
    }
  }

  onMount(() => {
    isClient = true;
    load();
    applyTheme();
    applyTabFromUrl();
    void runDiagnostics();
    void refreshLogs();

    let disposed = false;
    let unlistenMenuActions: (() => void) | null = null;

    void (async () => {
      try {
        const unlisten = await listenRuntimeMenuActions((action) => {
          if (action === "show_asr") {
            void goto("/?window=asr");
            return;
          }
          if (action === "show_service") {
            void goto("/?window=service");
            return;
          }
          if (action === "open_diagnostics") {
            activeTab = "diagnostics";
            void runDiagnostics();
            return;
          }
          if (action === "open_guide") {
            void goto("/guide");
            return;
          }
          void goto("/about");
        });
        if (disposed) {
          unlisten();
          return;
        }
        unlistenMenuActions = unlisten;
      } catch {
        // Ignore missing runtime menu bridge.
      }
    })();

    return () => {
      disposed = true;
      if (unlistenMenuActions) {
        unlistenMenuActions();
      }
    };
  });

  $effect(() => {
    if (!isClient) return;
    applyTheme();
    persist();
  });

  function totalEstimate(list: WorkItem[]): number {
    return list.reduce((sum, i) => sum + i.estimateH, 0);
  }

  const visible = $derived(
    items
      .filter((i) => (filter === "all" ? true : i.status === filter))
      .filter((i) => {
        const q = query.trim().toLowerCase();
        if (!q) return true;
        return (
          i.id.toLowerCase().includes(q) ||
          i.title.toLowerCase().includes(q) ||
          i.owner.toLowerCase().includes(q)
        );
      })
      .toSorted((a, b) => {
        if (statusOrder.indexOf(a.status) !== statusOrder.indexOf(b.status)) {
          return statusOrder.indexOf(a.status) - statusOrder.indexOf(b.status);
        }
        return a.id.localeCompare(b.id);
      })
  );

  const doneCount = $derived(items.filter((i) => i.status === "done").length);
  const completion = $derived(items.length ? Math.round((doneCount / items.length) * 100) : 0);
  const loadPercent = $derived(Math.round((totalEstimate(items) / Math.max(capacityH, 1)) * 100));

  function cycleStatus(id: string) {
    const next = (status: Status): Status =>
      status === "new" ? "active" : status === "active" ? "blocked" : status === "blocked" ? "done" : "new";
    items = items.map((i) => (i.id === id ? { ...i, status: next(i.status) } : i));
  }

  function addTerm() {
    const phrase = newPhrase.trim();
    const replacement = newReplacement.trim();
    if (!phrase || !replacement) return;
    dictionary = [{ id: newId("D"), phrase, replacement, active: true }, ...dictionary];
    newPhrase = "";
    newReplacement = "";
  }

  function selectedPrompt(): Prompt | null {
    return prompts.find((p) => p.id === selectedPromptId) ?? null;
  }

  function addPrompt() {
    const name = newPromptName.trim();
    const content = newPromptContent.trim();
    if (!name || !content) return;
    const p = { id: newId("P"), name, content, updatedAt: new Date().toISOString() };
    prompts = [p, ...prompts];
    selectedPromptId = p.id;
    newPromptName = "";
    newPromptContent = "";
  }

  function updatePromptContent(content: string) {
    prompts = prompts.map((p) =>
      p.id === selectedPromptId ? { ...p, content, updatedAt: new Date().toISOString() } : p
    );
  }

  async function checkRuntime() {
    try {
      const r = await invoke<Record<string, unknown>>("demo_health");
      runtimeMessage = JSON.stringify(r);
      await appendLog("INFO", "Runtime health check OK");
    } catch (e) {
      runtimeMessage = String(e);
      await appendLog("ERROR", `Runtime health check failed: ${String(e)}`);
    }
  }

  async function runDiagnostics() {
    diagnosticsError = "";
    try {
      const r = await invoke<Record<string, unknown>>("demo_diagnostics");
      diagnostics = JSON.stringify(r, null, 2);
      if (typeof r.log_file === "string") logFilePath = r.log_file;
    } catch (e) {
      diagnostics = "Diagnostics failed.";
      diagnosticsError = String(e);
    }
  }

  async function appendLog(level: string, message: string) {
    const r = await invoke<Record<string, unknown>>("demo_append_log", { level, message });
    if (typeof r.log_file === "string") logFilePath = r.log_file;
    await refreshLogs();
  }

  async function refreshLogs() {
    try {
      const r = await invoke<{ lines?: string[]; log_file?: string }>("demo_read_logs", { limit: 200 });
      if (typeof r.log_file === "string") logFilePath = r.log_file;
      const lines = Array.isArray(r.lines) ? r.lines : [];
      logs = lines
        .map((line) => {
          const [ts, level, ...rest] = line.split("|");
          return {
            ts: Number.isFinite(Number(ts)) ? new Date(Number(ts)).toLocaleString() : "-",
            level: level || "INFO",
            message: rest.join("|")
          };
        })
        .reverse();
    } catch (e) {
      diagnosticsError = String(e);
    }
  }

  async function addManualLog() {
    const message = logMessage.trim();
    if (!message) return;
    await appendLog(logLevel, message);
    logMessage = "";
  }

  async function testApi() {
    apiBusy = true;
    const start = performance.now();
    try {
      const base = settings.apiBaseUrl.trim().replace(/\/+$/, "");
      const endpoint = settings.apiEndpoint.trim().replace(/^\/+/, "");
      const url = endpoint ? `${base}/${endpoint}` : base;
      const headers: Record<string, string> = { Accept: "application/json, text/plain, */*" };
      if (settings.apiKey.trim()) headers.Authorization = `Bearer ${settings.apiKey.trim()}`;
      const res = await fetch(url, { method: "GET", headers });
      apiLatencyMs = Math.round(performance.now() - start);
      apiStatus = `${res.status} ${res.statusText}`;
      apiPreview = (await res.text()).slice(0, 1000);
      await appendLog(res.ok ? "INFO" : "WARN", `API test ${url} -> ${res.status}`);
    } catch (e) {
      apiLatencyMs = Math.round(performance.now() - start);
      apiStatus = "FAILED";
      apiPreview = String(e);
      await appendLog("ERROR", `API test failed: ${String(e)}`);
    } finally {
      apiBusy = false;
    }
  }
</script>

<main class="wrap">
  <h1>Project Control Console</h1>
  <p class="meta">No-STT demo with 4 tabs and testable features.</p>

  <nav class="tabs">
    <button class:active={activeTab === "operations"} onclick={() => (activeTab = "operations")}>Operations</button>
    <button class:active={activeTab === "knowledge"} onclick={() => (activeTab = "knowledge")}>Knowledge</button>
    <button class:active={activeTab === "system"} onclick={() => (activeTab = "system")}>System</button>
    <button class:active={activeTab === "diagnostics"} onclick={() => (activeTab = "diagnostics")}>Diagnostics</button>
  </nav>

  {#if activeTab === "operations"}
    <section class="panel">
      <div class="row"><button onclick={checkRuntime}>Check runtime</button><span>{runtimeMessage}</span></div>
      <div class="grid3">
        <label>Search <input bind:value={query} /></label>
        <label>Status <select bind:value={filter}><option value="all">all</option><option value="new">new</option><option value="active">active</option><option value="blocked">blocked</option><option value="done">done</option></select></label>
        <label>Capacity(h) <input type="number" min="1" bind:value={capacityH} /></label>
      </div>
      <p class="meta">Done: {doneCount}, Completion: {completion}%, Load: {loadPercent}%</p>
      <table>
        <thead><tr><th>ID</th><th>Title</th><th>Owner</th><th>Status</th><th>Est</th><th>Action</th></tr></thead>
        <tbody>
          {#each visible as item}
            <tr>
              <td>{item.id}</td><td>{item.title}</td><td>{item.owner}</td><td>{item.status}</td><td>{item.estimateH}</td>
              <td><button onclick={() => cycleStatus(item.id)}>Cycle</button></td>
            </tr>
          {/each}
        </tbody>
      </table>
    </section>
  {:else if activeTab === "knowledge"}
    <section class="grid2">
      <article class="panel">
        <h2>Dictionary</h2>
        <div class="grid3"><input bind:value={newPhrase} placeholder="Term" /><input bind:value={newReplacement} placeholder="Replacement" /><button onclick={addTerm}>Add</button></div>
        <table>
          <thead><tr><th>Term</th><th>Replacement</th><th>Active</th><th>Action</th></tr></thead>
          <tbody>
            {#each dictionary as d}
              <tr>
                <td>{d.phrase}</td><td>{d.replacement}</td><td>{d.active ? "yes" : "no"}</td>
                <td><button onclick={() => (dictionary = dictionary.map((x) => x.id === d.id ? { ...x, active: !x.active } : x))}>Toggle</button></td>
              </tr>
            {/each}
          </tbody>
        </table>
      </article>
      <article class="panel">
        <h2>Prompts</h2>
        <label>Select <select bind:value={selectedPromptId}>{#each prompts as p}<option value={p.id}>{p.name}</option>{/each}</select></label>
        <label>Content <textarea rows="6" value={selectedPrompt()?.content ?? ""} oninput={(e) => updatePromptContent((e.currentTarget as HTMLTextAreaElement).value)}></textarea></label>
        <p class="meta">Updated: {selectedPrompt()?.updatedAt ? new Date(selectedPrompt()!.updatedAt).toLocaleString() : "-"}</p>
        <h3>Add prompt</h3>
        <input bind:value={newPromptName} placeholder="Name" />
        <textarea rows="4" bind:value={newPromptContent} placeholder="Prompt body"></textarea>
        <button onclick={addPrompt}>Save prompt</button>
      </article>
    </section>
  {:else if activeTab === "system"}
    <section class="grid2">
      <article class="panel">
        <h2>Account</h2>
        <label>Name <input bind:value={account.displayName} /></label>
        <label>Role <input bind:value={account.role} /></label>
        <label>Email <input bind:value={account.email} /></label>
        <button onclick={() => (account = { ...account, updatedAt: new Date().toISOString() })}>Save profile</button>
      </article>
      <article class="panel">
        <h2>Settings + API</h2>
        <label>Theme <select bind:value={settings.theme}><option value="clinic">clinic</option><option value="slate">slate</option><option value="forest">forest</option></select></label>
        <label>Language <input bind:value={settings.language} /></label>
        <label><input type="checkbox" bind:checked={settings.autoSave} /> Auto-save</label>
        <label>API base <input bind:value={settings.apiBaseUrl} /></label>
        <label>API endpoint <input bind:value={settings.apiEndpoint} /></label>
        <label>API key <input type="password" bind:value={settings.apiKey} /></label>
        <div class="row"><button onclick={testApi} disabled={apiBusy}>{apiBusy ? "Testing..." : "Test API"}</button><span>{apiStatus} ({apiLatencyMs} ms)</span></div>
        <textarea rows="6" readonly value={apiPreview}></textarea>
      </article>
    </section>
  {:else}
    <section class="diag-stack">
      <article class="panel">
        <h2>Diagnostics</h2>
        <div class="row"><button onclick={runDiagnostics}>Refresh diagnostics</button><button onclick={refreshLogs}>Refresh logs</button></div>
        {#if diagnosticsError}<p class="error">{diagnosticsError}</p>{/if}
        <pre>{diagnostics}</pre>
      </article>
      <article class="panel">
        <h2>Service logs</h2>
        <p class="meta">Log file: {logFilePath || "-"}</p>
        <div class="grid3"><select bind:value={logLevel}><option>INFO</option><option>WARN</option><option>ERROR</option></select><input bind:value={logMessage} placeholder="message" /><button onclick={addManualLog}>Append</button></div>
        <button onclick={() => appendLog("ERROR", "Simulated diagnostic error")}>Simulate error</button>
        <div class="logbox">
          {#each logs as l}<p><strong>{l.ts}</strong> [{l.level}] {l.message}</p>{/each}
        </div>
      </article>
    </section>
  {/if}
</main>

<style>
  :global(html[data-demo-theme="clinic"]) { --bg: #f1f7ff; --card: #fff; --line: #d4e0ef; --txt: #1f2a38; }
  :global(html[data-demo-theme="slate"]) { --bg: #edf1f6; --card: #fff; --line: #c7d2e0; --txt: #1f2a38; }
  :global(html[data-demo-theme="forest"]) { --bg: #edf8ef; --card: #fff; --line: #c7dfce; --txt: #1f2a38; }
  :global(body) { margin: 0; font-family: "Segoe UI", Tahoma, sans-serif; background: var(--bg); color: var(--txt); }
  .wrap { max-width: 1100px; margin: 0 auto; padding: 1rem; }
  .meta { color: #50627a; font-size: 0.9rem; }
  .tabs { display: grid; grid-template-columns: repeat(4, 1fr); gap: 0.4rem; margin-bottom: 0.7rem; }
  .tabs button.active { font-weight: 700; }
  .panel { border: 1px solid var(--line); border-radius: 10px; background: var(--card); padding: 0.7rem; }
  .row { display: flex; gap: 0.5rem; align-items: center; flex-wrap: wrap; }
  .grid2 { display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.7rem; }
  .grid3 { display: grid; grid-template-columns: 1fr 1fr auto; gap: 0.5rem; }
  .diag-stack { display: grid; grid-template-columns: 1fr; gap: 0.7rem; }
  label { display: flex; flex-direction: column; gap: 0.2rem; font-size: 0.85rem; }
  input, select, button, textarea { font: inherit; padding: 0.4rem 0.5rem; border: 1px solid var(--line); border-radius: 8px; }
  table { width: 100%; border-collapse: collapse; }
  th, td { border-bottom: 1px solid var(--line); padding: 0.4rem 0.25rem; text-align: left; }
  pre { margin: 0; border: 1px solid var(--line); border-radius: 8px; padding: 0.5rem; max-height: 260px; overflow: auto; font-size: 0.8rem; }
  .logbox { margin-top: 0.6rem; max-height: 260px; overflow: auto; border: 1px solid var(--line); border-radius: 8px; padding: 0.35rem; font-size: 0.82rem; }
  .error { color: #9b2f1a; }
  @media (max-width: 900px) {
    .tabs, .grid2, .grid3 { grid-template-columns: 1fr; }
  }
</style>
