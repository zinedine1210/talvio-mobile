import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class ReportApi {
  ReportApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> getAttendanceSummary({
    required String dateFrom,
    required String dateTo,
    int? employeeId,
  }) async {
    final res = await _dio.get('/reports/attendance-summary', queryParameters: {
      'date_from': dateFrom,
      'date_to': dateTo,
      if (employeeId != null) 'employee_id': employeeId,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLeaveSummary({
    required int year,
    int? employeeId,
  }) async {
    final res = await _dio.get('/reports/leave-summary', queryParameters: {
      'year': year,
      if (employeeId != null) 'employee_id': employeeId,
    });
    return res.data as Map<String, dynamic>;
  }

  /// Downloads the pdf/xlsx export and saves it to a temp file — the app
  /// doesn't have a file-viewer/share package installed, so this hands
  /// back a path for the caller to surface to the user (e.g. "saved to
  /// ..."), not an in-app preview.
  Future<File> exportAttendanceSummary({
    required String dateFrom,
    required String dateTo,
    int? employeeId,
    required String format,
  }) {
    return _download('/reports/attendance-summary', {
      'date_from': dateFrom,
      'date_to': dateTo,
      'format': format,
      if (employeeId != null) 'employee_id': employeeId,
    }, 'attendance-summary.$format');
  }

  Future<File> exportLeaveSummary({
    required int year,
    int? employeeId,
    required String format,
  }) {
    return _download('/reports/leave-summary', {
      'year': year,
      'format': format,
      if (employeeId != null) 'employee_id': employeeId,
    }, 'leave-summary.$format');
  }

  Future<File> _download(
      String path, Map<String, dynamic> query, String filename) async {
    final res = await _dio.get<List<int>>(
      path,
      queryParameters: query,
      options: Options(responseType: ResponseType.bytes),
    );
    final file = File('${Directory.systemTemp.path}/$filename');
    await file.writeAsBytes(Uint8List.fromList(res.data!), flush: true);
    return file;
  }
}
