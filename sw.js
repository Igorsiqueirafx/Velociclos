/**
 * Service Worker Avançado para Velociclos Academy
 * Otimizado para dispositivos móveis com cache inteligente e estratégias de rede
 * Suporte a PWA, Background Sync e Cache personalizado
 */

const CACHE_NAME = 'velociclos-v3.0.1-mobile-optimized';
const DATA_CACHE_NAME = 'velociclos-data-v1';

// Cache crítico para funcionamento offline
const CRITICAL_CACHE = [
    '/',
    '/index.html',
    '/cursos.html',
    '/conquistas.html',
    '/CSS/styles.css',
    '/CSS/cursos-layout-optimized.css',
    '/CSS/optimized/styles-core.css',
    '/js/veloacademy.js',
    '/js/utils/lazy-loading.js',
    '/js/theme-toggle.js',
    '/js/auth.js'
];

// Recursos de CDN que podem ser cacheados
const CDN_RESOURCES = [
    'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css',
    'https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap',
    'https://fonts.gstatic.com/s/poppins/v20/pxiEyp8kv8JHgFVrJJfecg.woff2'
];

// Estratégias de cache por tipo de recurso
const CACHE_STRATEGIES = {
    STATIC: 'cache-first',
    CDN: 'cache-first',
    API: 'network-first',
    IMAGES: 'cache-first',
    FONTS: 'cache-first'
};

// Lista de bloqueio para cache
const CACHE_BLACKLIST = [
    '/api/',
    '/admin',
    '.json'
];

/**
 * Instala o Service Worker
 */
self.addEventListener('install', event => {
    console.log('[SW] Instalando Service Worker v3.0.0');
    
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => {
                console.log('[SW] Precarregando cache crítico');
                return cache.addAll(CRITICAL_CACHE);
            })
            .then(() => {
                console.log('[SW] Pré-carregando recursos CDN');
                return Promise.all(
                    CDN_RESOURCES.map(url => 
                        caches.open(CACHE_NAME).then(cache => 
                            cache.add(url).catch(err => 
                                console.log('[SW] Falha ao cachear CDN:', url, err)
                            )
                        )
                    )
                );
            })
            .then(() => {
                console.log('[SW] Cache crítico carregado com sucesso');
                return self.skipWaiting();
            })
            .catch(error => {
                console.error('[SW] Erro durante a instalação:', error);
            })
    );
});

/**
 * Ativa o Service Worker
 */
self.addEventListener('activate', event => {
    console.log('[SW] Ativando Service Worker');
    
    event.waitUntil(
        caches.keys()
            .then(cacheNames => {
                return Promise.all(
                    cacheNames.map(cacheName => {
                        if (cacheName !== CACHE_NAME && cacheName !== DATA_CACHE_NAME) {
                            console.log('[SW] Deletando cache antigo:', cacheName);
                            return caches.delete(cacheName);
                        }
                    })
                );
            })
            .then(() => {
                console.log('[SW] Service Worker ativado');
                return self.clients.claim();
            })
    );
});

/**
 * Intercepta requisições de rede
 */
self.addEventListener('fetch', event => {
    const { request } = event;
    const url = new URL(request.url);
    
    // Ignorar requisições de não-GET
    if (request.method !== 'GET') {
        return;
    }
    
    // Lista de bloqueio
    if (CACHE_BLACKLIST.some(pattern => url.pathname.includes(pattern))) {
        return;
    }
    
    // Estratégia de cache baseada no tipo de recurso
    if (isApiRequest(url)) {
        event.respondWith(handleApiRequest(request));
    } else if (isImageRequest(url)) {
        event.respondWith(handleImageRequest(request));
    } else if (isFontRequest(url)) {
        event.respondWith(handleFontRequest(request));
    } else if (isCdnRequest(url)) {
        event.respondWith(handleCdnRequest(request));
    } else if (isStaticRequest(url)) {
        event.respondWith(handleStaticRequest(request));
    } else {
        event.respondWith(handleNetworkFirst(request));
    }
});

/**
 * Mensagens do cliente
 */
self.addEventListener('message', event => {
    if (event.data && event.data.type === 'SKIP_WAITING') {
        self.skipWaiting();
    }
    
    if (event.data && event.data.type === 'CLEAR_CACHE') {
        clearCache();
    }
});

/**
 * Sincronização em background
 */
self.addEventListener('sync', event => {
    if (event.tag === 'background-sync') {
        event.waitUntil(performBackgroundSync());
    }
});

/**
 * Notificações Push (para futuras implementações)
 */
self.addEventListener('push', event => {
    const options = {
        body: event.data ? event.data.text() : 'Nova atualização disponível',
        icon: '/icons/icon-192x192.png',
        badge: '/icons/badge-72x72.png',
        vibrate: [100, 50, 100],
        data: {
            dateOfArrival: Date.now(),
            primaryKey: '1'
        },
        actions: [
            {
                action: 'explore',
                title: 'Ver Agora',
                icon: '/icons/checkmark.png'
            },
            {
                action: 'close',
                title: 'Fechar',
                icon: '/icons/xmark.png'
            }
        ]
    };
    
    event.waitUntil(
        self.registration.showNotification('Velociclos Academy', options)
    );
});

/**
 * Manipula requisições de API com cache first
 */
async function handleApiRequest(request) {
    const cache = await caches.open(DATA_CACHE_NAME);
    const cachedResponse = await cache.match(request);
    
    if (cachedResponse) {
        // Atualizar cache em background
        updateCache(request, cache).catch(console.error);
        return cachedResponse;
    }
    
    try {
        const networkResponse = await fetch(request);
        
        if (networkResponse.ok) {
            cache.put(request, networkResponse.clone());
        }
        
        return networkResponse;
    } catch (error) {
        console.error('[SW] Erro na requisição API:', error);
        return new Response('Offline', { status: 503 });
    }
}

/**
 * Manipula requisições de imagem com cache inteligente
 */
async function handleImageRequest(request) {
    const cache = await caches.open(CACHE_NAME);
    const cachedResponse = await cache.match(request);
    
    if (cachedResponse) {
        return cachedResponse;
    }
    
    try {
        // Otimização para dispositivos móveis - verificar tamanho da tela
        const client = await getClient();
        const isMobile = client && client.innerWidth <= 768;
        
        const networkResponse = await fetch(request);
        
        if (networkResponse.ok && !isMobile) {
            cache.put(request, networkResponse.clone());
        }
        
        return networkResponse;
    } catch (error) {
        console.error('[SW] Erro ao carregar imagem:', error);
        // Retornar imagem placeholder
        return new Response('', { status: 404 });
    }
}

/**
 * Manipula requisições de fonte
 */
async function handleFontRequest(request) {
    const cache = await caches.open(CACHE_NAME);
    const cachedResponse = await cache.match(request);
    
    if (cachedResponse) {
        return cachedResponse;
    }
    
    try {
        const networkResponse = await fetch(request);
        
        if (networkResponse.ok) {
            cache.put(request, networkResponse.clone());
        }
        
        return networkResponse;
    } catch (error) {
        console.error('[SW] Erro ao carregar fonte:', error);
        return new Response('', { status: 503 });
    }
}

/**
 * Manipula requisições de CDN
 */
async function handleCdnRequest(request) {
    const cache = await caches.open(CACHE_NAME);
    const cachedResponse = await cache.match(request);
    
    if (cachedResponse) {
        return cachedResponse;
    }
    
    try {
        const networkResponse = await fetch(request);
        
        if (networkResponse.ok) {
            cache.put(request, networkResponse.clone());
        }
        
        return networkResponse;
    } catch (error) {
        console.error('[SW] Erro ao carregar recurso CDN:', error);
        return new Response('', { status: 503 });
    }
}

/**
 * Manipula requisições estáticas
 */
async function handleStaticRequest(request) {
    const cache = await caches.open(CACHE_NAME);
    const cachedResponse = await cache.match(request);
    
    if (cachedResponse) {
        return cachedResponse;
    }
    
    try {
        const networkResponse = await fetch(request);
        
        if (networkResponse.ok) {
            cache.put(request, networkResponse.clone());
        }
        
        return networkResponse;
    } catch (error) {
        console.error('[SW] Erro ao carregar recurso estático:', error);
        return new Response('', { status: 503 });
    }
}

/**
 * Estratégia Network First
 */
async function handleNetworkFirst(request) {
    try {
        const networkResponse = await fetch(request);
        
        if (networkResponse.ok) {
            const cache = await caches.open(CACHE_NAME);
            cache.put(request, networkResponse.clone());
        }
        
        return networkResponse;
    } catch (error) {
        console.log('[SW] Rede indisponível, usando cache:', request.url);
        const cache = await caches.open(CACHE_NAME);
        const cachedResponse = await cache.match(request);
        
        if (cachedResponse) {
            return cachedResponse;
        }
        
        return new Response('Offline', { status: 503 });
    }
}

/**
 * Atualiza cache em background
 */
async function updateCache(request, cache) {
    try {
        const networkResponse = await fetch(request);
        
        if (networkResponse.ok) {
            await cache.put(request, networkResponse);
        }
    } catch (error) {
        console.log('[SW] Falha ao atualizar cache em background:', error);
    }
}

/**
 * Limpa cache
 */
async function clearCache() {
    const cacheNames = await caches.keys();
    await Promise.all(
        cacheNames.map(cacheName => caches.delete(cacheName))
    );
    console.log('[SW] Cache limpo');
}

/**
 * Sincronização em background
 */
async function performBackgroundSync() {
    console.log('[SW] Executando sincronização em background');
    
    // Implementar lógica de sincronização
    // Exemplo: atualizar dados de cursos, verificar atualizações
}

/**
 * Detecta se é requisição de API
 */
function isApiRequest(url) {
    return url.pathname.includes('/api/') || url.hostname !== location.hostname;
}

/**
 * Detecta se é requisição de imagem
 */
function isImageRequest(url) {
    return /\.(jpg|jpeg|png|gif|webp|avif|svg)$/i.test(url.pathname);
}

/**
 * Detecta se é requisição de fonte
 */
function isFontRequest(url) {
    return /\.(woff|woff2|ttf|otf|eot)$/i.test(url.pathname);
}

/**
 * Detecta se é requisição de CDN
 */
function isCdnRequest(url) {
    return url.hostname.includes('cdnjs') || 
           url.hostname.includes('fonts.googleapis.com') || 
           url.hostname.includes('unpkg.com');
}

/**
 * Detecta se é requisição estática
 */
function isStaticRequest(url) {
    return /\.(css|js|html|htm)$/i.test(url.pathname);
}

/**
 * Obtém cliente ativo
 */
async function getClient() {
    const clients = await self.clients.matchAll({ type: 'window' });
    return clients[0] || null;
}

/**
 * Otimizações específicas para mobile
 */
if (typeof window !== 'undefined') {
    // Detectar conexão lenta e adaptar estratégias de cache
    if ('connection' in navigator) {
        const connection = navigator.connection;
        
        if (connection.effectiveType === 'slow-2g' || connection.effectiveType === '2g') {
            console.log('[SW] Conexão lenta detectada - ajustando estratégias de cache');
            
            // Reduzir tamanho do cache e desabilitar cache de imagens grandes
            // Implementar limpeza mais agressiva de cache
        }
    }
}

// Log de inicialização
console.log('[SW] Service Worker carregado - Versão mobile otimizada');