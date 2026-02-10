// Tauri doesn't have a Node.js server to do proper SSR
// so we use adapter-static with a fallback to index.html to put the site in SPA mode
// See: https://svelte.dev/docs/kit/single-page-apps
// See: https://v2.tauri.app/start/frontend/sveltekit/ for more info
import adapter from "@sveltejs/adapter-static";
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter({
      fallback: "index.html",
    }),
    files: {
        assets: 'static',
        hooks: {
            client: 'src-ui/hooks.client',
            server: 'src-ui/hooks.server'
        },
        lib: 'src-ui/lib',
        params: 'src-ui/params',
        routes: 'src-ui/routes',
        serviceWorker: 'src-ui/service-worker',
        appTemplate: 'src-ui/app.html',
        errorTemplate: 'src-ui/error.html'
    },
  },
};

export default config;
