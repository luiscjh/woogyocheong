# 청년부 관리 앱 - 설정 가이드

## 1. Flutter 설치

```bash
# macOS
# https://flutter.dev/docs/get-started/install/macos 에서 SDK 다운로드 후
# 또는 Homebrew 설치 후:
brew install --cask flutter

# 설치 확인
flutter doctor
```

## 2. Flutter 프로젝트 초기화

```bash
cd ~/church_youth_app

# pubspec.yaml이 있는 디렉토리에서 실행
flutter pub get
```

## 3. Firebase 프로젝트 생성

1. https://console.firebase.google.com 접속
2. 새 프로젝트 생성 (예: `church-youth-app`)
3. **Authentication** 활성화
   - 로그인 방법 > 이메일/비밀번호 사용 설정
4. **Firestore Database** 활성화
   - 테스트 모드로 시작 (나중에 보안 규칙 변경)
5. **Storage** 활성화

## 4. FlutterFire CLI로 Firebase 연결

```bash
# FlutterFire CLI 설치
dart pub global activate flutterfire_cli

# Firebase CLI 설치 및 로그인
npm install -g firebase-tools
firebase login

# Firebase 연결 (프로젝트 루트에서 실행)
cd ~/church_youth_app
flutterfire configure
```

이 명령어가 `lib/firebase_options.dart` 파일을 자동 생성합니다.

## 5. Android 설정

`android/app/build.gradle`에서 패키지 이름 확인:
```gradle
applicationId "com.example.church_youth_app"
```

## 6. iOS 설정

Xcode에서 Bundle Identifier 설정:
`com.example.churchYouthApp`

## 7. 앱 실행

```bash
flutter run
```

## 8. 첫 번째 관리자 계정 만들기

앱 실행 후 회원가입으로 계정을 만든 뒤,
Firebase 콘솔 > Firestore > `users` 컬렉션에서
해당 문서의 `role` 필드를 `"admin"`으로 변경하세요.

## 9. Firestore 보안 규칙 (배포 전 필수)

Firebase 콘솔 > Firestore > 규칙에 아래 내용 적용:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isLoggedIn() {
      return request.auth != null;
    }
    function isAdmin() {
      return isLoggedIn() && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    function isOwner(userId) {
      return isLoggedIn() && request.auth.uid == userId;
    }

    match /users/{userId} {
      allow read: if isLoggedIn();
      allow write: if isAdmin() || isOwner(userId);
    }
    match /attendance/{docId} {
      allow read: if isLoggedIn();
      allow write: if isLoggedIn();
    }
    match /fees/{docId} {
      allow read: if isLoggedIn();
      allow write: if isLoggedIn();
    }
    match /visits/{docId} {
      allow read: if isLoggedIn();
      allow write: if isLoggedIn();
    }
    match /banners/{docId} {
      allow read: if isLoggedIn();
      allow write: if isAdmin();
    }
  }
}
```

## 10. 엑셀 가져오기 형식

엑셀 파일의 첫 행은 헤더, 2번째 행부터 데이터:

| A (이름) | B (이메일) | C (전화번호) | D (부서/그룹) |
|---------|---------|------------|------------|
| 홍길동 | hong@email.com | 010-1234-5678 | 1부 |
| 김철수 | kim@email.com | 010-9876-5432 | 2부 |
