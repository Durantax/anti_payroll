# ✅ 완료: 기본 다운로드 경로 설정 기능

## 🎯 추가된 기능

### 1. 기본 경로 설정 ⭐
```
예시: C:\Users\사용자\Documents\급여관리프로그램
```

### 2. 거래처별 하위 폴더 자동 생성 ⭐
```
구조: 급여관리프로그램/거래처명/연도/파일명

예시:
급여관리프로그램/
├─ 삼성전자/
│  ├─ 2024/
│  │  ├─ 삼성전자_2024년12월_급여대장.csv
│  │  └─ 삼성전자_2024년12월_급여명세서_홍길동.pdf
│  └─ 2025/
│     ├─ 삼성전자_2025년01월_급여대장.csv
│     └─ 삼성전자_2025년01월_급여대장.pdf
└─ LG전자/
   └─ 2025/
      └─ LG전자_2025년01월_급여대장.csv
```

---

## 📁 폴더 구조 옵션

### 옵션 1: 거래처별 하위 폴더 사용 (기본) ✅
```
급여관리프로그램/
└─ 삼성전자/
   └─ 2025/
      ├─ 삼성전자_2025년01월_급여대장.csv
      ├─ 삼성전자_2025년01월_급여대장.pdf
      └─ 삼성전자_2025년01월_급여명세서_홍길동.pdf
```

**장점**:
- 거래처별로 깔끔하게 정리
- 연도별로 자동 분류
- 파일 찾기 쉬움

### 옵션 2: 하위 폴더 없이 한 곳에 모음
```
급여관리프로그램/
├─ 삼성전자_2025년01월_급여대장.csv
├─ 삼성전자_2025년01월_급여대장.pdf
├─ LG전자_2025년01월_급여대장.csv
└─ LG전자_2025년01월_급여대장.pdf
```

**장점**:
- 단순한 구조
- 모든 파일 한눈에 보임

---

## 🛠️ 설정 방법

### 1. AppSettings 모델 (저장됨)
```dart
AppSettings(
  serverUrl: 'http://localhost:8000',
  downloadBasePath: 'C:\\Users\\사용자\\Documents\\급여관리프로그램',
  useClientSubfolders: true, // 거래처별 하위 폴더 사용
)
```

### 2. 설정하지 않으면
- 파일 저장 시마다 **저장 위치 선택 창**이 뜸
- 매번 수동으로 선택 필요

### 3. 설정하면
- 자동으로 **정해진 경로에 저장**
- 폴더가 없으면 **자동 생성**
- 저장 후 **탐색기로 자동 열림** (Windows)

---

## 💻 플랫폼별 기본 경로

### Windows
```
C:\Users\사용자\Documents\급여관리프로그램
```

### macOS
```
/Users/사용자/Documents/급여관리프로그램
```

### Linux
```
/home/사용자/Documents/급여관리프로그램
```

---

## 📝 파일명 자동 생성 규칙

### CSV 급여대장
```
{거래처명}_{연도}년{월}월_급여대장.csv
예: 삼성전자_2025년01월_급여대장.csv
```

### PDF 급여대장
```
{거래처명}_{연도}년{월}월_급여대장.pdf
예: 삼성전자_2025년01월_급여대장.pdf
```

### PDF 급여명세서
```
{거래처명}_{연도}년{월}월_{직원명}_급여명세서.pdf
예: 삼성전자_2025년01월_홍길동_급여명세서.pdf
```

### 파일명 정리 규칙
- 특수문자 (`< > : " / \ | ? *`) → 언더스코어(`_`)로 변경
- 공백 → 언더스코어(`_`)로 변경
- 연속된 언더스코어 → 하나로 합침

---

## 🔧 구현 내용

### 1. AppSettings 모델 확장
```dart
class AppSettings {
  final String serverUrl;
  final String apiKey;
  final String downloadBasePath;        // ✨ NEW!
  final bool useClientSubfolders;       // ✨ NEW!
  
  // 기본값
  downloadBasePath: '',                 // 빈 문자열 = 수동 선택
  useClientSubfolders: true,            // 기본은 하위 폴더 사용
}
```

### 2. PathHelper 유틸리티 (새 파일)
```dart
// lib/utils/path_helper.dart

class PathHelper {
  // 기본 다운로드 경로
  static String getDefaultDownloadPath();
  
  // 거래처별 폴더 경로
  static String getClientFolderPath({
    required String basePath,
    required String clientName,
    required int year,
  });
  
  // 전체 파일 경로 생성
  static String getFilePath({
    required String basePath,
    required String clientName,
    required int year,
    required int month,
    required String fileType, // 'csv', 'pdf_register', 'pdf_payslip'
    String? workerName,
    bool useClientSubfolders,
  });
  
  // 폴더 자동 생성
  static Future<Directory> ensureDirectoryExists(String path);
  
  // 파일명 정리
  static String _sanitizeFileName(String fileName);
}
```

### 3. FileEmailService 업데이트
```dart
static Future<File> exportPayrollCsv({
  required String clientName,
  required int year,
  required int month,
  required List<SalaryResult> results,
  String? customBasePath,              // ✨ NEW!
  bool useClientSubfolders = true,     // ✨ NEW!
}) async {
  if (customBasePath != null && customBasePath.isNotEmpty) {
    // 설정된 경로 사용 → 자동 저장
    final filePath = PathHelper.getFilePath(...);
    await PathHelper.ensureDirectoryExists(directory.path);
  } else {
    // 경로 없음 → 파일 선택 창
    final outputPath = await FilePicker.platform.saveFile(...);
  }
}
```

---

## 📊 사용 예시

### 예시 1: 경로 설정 없이 (기존 방식)
```dart
await FileEmailService.exportPayrollCsv(
  clientName: '삼성전자',
  year: 2025,
  month: 1,
  results: results,
);
// → 파일 선택 창이 뜸 (매번 선택)
```

### 예시 2: 경로 설정 후 (자동 저장)
```dart
await FileEmailService.exportPayrollCsv(
  clientName: '삼성전자',
  year: 2025,
  month: 1,
  results: results,
  customBasePath: 'C:\\Documents\\급여관리프로그램',
  useClientSubfolders: true,
);
// → 자동 저장: C:\Documents\급여관리프로그램\삼성전자\2025\삼성전자_2025년01월_급여대장.csv
// → 탐색기 자동 열림
```

---

## 🎯 다음 단계 (TODO)

### 1. 설정 UI 추가 ⏳
```dart
// 설정 화면에 추가 필요:
- 기본 다운로드 경로 입력 필드
- 폴더 선택 버튼 (FolderPicker)
- 거래처별 하위 폴더 사용 체크박스
- 경로 초기화 버튼
```

### 2. 나머지 export 함수 업데이트 ⏳
```dart
// 업데이트 필요:
- exportPayrollRegisterPdf()  // PDF 급여대장
- generatePayslipPdf()         // PDF 급여명세서
- generateAllPdfs()            // 일괄 PDF 생성
- generateExcelTemplate()      // Excel 템플릿
```

### 3. AppProvider 연동 ⏳
```dart
// app_provider.dart에서:
- settings.downloadBasePath 읽어오기
- export 함수 호출 시 경로 전달
```

### 4. 로컬 저장소 연동 ⏳
```dart
// shared_preferences 사용:
- downloadBasePath 저장/불러오기
- useClientSubfolders 저장/불러오기
```

---

## ✅ 완료된 작업

- [x] AppSettings 모델에 downloadBasePath, useClientSubfolders 추가
- [x] PathHelper 유틸리티 생성 (경로 관리)
- [x] exportPayrollCsv() 함수에 경로 설정 지원
- [x] 폴더 자동 생성 기능
- [x] 파일명 자동 생성 및 정리
- [x] 크로스 플랫폼 지원 (Windows/macOS/Linux)

---

## 🔗 Git 정보

**Commit**: `86e440f`  
**Branch**: `genspark_ai_developer`  
**Pull Request**: https://github.com/Durantax/payroll/pull/1 ✅

---

## 💡 핵심 요약

**기본 경로 설정 기능 추가 완료!**

1. ✅ **설정 가능**: `C:\Documents\급여관리프로그램`
2. ✅ **자동 폴더 생성**: `거래처명/연도/`
3. ✅ **파일명 자동 생성**: `거래처_연도월_종류.확장자`
4. ⏳ **UI 추가 필요**: 설정 화면에서 경로 선택

**다음**: 설정 UI 만들고, 나머지 export 함수 업데이트! 🚀
