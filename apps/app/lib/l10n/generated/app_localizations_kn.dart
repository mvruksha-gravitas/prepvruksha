// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kannada (`kn`).
class AppLocalizationsKn extends AppLocalizations {
  AppLocalizationsKn([String locale = 'kn']) : super(locale);

  @override
  String get appTitle => 'ಪ್ರೆಪ್‌ವೃಕ್ಷ';

  @override
  String get switchLanguage => 'English';

  @override
  String get phoneTitle => 'ನಿಮ್ಮ ಫೋನ್ ಸಂಖ್ಯೆಯೊಂದಿಗೆ ಸೈನ್ ಇನ್ ಮಾಡಿ';

  @override
  String get phoneLabel => 'ಮೊಬೈಲ್ ಸಂಖ್ಯೆ';

  @override
  String get phoneInvalid =>
      'ಮಾನ್ಯವಾದ 10 ಅಂಕಿಯ ಭಾರತೀಯ ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ';

  @override
  String get sendCode => 'ಕೋಡ್ ಕಳುಹಿಸಿ';

  @override
  String get otpTitle => 'ಕೋಡ್ ನಮೂದಿಸಿ';

  @override
  String otpSentTo(String phone) {
    return '$phone ಗೆ 6 ಅಂಕಿಯ ಕೋಡ್ ಕಳುಹಿಸಿದ್ದೇವೆ';
  }

  @override
  String get otpLabel => '6 ಅಂಕಿಯ ಕೋಡ್';

  @override
  String get verify => 'ಪರಿಶೀಲಿಸಿ';

  @override
  String resendIn(int seconds) {
    return '$seconds ಸೆಕೆಂಡುಗಳಲ್ಲಿ ಕೋಡ್ ಮರುಕಳುಹಿಸಬಹುದು';
  }

  @override
  String get resend => 'ಕೋಡ್ ಮರುಕಳುಹಿಸಿ';

  @override
  String get changeNumber => 'ಸಂಖ್ಯೆ ಬದಲಾಯಿಸಿ';

  @override
  String get errorInvalidCode =>
      'ಕೋಡ್ ತಪ್ಪಾಗಿದೆ ಅಥವಾ ಅವಧಿ ಮುಗಿದಿದೆ. ಪರಿಶೀಲಿಸಿ ಅಥವಾ ಹೊಸ ಕೋಡ್ ಪಡೆಯಿರಿ.';

  @override
  String get errorRateLimited =>
      'ಹಲವು ಪ್ರಯತ್ನಗಳಾಗಿವೆ. ಕೆಲವು ನಿಮಿಷಗಳ ನಂತರ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get errorNetwork =>
      'ಸರ್ವರ್ ತಲುಪಲು ಸಾಧ್ಯವಾಗುತ್ತಿಲ್ಲ. ನಿಮ್ಮ ಸಂಪರ್ಕ ಪರಿಶೀಲಿಸಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get errorUnknown => 'ಏನೋ ತಪ್ಪಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get homeWelcome => 'ಸ್ವಾಗತ';

  @override
  String homeSignedInAs(String phone) {
    return '$phone ಆಗಿ ಸೈನ್ ಇನ್ ಆಗಿದ್ದೀರಿ';
  }

  @override
  String get homeProfileIncomplete => 'ಪ್ರಾರಂಭಿಸಲು ನಿಮ್ಮ ಪ್ರೊಫೈಲ್ ಪೂರ್ಣಗೊಳಿಸಿ.';

  @override
  String get signOut => 'ಸೈನ್ ಔಟ್';
}
