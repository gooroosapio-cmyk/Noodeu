import { useSyncExternalStore } from "react";

function subscribe(cb: () => void) {
  window.addEventListener("online", cb);
  window.addEventListener("offline", cb);
  return () => {
    window.removeEventListener("online", cb);
    window.removeEventListener("offline", cb);
  };
}

/** État du réseau tel que le navigateur le connaît. */
export function useOnline() {
  return useSyncExternalStore(subscribe, () => navigator.onLine, () => true);
}

/** Exécute `cb` quand l'application revient au premier plan ou que le réseau revient. */
export function onResume(cb: () => void) {
  const vis = () => document.visibilityState === "visible" && cb();
  document.addEventListener("visibilitychange", vis);
  window.addEventListener("online", cb);
  window.addEventListener("focus", cb);
  return () => {
    document.removeEventListener("visibilitychange", vis);
    window.removeEventListener("online", cb);
    window.removeEventListener("focus", cb);
  };
}
