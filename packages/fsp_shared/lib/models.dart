library fsp_shared.models;

import 'dart:convert';

class BacktestRequest {
  final List<String> symbols;
  final List<double> weights;
  final DateTime startDate;
  final DateTime endDate;
  final double initialCapital;
  final double dcaAmount;

  BacktestRequest({
    required this.symbols,
    required this.weights,
    required this.startDate,
    required this.endDate,
    required this.initialCapital,
    required this.dcaAmount,
  });

  factory BacktestRequest.fromJson(Map<String, dynamic> json) => BacktestRequest(
        symbols: List<String>.from(json['symbols'] ?? const []),
        weights: (json['weights'] as List).map((e) => (e as num).toDouble()).toList(),
        startDate: DateTime.parse(json['startDate']),
        endDate: DateTime.parse(json['endDate']),
        initialCapital: (json['initialCapital'] as num).toDouble(),
        dcaAmount: (json['dcaAmount'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'symbols': symbols,
        'weights': weights,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'initialCapital': initialCapital,
        'dcaAmount': dcaAmount,
      };

  @override
  String toString() => jsonEncode(toJson());
}

class BacktestJobStatus {
  final String jobId;
  final String status; // queued|running|succeeded|failed
  final double? progress; // 0..1
  final Map<String, dynamic>? result;
  final String? error;

  BacktestJobStatus({
    required this.jobId,
    required this.status,
    this.progress,
    this.result,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'status': status,
        if (progress != null) 'progress': progress,
        if (result != null) 'result': result,
        if (error != null) 'error': error,
      };
}

class PriceQuote {
  final int? id;
  final String symbol;
  final DateTime date; // trading date
  final double close; // close price

  PriceQuote({this.id, required this.symbol, required this.date, required this.close});

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'symbol': symbol,
        'date': date.toIso8601String(),
        'close': close,
      };

  factory PriceQuote.fromJson(Map<String, dynamic> json) => PriceQuote(
        id: json['id'] as int?,
        symbol: json['symbol'] as String,
        date: DateTime.parse(json['date'] as String),
        close: (json['close'] as num).toDouble(),
      );
}

class ExchangeRate {
  final int? id;
  final DateTime date;
  final double rate; // e.g. USD->KRW

  ExchangeRate({this.id, required this.date, required this.rate});

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'date': date.toIso8601String(),
        'rate': rate,
      };

  factory ExchangeRate.fromJson(Map<String, dynamic> json) => ExchangeRate(
        id: json['id'] as int?,
        date: DateTime.parse(json['date'] as String),
        rate: (json['rate'] as num).toDouble(),
      );
}
