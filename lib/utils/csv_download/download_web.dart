// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

// 엑셀에서 한글이 깨지지 않도록 UTF-8 BOM을 붙여서 다운로드
void downloadCsv(String filename, String content) {
  final bytes = utf8.encode('﻿$content');
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
