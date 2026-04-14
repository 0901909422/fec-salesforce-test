let isEditMode = false;

const listeners = new Set();

/**
 * Set global mode
 */
export function setMode(value) {
  if (isEditMode === value) return;

  isEditMode = value;

  listeners.forEach((cb) => {
    try {
      cb(isEditMode);
    } catch (e) {
      console.error("[modeStore] listener error", e);
    }
  });
}

/**
 * Get current mode
 */
export function getMode() {
  return isEditMode;
}

/**
 * Subscribe to changes
 */
export function subscribeMode(callback) {
  listeners.add(callback);
}

/**
 * Unsubscribe
 */
export function unsubscribeMode(callback) {
  listeners.delete(callback);
}