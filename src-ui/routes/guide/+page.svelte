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
</script>

<main class="wrap">
  <article class="panel">
    <p class="eyebrow">aSTT</p>
    <h1>Návod</h1>
    <p>
      Tohle je úvodní stránka uživatelského návodu. Popisuje základní orientaci v aplikaci a
      navazuje na menu <strong>Help -&gt; Návod</strong>.
    </p>
    <h2>Základní orientace</h2>
    <ul>
      <li><strong>ASR Control Panel</strong>: práce s nahráváním a přepisem.</li>
      <li><strong>Service Window</strong>: online metriky hosta a servisní report.</li>
      <li><strong>Project Control Console</strong>: provozní, systémové a diagnostické informace.</li>
    </ul>
    <div class="actions">
      <a href="/?window=asr">Přejít na ASR Control Panel</a>
      <a href="/?window=service">Přejít na Service Window</a>
      <a href="/demo-a002?tab=diagnostics">Přejít na Diagnostics</a>
    </div>
  </article>
</main>

<style>
  :global(body) {
    margin: 0;
    background: #eef3f8;
    color: #1f2a38;
    font-family: "Segoe UI", Tahoma, sans-serif;
  }
  .wrap {
    max-width: 900px;
    margin: 0 auto;
    padding: 1rem;
  }
  .panel {
    background: #fff;
    border: 1px solid #d6e0ec;
    border-radius: 10px;
    padding: 1rem;
  }
  .eyebrow {
    margin: 0;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: #4b637e;
    font-size: 0.75rem;
  }
  h1 {
    margin: 0.2rem 0 0.8rem;
  }
  ul {
    margin-top: 0.4rem;
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
