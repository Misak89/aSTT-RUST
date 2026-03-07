const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("electronAPI", {
  invoke: (command, args = {}) => ipcRenderer.invoke("astt:invoke", command, args),
  openMediaFile: (options = {}) => ipcRenderer.invoke("astt:openMediaFile", options),
});
