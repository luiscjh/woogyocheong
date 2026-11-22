/*
 * 우교청 서비스 워커 정리용(kill switch)
 *
 * 우교청 웹은 서비스 워커를 쓰지 않는다(설치형으로 실행해도 manifest만
 * 사용). 이 파일은 31차 작업에서 잠시 배포된 PWA용 sw.js를 이미
 * 받아 간 브라우저를 정리하기 위해서만 남겨 둔다. 브라우저가 sw.js
 * 업데이트를 확인하면 이 버전을 받아:
 *  - 우교청/Flutter가 만든 캐시를 모두 지우고
 *  - 스스로 등록을 해제한 뒤
 *  - 열려 있는 탭을 새로고침해 서비스 워커 없이 최신 버전을 받게 한다.
 */
'use strict';

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys
          .filter((key) => key.startsWith('woogyocheong-') || key.startsWith('flutter-'))
          .map((key) => caches.delete(key))
      );
      await self.registration.unregister();
      const clients = await self.clients.matchAll({ type: 'window' });
      for (const client of clients) {
        // Firebase 예약 경로(/__/auth 등)의 창·iframe은 로그인 중일 수 있어 건드리지 않는다.
        if (new URL(client.url).pathname.startsWith('/__/')) continue;
        client.navigate(client.url);
      }
    })()
  );
});
