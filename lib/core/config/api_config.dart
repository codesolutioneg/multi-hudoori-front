import '../../l10n/l10n_extension.dart';

class ApiConfig {
  /// Bump when shipping to GitHub Pages (shown in Settings for cache verification).
  static const appVersion = '1.0.8+69';

  /// Odoo push UI (Settings form, test/push buttons). Backend routes remain available.
  static const showOdooUi = true;

  /// BioTime fingerprint device picker on employee forms — hidden from HR UI.
  static const showBiotimeDeviceUi = false;

  /// Fingerprint devices in HR Settings (location assignment per device).
  static const showDevicesInSettings = true;

  /// Local Node backend (hudoori-multi `npm run dev` on 3003).
  static const localBackendUrl = 'http://localhost:3003';

  /// Multi API domain — never single-company Hudoori APIs.
  static const productionBackendUrl = 'https://hr-api.hudoori.code-solution.org';

  /// Multi frontend host: hr.hudoori.code-solution.org
  static const productionFrontendUrl = 'https://hr.hudoori.code-solution.org';

  /// Direct local API only — do not bind Multi to single-company ports 3001/3002.
  static const vpsBackendUrl = 'http://127.0.0.1:3003';

  static const baseUrl = String.fromEnvironment(
    'BIOTIME_API_URL',
    defaultValue: productionBackendUrl,
  );

  /// When true, `flutter run` on localhost uses [localBackendUrl] (not production).
  /// GitHub Actions sets BIOTIME_PIN_LOCALHOST=false for deployed web.
  static const pinLocalhost = bool.fromEnvironment(
    'BIOTIME_PIN_LOCALHOST',
    defaultValue: true,
  );

  static const database = String.fromEnvironment(
    'BIOTIME_DB',
    defaultValue: '',
  );

  /// `prod` | `dev` — set via `--dart-define=BIOTIME_APP_ENV=dev` on the DEV build.
  static const appEnv = String.fromEnvironment(
    'BIOTIME_APP_ENV',
    defaultValue: 'prod',
  );

  static bool get isDevEnv => appEnv == 'dev';

  /// Browser tab / window title (marks DEV builds clearly).
  static String get documentTitle {
    return tr(isDevEnv ? 'app.titleDev' : 'app.title');
  }
}
