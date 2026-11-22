// 앱(Android/iOS)은 이미 설치된 앱이므로 "앱 설치" 버튼을 보여 주지 않는다
WebInstallState webInstallState() => WebInstallState.installed;

Future<bool> promptWebInstall() async => false;

enum WebInstallState { installed, prompt, ios, inapp, manual }
