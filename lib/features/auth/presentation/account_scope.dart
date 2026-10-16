import 'package:flutter/material.dart';
import 'package:youwell/application/app_auth_controller.dart';

class AccountScope extends InheritedNotifier<AppAuthController> {
  const AccountScope({
    super.key,
    required AppAuthController auth,
    required super.child,
  }) : super(notifier: auth);
  static AppAuthController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()?.notifier;
}
