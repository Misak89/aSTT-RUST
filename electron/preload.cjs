const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("electronAPI", {
  invoke: (command, args = {}) => ipcRenderer.invoke("astt:invoke", command, args),
  openMediaFile: (options = {}) => ipcRenderer.invoke("astt:openMediaFile", options),
  onMenuAction: (handler) => {
    if (typeof handler !== "function") {
      return () => {};
    }
    const channel = "astt:menu-action";
    const listener = (_event, action) => {
      handler(action);
    };
    ipcRenderer.on(channel, listener);
    return () => {
      ipcRenderer.removeListener(channel, listener);
    };
  },
});
