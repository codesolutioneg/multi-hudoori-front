import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class ApiConnectionHelp {
  ApiConnectionHelp._();

  static String connectionError(String apiBaseUrl) {
    final isLocalhost = apiBaseUrl.contains('localhost') || apiBaseUrl.contains('127.0.0.1');

    if (kIsWeb && isLocalhost) {
      return 'Cannot reach the API at $apiBaseUrl.\n\n'
          'Start the backend on your PC:\n'
          '  cd biotime_all_apps/biotime_backend\n'
          '  npm run dev\n\n'
          'Then refresh this page (Ctrl+Shift+R).';
    }

    return 'Cannot reach the API at $apiBaseUrl.\n\n'
        'On your PC:\n'
        '  cd biotime_backend\n'
        '  npm run dev\n\n'
        'For testers on another network use ngrok:\n'
        '  ngrok http 3000';
  }
}
