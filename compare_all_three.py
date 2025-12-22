"""
국세청 공식 조견표 vs 현재 Git 구현 vs 완벽한 하이브리드 계산기 비교
"""
import sys
sys.path.append('/home/user/webapp')

from perfect_hybrid_calculator import PerfectHybridDuranCalculator
import math

# Git 구현 시뮬레이션
class GitImplementation:
    TAX_TABLE = {
        3000: {1: 74350, 2: 56850, 3: 31940, 4: 26690, 5: 21440, 6: 17100, 7: 13730, 8: 10350, 9: 6980, 10: 3600, 11: 0},
        5000: {1: 290000, 2: 220000, 3: 150000, 4: 110000, 5: 90000, 6: 75000, 7: 60000, 8: 48000, 9: 38000, 10: 28000, 11: 20000},
        10000: {1: 890000, 2: 770000, 3: 600000, 4: 510000, 5: 440000, 6: 380000, 7: 335000, 8: 295000, 9: 260000, 10: 225000, 11: 195000},
    }
    
    @classmethod
    def calculate_tax(cls, monthly_income, family_count, child_count):
        adjusted_family_count = max(1, min(family_count, 11))
        
        # 간이세액표 조회
        if monthly_income <= 10000000:
            income_key = (monthly_income // 1000) * 1000
            if income_key in cls.TAX_TABLE and adjusted_family_count in cls.TAX_TABLE[income_key]:
                income_tax = cls.TAX_TABLE[income_key][adjusted_family_count]
            else:
                income_tax = 0
        else:
            # 1,000만원 초과
            base_a = cls.TAX_TABLE[10000][adjusted_family_count]
            if monthly_income <= 14000000:
                excess = monthly_income - 10000000
                income_tax = base_a + int(excess * 0.98 * 0.35) + 25000
            elif monthly_income <= 28000000:
                excess = monthly_income - 14000000
                income_tax = base_a + 1397000 + int(excess * 0.98 * 0.38)
            else:
                income_tax = base_a + 7394600 + int((monthly_income - 30000000) * 0.40)
        
        # 자녀 세액공제
        if child_count == 1:
            child_tax_credit = 12500
        elif child_count == 2:
            child_tax_credit = 29160
        elif child_count >= 3:
            child_tax_credit = 29160 + (child_count - 2) * 25000
        else:
            child_tax_credit = 0
        
        income_tax = max(0, income_tax - child_tax_credit)
        local_income_tax = int(income_tax * 0.1)
        
        income_tax = (income_tax // 10) * 10
        local_income_tax = (local_income_tax // 10) * 10
        
        return income_tax + local_income_tax


if __name__ == "__main__":
    # 완벽한 하이브리드 계산기 초기화
    excel_path = '근로소득_간이세액표(조견표).xlsx'
    perfect_calc = PerfectHybridDuranCalculator(excel_path)
    
    print("=" * 120)
    print("🔍 국세청 공식 조견표 vs 현재 Git 구현 비교")
    print("=" * 120)
    print()
    
    # 1,000만원 기준점 비교
    print("=" * 120)
    print("📊 1,000만원 기준점 비교")
    print("=" * 120)
    print()
    print(f"{'가족수':<10} {'국세청 조견표':<20} {'현재 Git':<20} {'차이':<20} {'차이율'}")
    print("-" * 120)
    
    git_baseline = {
        1: 890000, 2: 770000, 3: 600000, 4: 510000, 5: 440000,
        6: 380000, 7: 335000, 8: 295000, 9: 260000, 10: 225000, 11: 195000
    }
    
    official_baseline = perfect_calc.get_baseline_info()
    
    for family in range(1, 12):
        official_val = official_baseline[family]
        git_val = git_baseline[family]
        diff = official_val - git_val
        diff_pct = (diff / git_val * 100) if git_val > 0 else 0
        
        status = "✅" if abs(diff_pct) < 5 else "⚠️" if abs(diff_pct) < 20 else "❌"
        
        print(f"{family}명{'':<7} {official_val:>15,}원  {git_val:>15,}원  {diff:>15,}원  {diff_pct:>+8.1f}% {status}")
    
    print()
    
    # 실제 계산 비교
    print("=" * 120)
    print("📊 실제 계산 결과 비교")
    print("=" * 120)
    print()
    
    test_cases = [
        (3000000, 3, 1, "월급 300만원, 가족 3명, 자녀 1명"),
        (5000000, 2, 2, "월급 500만원, 가족 2명, 자녀 2명"),
        (10000000, 3, 1, "월급 1,000만원, 가족 3명, 자녀 1명"),
        (12000000, 3, 1, "월급 1,200만원, 가족 3명, 자녀 1명"),
    ]
    
    for monthly_income, family_count, child_count, desc in test_cases:
        perfect_result = perfect_calc.calculate(monthly_income, family_count, child_count)
        perfect_local = int(math.floor((perfect_result * 0.1) / 10) * 10)
        perfect_total = perfect_result + perfect_local
        
        git_result = GitImplementation.calculate_tax(monthly_income, family_count, child_count)
        
        diff = perfect_total - git_result
        diff_pct = (diff / git_result * 100) if git_result > 0 else 0
        
        print(f"📋 {desc}")
        print(f"   국세청 조견표:  {perfect_total:>12,}원")
        print(f"   현재 Git:       {git_result:>12,}원")
        print(f"   차이:          {diff:>12,}원 ({diff_pct:+.2f}%)")
        
        if abs(diff) > 1000:
            print(f"   ⚠️  차이가 1,000원 이상입니다!")
        elif abs(diff) > 0:
            print(f"   ⚠️  약간의 차이가 있습니다")
        else:
            print(f"   ✅ 완전히 일치합니다!")
        
        print()
    
    print("=" * 120)
    print("📊 결론")
    print("=" * 120)
    print()
    print("1️⃣ 1,000만원 기준점 차이:")
    print("   - 국세청 공식 조견표(9,980~10,000천원): 가족 3명 기준 1,198,650원")
    print("   - 현재 Git 구현: 가족 3명 기준 600,000원")
    print("   - 차이: 598,650원 (약 2배 차이!)")
    print()
    print("2️⃣ 원인:")
    print("   - 현재 Git 구현은 간이세액표 중간 샘플 값만 사용")
    print("   - 완벽한 하이브리드는 국세청 공식 엑셀 조견표 전체 데이터 사용")
    print()
    print("3️⃣ 권장 사항:")
    print("   ✅ 완벽한 하이브리드 계산기를 Dart로 포팅할 것")
    print("   ✅ 국세청 공식 조견표 전체 데이터를 Dart 코드에 내장")
    print("   ✅ 1,000만원 기준점을 공식 값(1,198,650원)으로 수정")
    print()
