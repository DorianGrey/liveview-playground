export function arrayBufferToBase64(buffer) {
  return btoa(String.fromCharCode(...new Uint8Array(buffer)));
}

export function base64ToArrayBuffer(base64) {
  return Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
}

export function arrayBufferToString(buffer) {
  return String.fromCharCode(...new Uint8Array(buffer));
}
