import 'dart:io';

/// Removes Flutter's offline shell for Feedback Console hosting builds.
///
/// The console is an authenticated, live review workspace. Serving a stale
/// JavaScript shell is worse than the small amount of extra network traffic,
/// so the hosting release replaces the generated worker with a one-shot
/// cleanup worker and disables registration in the current bootstrap. Older
/// clients still request the cleanup worker; refreshed clients do not create a
/// new offline cache afterwards.
void main() {
  final worker = File('build/web/flutter_service_worker.js');
  final bootstrap = File('build/web/flutter_bootstrap.js');
  if (!worker.existsSync() || !bootstrap.existsSync()) {
    stderr.writeln('Run `flutter build web` before preparing the hosting build.');
    exitCode = 64;
    return;
  }

  worker.writeAsStringSync('''
'use strict';
self.addEventListener('install', (event) => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil((async () => {
  const keys = await caches.keys();
  await Promise.all(keys.map((key) => caches.delete(key)));
  await self.registration.unregister();
  const clients = await self.clients.matchAll({type: 'window'});
  await Promise.all(clients.map((client) => client.navigate(client.url)));
})()));
''');

  final originalBootstrap = bootstrap.readAsStringSync();
  final updatedBootstrap = originalBootstrap.replaceFirst(
    RegExp(r'_flutter\.loader\.load\(\{\s*serviceWorkerSettings:\s*\{\s*serviceWorkerVersion: "[^"]+"\s*}\s*}\);'),
    "_flutter.loader.load({config: {renderer: 'canvaskit'}});",
  );
  if (updatedBootstrap == originalBootstrap) {
    stderr.writeln('Could not locate Flutter service-worker bootstrap settings.');
    exitCode = 65;
    return;
  }
  bootstrap.writeAsStringSync(updatedBootstrap);
}
