import 'dart:convert';
import 'package:share_plus/share_plus.dart';

// 모바일에는 웹처럼 다운로드 폴더가 따로 없으므로, OS 공유 시트를 통해
// 파일 앱 저장/카카오톡 전송 등으로 내보내도록 함. 엑셀에서 한글이 깨지지
// 않도록 웹 버전과 동일하게 UTF-8 BOM을 붙임
Future<void> downloadCsv(String filename, String content) async {
  final bytes = utf8.encode('﻿$content');
  await Share.shareXFiles(
    [XFile.fromData(bytes, name: filename, mimeType: 'text/csv')],
    fileNameOverrides: [filename],
  );
}
