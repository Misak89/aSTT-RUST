type InvokeArgs = Record<string, unknown>;
type RuntimeMenuAction =
  | "show_asr"
  | "show_service"
  | "open_guide"
  | "open_diagnostics"
  | "open_about";

type ElectronAPI = {
  invoke: <T = unknown>(command: string, args?: InvokeArgs) => Promise<T>;
  openMediaFile: (options?: unknown) => Promise<string | string[] | null>;
  onMenuAction?: (handler: (action: RuntimeMenuAction) => void) => (() => void) | Promise<() => void>;
};

function electronApi(): ElectronAPI | null {
  if (typeof window === "undefined") return null;
  return (window as Window & { electronAPI?: ElectronAPI }).electronAPI ?? null;
}

export async function invokeCommand<T = unknown>(
  command: string,
  args: InvokeArgs = {}
): Promise<T> {
  const electron = electronApi();
  if (electron) {
    return electron.invoke<T>(command, args);
  }

  const { invoke } = await import("@tauri-apps/api/core");
  return invoke<T>(command, args);
}

export async function openMediaFileDialog(
  options?: unknown
): Promise<string | string[] | null> {
  const electron = electronApi();
  if (electron) {
    return electron.openMediaFile(options);
  }

  const { open } = await import("@tauri-apps/plugin-dialog");
  return open(options as never);
}

export async function listenRuntimeMenuActions(
  handler: (action: RuntimeMenuAction) => void
): Promise<() => void> {
  const electron = electronApi();
  if (electron && typeof electron.onMenuAction === "function") {
    const maybeUnlisten = await electron.onMenuAction(handler);
    return typeof maybeUnlisten === "function" ? maybeUnlisten : () => {};
  }

  const { listen } = await import("@tauri-apps/api/event");
  const unlisten = await listen<string>("astt://menu-action", (event) => {
    const action = event.payload;
    if (
      action === "show_asr" ||
      action === "show_service" ||
      action === "open_guide" ||
      action === "open_diagnostics" ||
      action === "open_about"
    ) {
      handler(action);
    }
  });
  return unlisten;
}
