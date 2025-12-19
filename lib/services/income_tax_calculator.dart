/// 근로소득 간이세액표 계산기
/// 2024년 기준 간이세액표 적용
class IncomeTaxCalculator {
  /// 근로소득 간이세액 계산
  /// 
  /// [monthlyIncome]: 월 총급여액 (비과세 제외)
  /// [familyCount]: 공제대상 가족수 (본인 포함)
  /// 
  /// Returns: [소득세, 지방소득세] (1의 자리 절사)
  static List<int> calculateIncomeTax({
    required int monthlyIncome,
    required int familyCount,
  }) {
    // 공제대상 가족수는 최소 1명 (본인)
    final adjustedFamilyCount = familyCount < 1 ? 1 : familyCount;
    
    // 간이세액표에 따른 소득세 계산
    int incomeTax = _getSimplifiedTax(monthlyIncome, adjustedFamilyCount);
    
    // 지방소득세: 소득세의 10%
    int localIncomeTax = (incomeTax * 0.1).round();
    
    // 1의 자리 절사
    incomeTax = (incomeTax ~/ 10) * 10;
    localIncomeTax = (localIncomeTax ~/ 10) * 10;
    
    return [incomeTax, localIncomeTax];
  }
  
  /// 간이세액표 조회
  /// 실제 간이세액표를 기반으로 계산
  static int _getSimplifiedTax(int monthlyIncome, int familyCount) {
    // 80% 세율 적용 기준 (일반적인 경우)
    
    // 월급여액 구간별 처리
    if (monthlyIncome <= 1060000) {
      return 0; // 106만원 이하: 비과세
    }
    
    // 가족수에 따른 기본 공제 차등 적용
    // 간이세액표를 단순화한 근사 계산식
    
    // 연 급여 환산 (월 × 12)
    final annualIncome = monthlyIncome * 12;
    
    // 과세표준 계산 (근로소득공제 + 인적공제 등)
    int taxBase = _calculateTaxBase(annualIncome, familyCount);
    
    if (taxBase <= 0) return 0;
    
    // 세율 구간별 계산 (누진세율)
    int tax = _calculateProgressiveTax(taxBase);
    
    // 근로소득세액공제 적용
    tax = _applyEarnedIncomeCredit(tax, annualIncome);
    
    // 월 소득세 환산
    return (tax / 12).round();
  }
  
  /// 과세표준 계산
  static int _calculateTaxBase(int annualIncome, int familyCount) {
    // 1. 근로소득공제
    int earnedIncomeDeduction;
    if (annualIncome <= 5000000) {
      earnedIncomeDeduction = (annualIncome * 0.7).round();
    } else if (annualIncome <= 15000000) {
      earnedIncomeDeduction = 3500000 + ((annualIncome - 5000000) * 0.4).round();
    } else if (annualIncome <= 45000000) {
      earnedIncomeDeduction = 7500000 + ((annualIncome - 15000000) * 0.15).round();
    } else if (annualIncome <= 100000000) {
      earnedIncomeDeduction = 12000000 + ((annualIncome - 45000000) * 0.05).round();
    } else {
      earnedIncomeDeduction = 14750000 + ((annualIncome - 100000000) * 0.02).round();
      if (earnedIncomeDeduction > 20000000) {
        earnedIncomeDeduction = 20000000; // 최대 2천만원
      }
    }
    
    final incomeAfterDeduction = annualIncome - earnedIncomeDeduction;
    
    // 2. 인적공제 (본인 + 가족)
    final personalDeduction = familyCount * 1500000; // 1인당 150만원
    
    // 3. 특별소득공제 추정 (간이세액표 기준)
    int specialDeduction = 0;
    if (annualIncome <= 30000000) {
      if (familyCount == 1) {
        specialDeduction = 3100000 + (annualIncome * 0.04).round();
      } else if (familyCount == 2) {
        specialDeduction = 3600000 + (annualIncome * 0.04).round();
      } else {
        specialDeduction = 5000000 + (annualIncome * 0.07).round();
      }
    } else if (annualIncome <= 45000000) {
      if (familyCount == 1) {
        specialDeduction = 3100000 + (annualIncome * 0.04).round() - 
                          ((annualIncome - 30000000) * 0.05).round();
      } else if (familyCount == 2) {
        specialDeduction = 3600000 + (annualIncome * 0.04).round() - 
                          ((annualIncome - 30000000) * 0.05).round();
      } else {
        specialDeduction = 5000000 + (annualIncome * 0.07).round() - 
                          ((annualIncome - 30000000) * 0.05).round();
      }
    } else if (annualIncome <= 70000000) {
      if (familyCount == 1) {
        specialDeduction = 3100000 + (annualIncome * 0.015).round();
      } else if (familyCount == 2) {
        specialDeduction = 3600000 + (annualIncome * 0.02).round();
      } else {
        specialDeduction = 5000000 + (annualIncome * 0.05).round() + 
                          ((annualIncome - 40000000) * 0.04).round();
      }
    } else if (annualIncome <= 120000000) {
      if (familyCount == 1) {
        specialDeduction = 3100000 + (annualIncome * 0.005).round();
      } else if (familyCount == 2) {
        specialDeduction = 3600000 + (annualIncome * 0.01).round();
      } else {
        specialDeduction = 5000000 + (annualIncome * 0.03).round();
      }
    } else {
      if (familyCount == 1) {
        specialDeduction = 3100000 + (annualIncome * 0.005).round();
      } else if (familyCount == 2) {
        specialDeduction = 3600000 + (annualIncome * 0.01).round();
      } else {
        specialDeduction = 5000000 + (annualIncome * 0.03).round();
      }
    }
    
    // 과세표준 = 근로소득금액 - 인적공제 - 특별소득공제
    int taxBase = incomeAfterDeduction - personalDeduction - specialDeduction;
    
    return taxBase > 0 ? taxBase : 0;
  }
  
  /// 누진세율 계산
  static int _calculateProgressiveTax(int taxBase) {
    int tax = 0;
    
    if (taxBase <= 14000000) {
      // 1,400만원 이하: 6%
      tax = (taxBase * 0.06).round();
    } else if (taxBase <= 50000000) {
      // 5,000만원 이하: 840,000원 + 초과분의 15%
      tax = 840000 + ((taxBase - 14000000) * 0.15).round();
    } else if (taxBase <= 88000000) {
      // 8,800만원 이하: 6,240,000원 + 초과분의 24%
      tax = 6240000 + ((taxBase - 50000000) * 0.24).round();
    } else if (taxBase <= 150000000) {
      // 1억 5천만원 이하: 15,360,000원 + 초과분의 35%
      tax = 15360000 + ((taxBase - 88000000) * 0.35).round();
    } else if (taxBase <= 300000000) {
      // 3억원 이하: 37,060,000원 + 초과분의 38%
      tax = 37060000 + ((taxBase - 150000000) * 0.38).round();
    } else if (taxBase <= 500000000) {
      // 5억원 이하: 94,060,000원 + 초과분의 40%
      tax = 94060000 + ((taxBase - 300000000) * 0.40).round();
    } else if (taxBase <= 1000000000) {
      // 10억원 이하: 174,060,000원 + 초과분의 42%
      tax = 174060000 + ((taxBase - 500000000) * 0.42).round();
    } else {
      // 10억원 초과: 384,060,000원 + 초과분의 45%
      tax = 384060000 + ((taxBase - 1000000000) * 0.45).round();
    }
    
    return tax;
  }
  
  /// 근로소득세액공제 적용
  static int _applyEarnedIncomeCredit(int tax, int annualIncome) {
    if (tax <= 1300000) {
      // 130만원 이하: 산출세액의 55% 공제
      final credit = (tax * 0.55).round();
      return tax - credit;
    } else {
      // 130만원 초과: 715,000원 + (산출세액 - 130만원)의 30% 공제
      final credit = 715000 + ((tax - 1300000) * 0.30).round();
      
      // 공제 한도 체크
      int maxCredit;
      if (annualIncome <= 33000000) {
        maxCredit = 740000;
      } else if (annualIncome <= 70000000) {
        maxCredit = 740000 - ((annualIncome - 33000000) * 0.008).round();
        if (maxCredit < 660000) maxCredit = 660000;
      } else {
        maxCredit = 660000 - ((annualIncome - 70000000) * 0.005).round();
        if (maxCredit < 500000) maxCredit = 500000;
      }
      
      final actualCredit = credit > maxCredit ? maxCredit : credit;
      return tax - actualCredit;
    }
  }
}
