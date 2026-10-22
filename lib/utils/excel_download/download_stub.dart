import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';

const _xlsxMimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

// 모바일에는 웹처럼 다운로드 폴더가 따로 없으므로, OS 공유 시트를 통해
// 파일 앱 저장/카카오톡 전송 등으로 내보내도록 함. 이 플랫폼에서는 save()가
// 부작용 없이 바이트만 돌려준다
Future<void> downloadExcelBook(Excel book, String filename) async {
  final bytes = book.save();
  if (bytes == null) return;
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(Uint8List.fromList(bytes), name: filename, mimeType: _xlsxMimeType)],
    fileNameOverrides: [filename],
  ));
}
