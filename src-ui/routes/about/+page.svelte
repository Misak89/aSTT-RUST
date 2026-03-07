<script lang="ts">
  import { goto } from "$app/navigation";
  import { onMount } from "svelte";
  import { listenRuntimeMenuActions } from "$lib/runtime-bridge";

  onMount(() => {
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
            void goto("/demo-a002?tab=diagnostics");
            return;
          }
          if (action === "open_guide") {
            void goto("/guide");
            return;
          }
          return;
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
</script>

<main class="wrap">
  <article class="panel">
    <p class="eyebrow">aSTT</p>
    <h1>About aSTT</h1>
    <p>
      Desktop aplikace pro ASR workflow a servisní diagnostiku. Runtime používá SvelteKit UI,
      Rust backend a Python sidecar.
    </p>
    <dl>
      <dt>Aplikace</dt>
      <dd>aSTT Desktop App</dd>
      <dt>Runtime</dt>
      <dd>Tauri 2 / Electron variant</dd>
      <dt>Verze</dt>
      <dd>0.1.0</dd>
    </dl>
    <div class="actions">
      <a href="/?window=asr">Zpět na ASR Control Panel</a>
      <a href="/guide">Otevřít Návod</a>
    </div>
  </article>
</main>

<style>
  :global(body) {
    margin: 0;
    background: #f3f0ea;
    color: #2a241c;
    font-family: "Segoe UI", Tahoma, sans-serif;
  }
  .wrap {
    max-width: 900px;
    margin: 0 auto;
    padding: 1rem;
  }
  .panel {
    background: #fff;
    border: 1px solid #e0d6c7;
    border-radius: 10px;
    padding: 1rem;
  }
  .eyebrow {
    margin: 0;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: #7d6a54;
    font-size: 0.75rem;
  }
  h1 {
    margin: 0.2rem 0 0.8rem;
  }
  dl {
    margin: 0.8rem 0;
    display: grid;
    grid-template-columns: 130px 1fr;
    gap: 0.35rem 0.75rem;
  }
  dt {
    font-weight: 600;
  }
  dd {
    margin: 0;
  }
  .actions {
    margin-top: 1rem;
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
  }
  a {
    color: #0f5ea6;
    font-weight: 600;
  }
</style>
