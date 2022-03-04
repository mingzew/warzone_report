import 'package:flutter/material.dart';

void showInSnackBar(GlobalKey<ScaffoldState> scaffoldKey, String message) {
  // ignore: deprecated_member_use
  scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
}