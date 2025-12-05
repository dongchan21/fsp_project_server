String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
