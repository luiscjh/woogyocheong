/*
 * 우교청 PWA 서비스 워커
 *
 * 원칙: "오래된 버전이 캐시에 갇히지 않는다."
 *  - 앱 파일(index.html, main.dart.js, flutter_bootstrap.js, assets 등)은
 *    절대 캐시하지 않는다. 그런 요청은 respondWith 하지 않으므로 브라우저
 *    기본 동작(HTTP 캐시 + 서버의 Cache-Control: no-cache 재검증)을 그대로
 *    따른다. 새로 배포하면 다음 로딩에서 바로 새 버전을 받는다.
 *  - 같은 출처(origin)의 페이지 이동(navigate) 요청만 가로채 네트워크로
 *    보내고, 네트워크 자체가 실패(오프라인)했을 때만 미리 저장해 둔
 *    offline.html을 보여준다.
 *  - Firebase 예약 경로(/__/…)와 다른 출처 요청(Google 로그인, Firestore,
 *    Storage 등)은 건드리지 않는다.
 */
'use strict';

const CACHE_PREFIX = 'woogyocheong-';
const CACHE_NAME = CACHE_PREFIX + 'offline-v2';
const OFFLINE_URL = 'offline.html';
// offline.html은 아이콘을 data URI로 품고 있어 다른 파일 없이 단독으로 표시된다.
const PRECACHE = [OFFLINE_URL];

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      // cache: 'reload' — HTTP 캐시를 거치지 않고 서버에서 최신본을 받아 저장
      await cache.addAll(
        PRECACHE.map((url) => new Request(url, { cache: 'reload' }))
      );
      await self.skipWaiting();
    })()
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys
          .filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      );
      await self.clients.claim();
    })()
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.mode !== 'navigate' || request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (url.pathname.startsWith('/__/')) return;

  event.respondWith(
    (async () => {
      try {
        return await fetch(request);
      } catch (error) {
        const cached = await caches.match(OFFLINE_URL, {
          cacheName: CACHE_NAME,
        });
        return (
          cached ||
          new Response('오프라인 상태입니다. 인터넷 연결 후 다시 시도해 주세요.', {
            status: 503,
            headers: { 'Content-Type': 'text/plain; charset=utf-8' },
          })
        );
      }
    })()
  );
});
