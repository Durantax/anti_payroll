import pandas as pd
import math

class PerfectHybridDuranCalculator:
    """
    세무회계 두란(010-7704-1536) 전용 근로소득 간이세액 완벽한 하이브리드 계산기
    
    ✅ 1,000만 원 이하: 국세청 공식 조견표(엑셀) 정확히 매칭
    ✅ 1,000만 원 초과: 법정 산식 적용 (33페이지)
    ✅ 자녀 세액공제 반영 (8~20세)
    ✅ 11명 초과 가족 공제 반영
    
    업데이트: 2024년 국세청 공식 간이세액표 기준
    """

    def __init__(self, excel_file_path):
        """
        Args:
            excel_file_path: 국세청 공식 근로소득_간이세액표(조견표).xlsx 파일 경로
        """
        self.df = self._load_official_table(excel_file_path)
        
        # 1,000만원 기준점 값 (조견표 마지막 행: 9,980~10,000천원 구간)
        self.tax_at_10m = self._extract_10m_baseline()

    def _load_official_table(self, file_path):
        """국세청 공식 조견표 로드 및 정제"""
        # 상단 헤더 5줄 건너뛰고 로드
        df = pd.read_excel(file_path, skiprows=5, header=None)
        
        # 컬럼명 설정: 0=이상(천원), 1=미만(천원), 2~12=가족 1~11명
        cols = ['low', 'high'] + [str(i) for i in range(1, 12)]
        df.columns = cols
        
        # 숫자 변환
        for col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce')
        
        # NaN 행 제거
        df = df.dropna(subset=['low', 'high'])
        
        return df

    def _extract_10m_baseline(self):
        """
        조견표에서 1,000만원 기준점 값 추출
        실제 조견표는 9,980~10,000천원 구간까지만 있으므로 마지막 행 사용
        """
        last_row = self.df.iloc[-1]
        
        baseline = {}
        for i in range(1, 12):
            val = last_row[str(i)]
            baseline[i] = int(val) if pd.notna(val) else 0
        
        return baseline

    def _lookup_table(self, monthly_income, family_count):
        """
        1,000만 원 이하: 조견표에서 정확한 세액 조회
        
        Args:
            monthly_income: 월 급여액 (원 단위)
            family_count: 공제대상 가족 수
            
        Returns:
            int: 원천징수 세액 (원)
        """
        income_thousand = monthly_income / 1000  # 천원 단위 변환
        
        # 조견표에서 구간 찾기: low <= 급여 < high
        match = self.df[(self.df['low'] <= income_thousand) & 
                        (income_thousand < self.df['high'])]
        
        if match.empty:
            # 구간을 벗어난 경우 (1,000만원 상한선)
            return self.tax_at_10m.get(min(family_count, 11), 0)
        
        # 가족 수 컬럼 선택 (최대 11명)
        family_col = str(min(family_count, 11))
        base_tax = match.iloc[0][family_col]
        
        if pd.isna(base_tax):
            base_tax = 0
        
        base_tax = int(base_tax)
        
        # 11명 초과 가족 공제 처리
        if family_count > 11:
            tax_11 = int(match.iloc[0]['11']) if pd.notna(match.iloc[0]['11']) else 0
            tax_10 = int(match.iloc[0]['10']) if pd.notna(match.iloc[0]['10']) else 0
            extra_count = family_count - 11
            base_tax = tax_11 - ((tax_10 - tax_11) * extra_count)
        
        return max(0, base_tax)

    def _calculate_high_income(self, monthly_income, family_count):
        """
        1,000만 원 초과: PDF 33페이지 법정 산식 적용
        
        규정:
        - A = 1,000만원 기준점 세액
        - 1,400만원 이하: A + (초과액 × 98% × 35%) + 25,000원
        - 2,800만원 이하: A + 1,397,000원 + (초과액 × 98% × 38%)
        - 3,000만원 이하: A + 6,610,600원 + (초과액 × 98% × 40%)
        - 4,500만원 이하: A + 7,394,600원 + (초과액 × 40%)
        - 8,700만원 이하: A + 13,394,600원 + (초과액 × 42%)
        - 8,700만원 초과: A + 31,034,600원 + (초과액 × 45%)
        
        Args:
            monthly_income: 월 급여액 (원 단위)
            family_count: 공제대상 가족 수
            
        Returns:
            float: 원천징수 세액 (원)
        """
        eff_family = min(family_count, 11)
        tax_10m = self.tax_at_10m.get(eff_family, 958650)  # 기본값: 11명 기준
        
        if monthly_income <= 14000000:
            # 1,400만원 이하
            excess = monthly_income - 10000000
            return tax_10m + (excess * 0.98 * 0.35) + 25000
        elif monthly_income <= 28000000:
            # 2,800만원 이하
            excess = monthly_income - 14000000
            return tax_10m + 1397000 + (excess * 0.98 * 0.38)
        elif monthly_income <= 30000000:
            # 3,000만원 이하
            excess = monthly_income - 28000000
            return tax_10m + 6610600 + (excess * 0.98 * 0.40)
        elif monthly_income <= 45000000:
            # 4,500만원 이하
            excess = monthly_income - 30000000
            return tax_10m + 7394600 + (excess * 0.40)
        elif monthly_income <= 87000000:
            # 8,700만원 이하
            excess = monthly_income - 45000000
            return tax_10m + 13394600 + (excess * 0.42)
        else:
            # 8,700만원 초과
            excess = monthly_income - 87000000
            return tax_10m + 31034600 + (excess * 0.45)

    def _get_child_deduction(self, child_count):
        """
        자녀 세액공제 계산 (8~20세 자녀 대상)
        
        규정:
        - 1명: 12,500원
        - 2명: 29,160원
        - 3명 이상: 29,160원 + (2명 초과 1명당 25,000원)
        
        Args:
            child_count: 8~20세 자녀 수
            
        Returns:
            int: 자녀 세액공제액 (원)
        """
        if child_count == 1:
            return 12500
        elif child_count == 2:
            return 29160
        elif child_count >= 3:
            return 29160 + (child_count - 2) * 25000
        return 0

    def calculate(self, monthly_income, family_count=1, child_count=0):
        """
        최종 원천징수 세액 산출
        
        Args:
            monthly_income: 월 급여액 (원 단위, 비과세 제외)
            family_count: 공제대상 가족 수 (본인 포함, 기본값 1명)
            child_count: 8~20세 자녀 수 (기본값 0명)
            
        Returns:
            int: 최종 원천징수 세액 (10원 미만 절사)
        """
        # 1. 기본 세액 결정 (1,000만원 기준 분기)
        if monthly_income <= 10000000:
            # 조견표 조회
            base_tax = self._lookup_table(monthly_income, family_count)
        else:
            # 법정 산식 계산
            base_tax = self._calculate_high_income(monthly_income, family_count)
        
        # 2. 자녀 세액공제 적용
        child_deduction = self._get_child_deduction(child_count)
        final_tax = max(0, base_tax - child_deduction)
        
        # 3. 10원 미만 절사
        return int(math.floor(final_tax / 10) * 10)
    
    def get_baseline_info(self):
        """1,000만원 기준점 값 정보 반환"""
        return self.tax_at_10m.copy()


# ============================================================================
# 실행 테스트 및 비교
# ============================================================================
if __name__ == "__main__":
    excel_path = '근로소득_간이세액표(조견표).xlsx'
    calc = PerfectHybridDuranCalculator(excel_path)
    
    print("=" * 100)
    print("🎯 세무회계 두란 - 완벽한 하이브리드 계산기")
    print("=" * 100)
    print()
    
    # 1,000만원 기준점 값 확인
    print("=" * 100)
    print("📊 국세청 공식 조견표 - 1,000만원 기준점 값 (9,980~10,000천원 구간)")
    print("=" * 100)
    baseline = calc.get_baseline_info()
    for family, tax in baseline.items():
        print(f"가족 {family:2d}명: {tax:>12,}원")
    print()
    
    # 테스트 케이스
    print("=" * 100)
    print("📊 계산 테스트 (국세청 공식 조견표 기반)")
    print("=" * 100)
    print()
    
    test_cases = [
        (2417230, 1, 0, "월급 2,417,230원, 1인 가구"),
        (3000000, 3, 1, "월급 300만원, 가족 3명, 자녀 1명"),
        (3000000, 3, 0, "월급 300만원, 가족 3명, 자녀 0명"),
        (5000000, 2, 2, "월급 500만원, 가족 2명, 자녀 2명"),
        (10000000, 3, 1, "월급 1,000만원, 가족 3명, 자녀 1명"),
        (12000000, 3, 1, "월급 1,200만원, 가족 3명, 자녀 1명"),
        (15000000, 2, 2, "월급 1,500만원, 가족 2명, 자녀 2명"),
        (20000000, 4, 3, "월급 2,000만원, 가족 4명, 자녀 3명"),
    ]
    
    for monthly_income, family_count, child_count, desc in test_cases:
        result = calc.calculate(monthly_income, family_count, child_count)
        
        # 지방소득세 계산 (소득세의 10%)
        local_tax = int(math.floor((result * 0.1) / 10) * 10)
        total = result + local_tax
        
        print(f"📋 {desc}")
        print(f"   소득세:        {result:>12,}원")
        print(f"   지방소득세:    {local_tax:>12,}원 (소득세의 10%)")
        print(f"   합계:          {total:>12,}원")
        print()
    
    print("=" * 100)
    print("✅ 완료: 국세청 공식 조견표 기반 정확한 계산")
    print("=" * 100)
