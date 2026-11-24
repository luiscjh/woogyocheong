// 가입(온보딩) 화면의 개인정보 동의 항목. 내용은 web/privacy.html을 요약한 것이므로
// 방침을 바꾸면 여기 문구와 policyVersion(방침 시행일)도 함께 맞출 것
class PrivacyConsentItem {
  final String title;
  final List<(String, String)> details; // (구분, 내용)

  const PrivacyConsentItem(this.title, this.details);
}

class PrivacyConsent {
  static const policyVersion = '2026-10-11';

  static const _refuse = '동의를 거부할 수 있으나, 거부하시면 회원 가입과 앱 이용이 불가능합니다.';

  static const items = [
    PrivacyConsentItem('[필수] 개인정보 수집·이용 동의', [
      ('수집 항목', '이름, 이메일 주소, 로그인 식별자, 생년월일, 기수, 소속 팀\n'
          '앱 이용 중: 전화번호(리더가 입력), 출석·회비 기록, 심방 신청 내용, 앱 내 알림'),
      ('수집 목적', '회원 확인과 로그인, 청년부 명단·소팀 관리, 출석·회비 관리, 심방 신청 접수, 앱 내 알림'),
      ('보유 기간', '회원 탈퇴 시 즉시 삭제. 출석·회비·심방 등 운영 기록은 탈퇴 후 1년간 보관 후 삭제'),
      ('거부 권리', _refuse),
    ]),
    PrivacyConsentItem('[필수] 민감정보(종교 관련 정보) 처리 동의', [
      ('처리 항목', '교회 청년부 소속과 출석 기록(종교에 관한 정보로 볼 수 있음), 심방 신청 사유'),
      ('처리 목적', '청년부 명단·출석 관리와 심방 일정 조율'),
      ('보유 기간', '회원 탈퇴 시 즉시 삭제. 운영 기록은 탈퇴 후 1년간 보관 후 삭제'),
      ('거부 권리', _refuse),
    ]),
    PrivacyConsentItem('[필수] 개인정보 국외 이전 동의', [
      ('이전받는 자', 'Google LLC (미국) — Firebase 로그인 서비스'),
      ('이전 항목', '로그인 이메일, 이름, 로그인 식별자'),
      ('이전 시기·방법', '앱 사용 시 네트워크를 통한 전송'),
      ('이용 목적', '로그인 처리'),
      ('보유 기간', '회원 탈퇴 또는 위탁 계약 종료 시까지'),
      ('거부 권리', _refuse),
    ]),
  ];
}
