// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import '../util/locale_manager.dart';
import '../widgets/dialogs.dart';

T Function(dynamic error, dynamic stackTrace) _showErrorToUserFunc<T>(BuildContext context) => (error, stackTrace) {
  if(error == null)
    throw Exception(L(context).futureUtilUnknownError);
  var msg = error.toString();
  showPopupMsg(context, msg);
  throw error;
};

extension FutureUserError<T> on Future<T> {
  Future<T> showErrorToUser(BuildContext context) {
    return onError(_showErrorToUserFunc<Future<T>>(context));
  }
}

extension StreamUserError<T> on Stream<T> {
  Stream<T> showErrorToUser(BuildContext context) {
    return handleError(_showErrorToUserFunc<Stream<T>>(context));
  }
}
