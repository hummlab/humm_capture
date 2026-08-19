import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void openExternalUrl(Uri uri) {
  // Assigning `window.location` does not use the browser popup mechanism.
  // It therefore remains reliable in Safari and Chromium when a Flutter
  // callback originates from a canvas-based control.
  globalContext.setProperty('location'.toJS, uri.toString().toJS);
}
