import 'dart:io';
import 'package:path/path.dart' as path;

/// 파일 저장 경로 헬퍼
class PathHelper {
  /// 기본 다운로드 경로 생성
  /// 
  /// 예시:
  /// - Windows: C:\Users\사용자\Documents\급여관리프로그램
  /// - macOS: /Users/사용자/Documents/급여관리프로그램
  /// - Linux: /home/사용자/Documents/급여관리프로그램
  static String getDefaultDownloadPath() {
    String documentsPath;
    
    if (Platform.isWindows) {
      // Windows: C:\Users\사용자\Documents
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      documentsPath = path.join(userProfile, 'Documents');
    } else if (Platform.isMacOS) {
      // macOS: /Users/사용자/Documents
      final home = Platform.environment['HOME'] ?? '';
      documentsPath = path.join(home, 'Documents');
    } else {
      // Linux: /home/사용자/Documents
      final home = Platform.environment['HOME'] ?? '';
      documentsPath = path.join(home, 'Documents');
    }
    
    return path.join(documentsPath, '급여관리프로그램');
  }
  
  /// 거래처별 하위 폴더 경로 생성
  /// 
  /// 구조: 급여관리프로그램/거래처명/연도/
  /// 예시: 급여관리프로그램/삼성전자/2025/
  static String getClientFolderPath({
    required String basePath,
    required String clientName,
    required int year,
  }) {
    // 파일명에 사용할 수 없는 문자 제거
    final safeClientName = _sanitizeFileName(clientName);
    return path.join(basePath, safeClientName, year.toString());
  }
  
  /// 파일 전체 경로 생성
  /// 
  /// useClientSubfolders = true:
  ///   급여관리프로그램/삼성전자/2025/삼성전자_2025년01월_급여대장.csv
  /// 
  /// useClientSubfolders = false:
  ///   급여관리프로그램/삼성전자_2025년01월_급여대장.csv
  static String getFilePath({
    required String basePath,
    required String clientName,
    required int year,
    required int month,
    required String fileType, // 'csv', 'pdf_register', 'pdf_payslip'
    String? workerName,
    bool useClientSubfolders = true,
  }) {
    String fileName;
    
    switch (fileType) {
      case 'csv':
        fileName = '${clientName}_${year}년${month.toString().padLeft(2, '0')}월_급여대장.csv';
        break;
      case 'pdf_register':
        fileName = '${clientName}_${year}년${month.toString().padLeft(2, '0')}월_급여대장.pdf';
        break;
      case 'pdf_payslip':
        if (workerName == null) {
          throw ArgumentError('workerName is required for payslip PDF');
        }
        fileName = '${clientName}_${year}년${month.toString().padLeft(2, '0')}월_${workerName}_급여명세서.pdf';
        break;
      default:
        throw ArgumentError('Unknown file type: $fileType');
    }
    
    // 파일명 정리
    fileName = _sanitizeFileName(fileName);
    
    if (useClientSubfolders) {
      final folderPath = getClientFolderPath(
        basePath: basePath,
        clientName: clientName,
        year: year,
      );
      return path.join(folderPath, fileName);
    } else {
      return path.join(basePath, fileName);
    }
  }
  
  /// 폴더 생성 (없으면 생성)
  static Future<Directory> ensureDirectoryExists(String dirPath) async {
    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
  
  /// 파일명에서 사용할 수 없는 문자 제거
  /// 
  /// Windows: < > : " / \ | ? *
  /// 추가: 파일 시스템 호환성을 위해 제거
  static String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_') // 연속된 공백을 언더스코어로
        .replaceAll(RegExp(r'_+'), '_'); // 연속된 언더스코어를 하나로
  }
  
  /// 기본 경로 예시 생성
  static String getExamplePath() {
    if (Platform.isWindows) {
      return 'C:\\Users\\사용자\\Documents\\급여관리프로그램';
    } else if (Platform.isMacOS) {
      return '/Users/사용자/Documents/급여관리프로그램';
    } else {
      return '/home/사용자/Documents/급여관리프로그램';
    }
  }
}
