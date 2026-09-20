import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Translates an API error (or a raw exception) into a localized,
/// user-facing message. Backend errors are `{"code": "...", "message": "..."}`
/// — `code` is looked up against known translations; an unrecognized code
/// (including the backend's catch-all `INTERNAL_ERROR`) falls back to a
/// generic localized message, NEVER the backend's raw English `message` —
/// that text is for logs/debugging, not something an end user should see.
String translateError(BuildContext context, Object error) {
  final t = AppLocalizations.of(context)!;
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final translated = _translateCode(t, data['code']?.toString());
      if (translated != null) return translated;
    }
    if (error.response == null) return t.errorNetworkUnreachable;
  }
  return t.errorGeneric;
}

String? _translateCode(AppLocalizations t, String? code) {
  switch (code) {
    case 'VALIDATION_ERROR':
      return t.errorValidation;
    case 'PASSWORD_TOO_SHORT':
      return t.errorPasswordTooShort;
    case 'EMAIL_TAKEN':
      return t.errorEmailTaken;
    case 'INVALID_CREDENTIALS':
      return t.errorInvalidCredentials;
    case 'ACCOUNT_INACTIVE':
      return t.errorAccountInactive;
    case 'INVALID_REFRESH_TOKEN':
      return t.errorInvalidRefreshToken;
    case 'UNAUTHORIZED':
      return t.errorUnauthorized;
    case 'FORBIDDEN':
      return t.errorForbidden;
    case 'MISSING_SIGNATURE':
      return t.errorMissingSignature;
    case 'INVALID_SIGNATURE':
      return t.errorInvalidSignature;
    case 'SIGNATURE_EXPIRED':
      return t.errorSignatureExpired;
    case 'RATE_LIMITED':
      return t.errorRateLimited;
    case 'COMPANY_NOT_FOUND':
      return t.errorCompanyNotFound;
    case 'LOCATION_NOT_FOUND':
      return t.errorLocationNotFound;
    case 'DEPARTMENT_NOT_FOUND':
      return t.errorDepartmentNotFound;
    case 'EMPLOYEE_NOT_FOUND':
      return t.errorEmployeeNotFound;
    case 'INVALID_DEPARTMENT_REFERENCE':
      return t.errorInvalidDepartmentReference;
    case 'INVALID_SUPERVISOR_REFERENCE':
      return t.errorInvalidSupervisorReference;
    case 'INVALID_DATE_FORMAT':
      return t.errorInvalidDateFormat;
    case 'INTERNAL_ERROR':
      return t.errorGeneric;
    default:
      return null;
  }
}
