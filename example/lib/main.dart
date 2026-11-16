import 'package:flutter/material.dart';
import 'package:wompi_webview_example/app_theme.dart';
import 'package:wompi_webview_example/checkout_setup_page.dart';
import 'package:wompi_webview_example/checkout_view_model.dart';

void main() {
  runApp(const WompiExampleApp());
}

class WompiExampleApp extends StatefulWidget {
  const WompiExampleApp({super.key});

  @override
  State<WompiExampleApp> createState() => _WompiExampleAppState();
}

class _WompiExampleAppState extends State<WompiExampleApp> {
  final CheckoutViewModel _viewModel = CheckoutViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wompi WebView Example',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: CheckoutSetupPage(viewModel: _viewModel),
    );
  }
}
