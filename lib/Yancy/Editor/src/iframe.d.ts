export {};

declare global {
  interface Window {
    Yancy: {
      allowOrigins: Array<string | RegExp>;
      editorPort?: MessagePort;
    };
  }
}
