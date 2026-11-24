// 앱(Android/iOS)은 이미 설치된 앱이므로 "앱 설치" 버튼을 보여 주지 않는다
WebInstallState webInstallState() => WebInstallState.installed;

Future<bool> promptWebInstall() async => false;

bool openInExternalBrowser() => false;

enum WebInstallState { installed, prompt, android, ios, inappAndroid, inappIos, manual }

// Google 로그인 방식 판단용(앱에서는 쓰지 않음)
bool preferRedirectSignIn() => false;

bool isInAppBrowser() => false;
