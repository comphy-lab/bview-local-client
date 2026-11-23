// Retire registrations from earlier releases.
self.addEventListener( 'install', event => event.waitUntil( self.skipWaiting() ) );
self.addEventListener( 'activate', event => event.waitUntil( self.registration.unregister() ) );
