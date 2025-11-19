import 'dart:math';

// 백테스트 summary 데이터를 받아 분석 결과(점수 + 텍스트) 생성
Map<String, dynamic> generateScoreAndAnalysis(Map<String, dynamic> summary) {
  final annualReturn = summary['annualReturn'] ?? 0.0;
  final totalReturn = summary['totalReturn'] ?? 0.0;
  final mdd = (summary['mdd'] ?? 0.0).abs() * 100; // %
  final sharpe = summary['sharpe'] ?? 0.0;

  // ---------------- S&P500 기준값 ----------------
  const spAnnual = 0.10; // 10%
  const spMdd = 13.9;    // -13.9% 절댓값 기준
  const spSharpe = 1.2;  // Sharpe

  // ---------------- 수익성 (0~30점)
  double profitScore = (annualReturn * 200).clamp(0, 30).toDouble();
  if (annualReturn > 0.15) profitScore = 30;

  // ---------------- 리스크 관리 (0~35점)
  double riskScore = (35 - 0.9 * mdd).clamp(5, 35).toDouble();

  // ---------------- 효율성 (0~35점)
  double effScore;
  if (sharpe >= 1.5)
    effScore = 35;
  else if (sharpe >= 1.0)
    effScore = (25 + (sharpe - 1.0) * 20).toDouble();
  else if (sharpe >= 0.5)
    effScore = (15 + (sharpe - 0.5) * 20).toDouble();
  else
    effScore = max(5.0, sharpe * 10);

  // ---------------- 총점 + 등급 ----------------
  final total = profitScore + riskScore + effScore;
  final totalScaled = (total / 100 * (30 + 35 + 35)).clamp(0, 100);

  String grade;
  if (totalScaled >= 85)
    grade = 'A';
  else if (totalScaled >= 70)
    grade = 'B';
  else if (totalScaled >= 55)
    grade = 'C';
  else
    grade = 'D';

  // ---------------- 비교 계산 ----------------
  final returnDiff = ((annualReturn - spAnnual) * 100);
  final mddDiff = (mdd - spMdd); // 절댓값 기준
  final sharpeDiff = (sharpe - spSharpe);

  final returnTrend =
      returnDiff >= 0 ? "높은" : "낮은";
  final riskTrend =
      mddDiff <= 0 ? "낮은" : "높은";
  final sharpeTrend =
      sharpeDiff >= 0 ? "우수한" : "낮은";

  // ---------------- 텍스트 생성 ----------------

  // ✅ 수익성
  String profitText =
      "연평균 수익률 ${(annualReturn * 100).toStringAsFixed(1)}%로, "
      "S&P500 평균(${(spAnnual * 100).toStringAsFixed(1)}%)에 비해 "
      "${returnDiff.abs().toStringAsFixed(1)}% ${returnTrend} 수익률입니다. "
      "총 누적 수익률은 +${(totalReturn * 100).toStringAsFixed(1)}%로 평가됩니다.";

  // ✅ 리스크
  String riskText =
      "최대 낙폭(MDD)은 ${mdd.toStringAsFixed(1)}%로, "
      "S&P500 평균 하락폭(${spMdd.toStringAsFixed(1)}%) 대비 "
      "${mddDiff.abs().toStringAsFixed(1)}% ${riskTrend} 리스크를 보입니다.";

  // ✅ 위험 대비 효율
  String sharpeText =
      "샤프 비율은 ${sharpe.toStringAsFixed(2)}로, "
      "S&P500 평균(${spSharpe.toStringAsFixed(2)}) 대비 "
      "${sharpeDiff.abs().toStringAsFixed(2)} ${sharpeTrend} 위험 대비 수익 효율을 나타냅니다.";

  return {
    "score": {
      "total": totalScaled.round(),
      "grade": grade,
      "profit": profitScore.round(),
      "risk": riskScore.round(),
      "efficiency": effScore.round()
    },
    "analysis": {
      "profitability": profitText,
      "risk": riskText,
      "riskEfficiency": sharpeText
    },
    "spBenchmark": {
      "annualReturn": spAnnual,
      "mdd": spMdd,
      "sharpe": spSharpe
    }
  };
}
