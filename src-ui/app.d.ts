export {};

declare global {
  interface Window {
    electronAPI?: {
      invoke: <T = unknown>(
        command: string,
        args?: Record<string, unknown>
      ) => Promise<T>;
      openMediaFile: (options?: unknown) => Promise<string | string[] | null>;
    };
  }
}
