// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:excel/excel.dart';

// excel 패키지는 웹에서 save(fileName: ...)를 호출하는 순간 그 자체로
// 브라우저 다운로드를 실행한다 — Blob/AnchorElement를 따로 만들면 다운로드가
// 중복되므로 여기서는 그대로 위임만 한다
Future<void> downloadExcelBook(Excel book, String filename) async {
  book.save(fileName: filename);
}
