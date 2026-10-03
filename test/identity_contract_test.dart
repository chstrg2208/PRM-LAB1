import 'package:flutter_test/flutter_test.dart';

import 'package:birdle/models/attendance_record.dart';
import 'package:birdle/models/student.dart';

void main() {
  group('Identity contract: MEMBER vs CODE', () {
    test('keeps MEMBER canonical when MEMBER and CODE are different', () {
      final student = Student.fromJson({
        'MEMBER': 'an_nv',
        'CODE': 'SE170001',
        'SURNAME': 'Nguyễn',
        'GIVEN NAME': 'An',
      });

      expect(student.member, 'an_nv');
      expect(student.rollNumber, 'an_nv');
      expect(student.code, 'SE170001');
      expect(student.toJson()['member'], 'an_nv');
      expect(student.toJson()['rollNumber'], 'an_nv');
      expect(student.toJson()['code'], 'SE170001');
    });

    test('maps RollNumber and StudentCode to separate fields', () {
      final student = Student.fromJson({
        'ROLLNUMBER': 'AN_NV',
        'STUDENTCODE': 'SE170001',
      });

      expect(student.member, 'AN_NV');
      expect(student.rollNumber, 'AN_NV');
      expect(student.code, 'SE170001');
    });

    test('supports MSSV aliases and CODE-only legacy sheets', () {
      final mssvStudent = Student.fromJson({
        'MSSV': 'SE170002',
        'MÃ SV': 'SE170002',
      });
      final legacyStudent = Student.fromJson({'CODE': 'SE170003'});

      expect(mssvStudent.member, 'SE170002');
      expect(mssvStudent.code, 'SE170002');
      expect(legacyStudent.member, 'SE170003');
      expect(legacyStudent.rollNumber, 'SE170003');
      expect(legacyStudent.code, 'SE170003');
    });
  });

  test('AttendanceRecord reads MEMBER aliases and sends canonical member', () {
    final record = AttendanceRecord.fromJson({
      'MEMBER': 'AN_NV',
      'CODE': 'SE170001',
      'className': 'SE1801',
      'date': '2026-09-22',
      'slot': 1,
      'status': 'absent',
    });

    expect(record.rollNumber, 'AN_NV');
    expect(record.status, AttendanceStatus.absent);
    expect(record.toJson()['rollNumber'], 'AN_NV');
    expect(record.toJson()['member'], 'AN_NV');
  });
}
