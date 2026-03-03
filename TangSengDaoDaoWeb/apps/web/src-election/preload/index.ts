import { contextBridge, ipcRenderer } from "electron";

contextBridge.exposeInMainWorld("__POWERED_ELECTRON__", true);

contextBridge.exposeInMainWorld("ipc", {
  send: (channel: string, ...args: any[]) => ipcRenderer.send(channel, ...args),
  invoke: (channel: string, ...args: any[]): Promise<any> =>
    ipcRenderer.invoke(channel, ...args),
  on: (
    channel: string,
    listener: (event: Electron.IpcRendererEvent, ...args: any[]) => void
  ) => {
    ipcRenderer.on(channel, listener);
  },
  once: (
    channel: string,
    listener: (event: Electron.IpcRendererEvent, ...args: any[]) => void
  ) => {
    ipcRenderer.once(channel, listener);
  },
});

// Expose native notification API
contextBridge.exposeInMainWorld("electronNotification", {
  show: (options: any) => ipcRenderer.invoke('show-native-notification', options),
  close: (tag: string) => ipcRenderer.invoke('close-native-notification', tag),
  closeAll: () => ipcRenderer.invoke('close-all-native-notifications'),
  onClicked: (callback: (data: any) => void) => {
    console.log("onClicked");
    ipcRenderer.on('notification-clicked', (event, data) => callback(data));
  },
  onActionClicked: (callback: (data: any) => void) => {
    ipcRenderer.on('notification-action-clicked', (event, data) => callback(data));
  },
  // Test notification icon
  testNotificationIcon: () => ipcRenderer.invoke('test-notification-icon'),
});
