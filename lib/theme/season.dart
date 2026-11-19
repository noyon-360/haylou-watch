import 'package:flutter/material.dart';

/// The six seasons (ষড়ঋতু) of Bangladesh, each two Bengali months long.
enum Season {
  grishma('Grishma', 'গ্রীষ্ম', 'Summer', 'বৈশাখ – জ্যৈষ্ঠ', 'Boishakh – Joishtho', Icons.wb_sunny_outlined),
  barsha('Barsha', 'বর্ষা', 'Monsoon', 'আষাঢ় – শ্রাবণ', 'Asharh – Srabon', Icons.water_drop_outlined),
  sharat('Sharat', 'শরৎ', 'Early autumn', 'ভাদ্র – আশ্বিন', 'Bhadro – Ashwin', Icons.cloud_outlined),
  hemanta('Hemanta', 'হেমন্ত', 'Late autumn', 'কার্তিক – অগ্রহায়ণ', 'Kartik – Ogrohayon', Icons.grass_rounded),
  sheet('Sheet', 'শীত', 'Winter', 'পৌষ – মাঘ', 'Poush – Magh', Icons.ac_unit_rounded),
  basanta('Basanta', 'বসন্ত', 'Spring', 'ফাল্গুন – চৈত্র', 'Falgun – Choitro', Icons.local_florist_outlined);

  const Season(this.en, this.bn, this.english, this.monthsBn, this.monthsEn, this.icon);

  final String en;
  final String bn;
  final String english;
  final String monthsBn;
  final String monthsEn;
  final IconData icon;

  Season get next => Season.values[(index + 1) % Season.values.length];
}

/// Bangladesh's revised Bengali calendar (Bangla Academy, 2019):
/// 1 Boishakh = 14 April; Boishakh–Ashwin have 31 days, Falgun has 29
/// (30 in a Gregorian leap year), all other months 30.
class BengaliCalendar {
  BengaliCalendar._();

  static List<int> _monthLengths(int startYear) {
    // Falgun falls in Feb–Mar of startYear + 1.
    final y = startYear + 1;
    final leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
    return [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, leap ? 30 : 29, 30];
  }

  /// 0 = Boishakh … 11 = Choitro, plus the 0-based day in that month.
  static ({int month, int day, DateTime yearStart}) monthOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    var start = DateTime(d.year, 4, 14);
    if (d.isBefore(start)) start = DateTime(d.year - 1, 4, 14);
    var offset = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    final lengths = _monthLengths(start.year);
    var m = 0;
    while (m < 11 && offset >= lengths[m]) {
      offset -= lengths[m];
      m++;
    }
    return (month: m, day: offset, yearStart: start);
  }

  static Season seasonOf(DateTime date) => Season.values[monthOf(date).month ~/ 2];

  /// First day of the season that follows [date]'s season.
  static DateTime nextSeasonStart(DateTime date) {
    final info = monthOf(date);
    final lengths = _monthLengths(info.yearStart.year);
    final nextMonth = (info.month ~/ 2 + 1) * 2; // 2, 4, … 12
    var days = 0;
    for (var i = 0; i < nextMonth; i++) {
      days += lengths[i];
    }
    final s = info.yearStart;
    return DateTime(s.year, s.month, s.day + days);
  }
}
