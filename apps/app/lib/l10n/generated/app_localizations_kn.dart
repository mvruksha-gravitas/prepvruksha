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
  String get signOut => 'ಸೈನ್ ಔಟ್';

  @override
  String get retry => 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ';

  @override
  String get cancel => 'ರದ್ದುಮಾಡಿ';

  @override
  String get continueButton => 'ಮುಂದುವರಿಯಿರಿ';

  @override
  String get profileTitle => 'ನಿಮ್ಮ ಬಗ್ಗೆ';

  @override
  String get profileIntro =>
      'ನಿಮ್ಮ ತಯಾರಿಯನ್ನು ಸಿದ್ಧಪಡಿಸಲು ಈ ವಿವರಗಳನ್ನು ಬಳಸುತ್ತೇವೆ.';

  @override
  String get profileNameLabel => 'ಪೂರ್ಣ ಹೆಸರು';

  @override
  String get profileNameRequired => 'ನಿಮ್ಮ ಹೆಸರನ್ನು ನಮೂದಿಸಿ';

  @override
  String get profileDobLabel => 'ಜನ್ಮ ದಿನಾಂಕ';

  @override
  String get profileDobHint => 'DD/MM/YYYY';

  @override
  String get profileDobInvalid =>
      'ಜನ್ಮ ದಿನಾಂಕವನ್ನು DD/MM/YYYY ರೂಪದಲ್ಲಿ ನಮೂದಿಸಿ';

  @override
  String get profileDobOnce =>
      'ಎಚ್ಚರಿಕೆಯಿಂದ ಪರಿಶೀಲಿಸಿ: ಜನ್ಮ ದಿನಾಂಕವನ್ನು ನಂತರ ಬದಲಾಯಿಸಲು ಸಾಧ್ಯವಿಲ್ಲ.';

  @override
  String get profileExamYearLabel => 'NEET ಪರೀಕ್ಷೆಯ ವರ್ಷ';

  @override
  String get profileExamYearRequired => 'ನಿಮ್ಮ ಪರೀಕ್ಷೆಯ ವರ್ಷವನ್ನು ಆಯ್ಕೆಮಾಡಿ';

  @override
  String get profileCategoryLabel => 'ವರ್ಗ (ಐಚ್ಛಿಕ)';

  @override
  String get profileCategoryHelp =>
      'ಕಾಲೇಜು ಮುನ್ಸೂಚಕಕ್ಕೆ ಮಾತ್ರ ನಂತರ ಬೇಕಾಗುತ್ತದೆ.';

  @override
  String get categoryNone => 'ಹೇಳಲು ಇಷ್ಟವಿಲ್ಲ';

  @override
  String get categoryGeneral => 'ಸಾಮಾನ್ಯ';

  @override
  String get categoryEws => 'EWS';

  @override
  String get categoryObcNcl => 'OBC (ನಾನ್-ಕ್ರೀಮಿ ಲೇಯರ್)';

  @override
  String get categorySc => 'SC';

  @override
  String get categorySt => 'ST';

  @override
  String get profileLanguageLabel => 'ಆ್ಯಪ್ ಭಾಷೆ';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKannada => 'ಕನ್ನಡ';

  @override
  String get termsTitle => 'ನಿಯಮಗಳು ಮತ್ತು ಗೌಪ್ಯತೆ';

  @override
  String get termsIntro =>
      'ಪ್ರಾರಂಭಿಸುವ ಮೊದಲು, ದಯವಿಟ್ಟು ನಮ್ಮ ಬಳಕೆಯ ನಿಯಮಗಳು ಮತ್ತು ಗೌಪ್ಯತಾ ನೀತಿಯನ್ನು ಓದಿ ಒಪ್ಪಿಕೊಳ್ಳಿ.';

  @override
  String get termsRead => 'ನಿಯಮಗಳು ಮತ್ತು ಗೌಪ್ಯತಾ ನೀತಿಯನ್ನು ಓದಿ';

  @override
  String get termsAgree =>
      'ನಾನು ಬಳಕೆಯ ನಿಯಮಗಳು ಮತ್ತು ಗೌಪ್ಯತಾ ನೀತಿಯನ್ನು ಓದಿದ್ದೇನೆ ಮತ್ತು ಒಪ್ಪುತ್ತೇನೆ';

  @override
  String get termsAccept => 'ಒಪ್ಪಿ ಮುಂದುವರಿಯಿರಿ';

  @override
  String get policyTitle => 'ನಿಯಮಗಳು ಮತ್ತು ಗೌಪ್ಯತಾ ನೀತಿ';

  @override
  String policyVersion(String version) {
    return 'ಆವೃತ್ತಿ $version';
  }

  @override
  String get policyPlaceholderBody =>
      'ಇದು ಕರಡು. ಅಂತಿಮ ಬಳಕೆಯ ನಿಯಮಗಳು ಮತ್ತು ಗೌಪ್ಯತಾ ನೀತಿಯನ್ನು ಸಿದ್ಧಪಡಿಸಲಾಗುತ್ತಿದೆ; ಪ್ರೆಪ್‌ವೃಕ್ಷ ವಿದ್ಯಾರ್ಥಿಗಳಿಗೆ ತೆರೆಯುವ ಮೊದಲು ಇಲ್ಲಿ ಪ್ರಕಟವಾಗುತ್ತದೆ.\n\nಸಂಕ್ಷಿಪ್ತವಾಗಿ: ಸೈನ್ ಇನ್ ಮಾಡಲು ನಿಮ್ಮ ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು, ಮತ್ತು ನಿಮ್ಮ ಪ್ರಗತಿಯನ್ನು ತೋರಿಸಲು ನಿಮ್ಮ ಉತ್ತರಗಳು ಮತ್ತು ಫಲಿತಾಂಶಗಳನ್ನು ಬಳಸುತ್ತೇವೆ. 18 ವರ್ಷದೊಳಗಿನ ವಿದ್ಯಾರ್ಥಿಗಳಿಗೆ ಪೋಷಕರ ಅಥವಾ ಪಾಲಕರ ಅನುಮತಿ ಬೇಕು. 18 ವರ್ಷದೊಳಗಿನ ವಿದ್ಯಾರ್ಥಿಗಳಿಗೆ ನಾವು ಎಂದಿಗೂ ಗುರಿಪಡಿಸಿದ ಜಾಹೀರಾತು ತೋರಿಸುವುದಿಲ್ಲ, ಜಾಹೀರಾತಿಗಾಗಿ ಅವರ ನಡವಳಿಕೆಯನ್ನು ಗಮನಿಸುವುದಿಲ್ಲ, ಮತ್ತು ನಿಮ್ಮ ಹೆಸರು ಅಥವಾ ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು AI ಸೇವೆಗಳಿಗೆ ಕಳುಹಿಸುವುದಿಲ್ಲ. ನೀವು ಯಾವಾಗ ಬೇಕಾದರೂ ನಿಮ್ಮ ಸಮ್ಮತಿಯನ್ನು ಹಿಂಪಡೆಯಬಹುದು.';

  @override
  String get parentTitle => 'ಪೋಷಕರ ಅನುಮತಿ';

  @override
  String get parentIntro =>
      'ನಿಮಗೆ 18 ವರ್ಷ ತುಂಬಿಲ್ಲ, ಆದ್ದರಿಂದ ಪ್ರೆಪ್‌ವೃಕ್ಷ ಬಳಸಲು ಪೋಷಕರು ಅಥವಾ ಪಾಲಕರು ಅನುಮತಿ ನೀಡಬೇಕು. ಅವರ ಫೋನ್‌ಗೆ ಕೋಡ್ ಕಳುಹಿಸುತ್ತೇವೆ.';

  @override
  String get parentNameLabel => 'ಪೋಷಕರ ಅಥವಾ ಪಾಲಕರ ಹೆಸರು';

  @override
  String get parentNameRequired => 'ಪೋಷಕರ ಅಥವಾ ಪಾಲಕರ ಹೆಸರನ್ನು ನಮೂದಿಸಿ';

  @override
  String get parentPhoneLabel => 'ಪೋಷಕರ ಮೊಬೈಲ್ ಸಂಖ್ಯೆ';

  @override
  String get parentSendCode => 'ಪೋಷಕರಿಗೆ ಕೋಡ್ ಕಳುಹಿಸಿ';

  @override
  String parentCodeSent(String name, String last4) {
    return '$last4 ರಲ್ಲಿ ಕೊನೆಗೊಳ್ಳುವ $name ಅವರ ಫೋನ್‌ಗೆ ಕೋಡ್ ಕಳುಹಿಸಿದ್ದೇವೆ. ಅವರಿಂದ ಕೋಡ್ ಪಡೆದು ಇಲ್ಲಿ ನಮೂದಿಸಿ.';
  }

  @override
  String get parentCodeLabel => 'ಪೋಷಕರಿಂದ ಪಡೆದ ಕೋಡ್';

  @override
  String get parentConsentNote =>
      'ಈ ಕೋಡ್ ಹಂಚಿಕೊಳ್ಳುವ ಮೂಲಕ, ನಿಯಮಗಳು ಮತ್ತು ಗೌಪ್ಯತಾ ನೀತಿಯಂತೆ ನೀವು ಪ್ರೆಪ್‌ವೃಕ್ಷ ಬಳಸಲು ನಿಮ್ಮ ಪೋಷಕರು ಅಥವಾ ಪಾಲಕರು ಒಪ್ಪುತ್ತಾರೆ.';

  @override
  String parentCodeWrong(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ಕೋಡ್ ತಪ್ಪಾಗಿದೆ. ಇನ್ನು $count ಪ್ರಯತ್ನಗಳು ಬಾಕಿ ಇವೆ.',
      one: 'ಕೋಡ್ ತಪ್ಪಾಗಿದೆ. ಇನ್ನು 1 ಪ್ರಯತ್ನ ಬಾಕಿ ಇದೆ.',
    );
    return '$_temp0';
  }

  @override
  String get parentCodeLocked => 'ಹಲವು ತಪ್ಪು ಪ್ರಯತ್ನಗಳಾಗಿವೆ. ಹೊಸ ಕೋಡ್ ಕಳುಹಿಸಿ.';

  @override
  String get parentCodeExpired => 'ಕೋಡ್‌ನ ಅವಧಿ ಮುಗಿದಿದೆ. ಹೊಸ ಕೋಡ್ ಕಳುಹಿಸಿ.';

  @override
  String get parentChangeNumber => 'ಪೋಷಕರ ಸಂಖ್ಯೆ ಬದಲಾಯಿಸಿ';

  @override
  String get parentBackToCode => 'ಕೋಡ್ ನಮೂದಿಸಲು ಹಿಂತಿರುಗಿ';

  @override
  String get privacyTitle => 'ಗೌಪ್ಯತೆ ಮತ್ತು ಸಮ್ಮತಿ';

  @override
  String get withdrawTerms => 'ನಿಯಮಗಳಿಗೆ ನೀಡಿದ ಸಮ್ಮತಿ ಹಿಂಪಡೆಯಿರಿ';

  @override
  String get withdrawParental => 'ಪೋಷಕರ ಸಮ್ಮತಿ ಹಿಂಪಡೆಯಿರಿ';

  @override
  String get withdrawConfirmTitle => 'ಸಮ್ಮತಿ ಹಿಂಪಡೆಯುವುದೇ?';

  @override
  String get withdrawConfirmBody =>
      'ಮತ್ತೆ ಸಮ್ಮತಿ ನೀಡುವವರೆಗೆ ನೀವು ಪ್ರೆಪ್‌ವೃಕ್ಷ ಬಳಸಲು ಸಾಧ್ಯವಿಲ್ಲ. ನಿಮ್ಮ ಸಮ್ಮತಿಯ ದಾಖಲೆಯನ್ನು ಇರಿಸಲಾಗುತ್ತದೆ.';

  @override
  String get withdrawConfirm => 'ಹಿಂಪಡೆಯಿರಿ';

  @override
  String get errorAgeOutOfRange =>
      'ಪ್ರೆಪ್‌ವೃಕ್ಷ 13 ರಿಂದ 30 ವರ್ಷದ ವಿದ್ಯಾರ್ಥಿಗಳಿಗಾಗಿ. ನಿಮ್ಮ ಜನ್ಮ ದಿನಾಂಕವನ್ನು ಪರಿಶೀಲಿಸಿ. ಅದು ಸರಿಯಾಗಿದ್ದರೆ, ಕ್ಷಮಿಸಿ, ನೀವು ಈಗ ಸೈನ್ ಅಪ್ ಮಾಡಲು ಸಾಧ್ಯವಿಲ್ಲ.';

  @override
  String get errorDobAlreadySet =>
      'ನಿಮ್ಮ ಜನ್ಮ ದಿನಾಂಕ ಈಗಾಗಲೇ ಉಳಿಸಲಾಗಿದೆ ಮತ್ತು ಇಲ್ಲಿ ಬದಲಾಯಿಸಲು ಸಾಧ್ಯವಿಲ್ಲ. ತಪ್ಪಾಗಿದ್ದರೆ ಬೆಂಬಲ ತಂಡವನ್ನು ಸಂಪರ್ಕಿಸಿ.';

  @override
  String get errorInvalidInput =>
      'ಕೆಲವು ವಿವರಗಳು ಮಾನ್ಯವಾಗಿಲ್ಲ. ಪರಿಶೀಲಿಸಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get errorTermsOutdated =>
      'ನಿಯಮಗಳನ್ನು ನವೀಕರಿಸಲಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಓದಿ ಒಪ್ಪಿಕೊಳ್ಳಿ.';

  @override
  String get errorParentPhoneInvalid =>
      'ಮಾನ್ಯವಾದ 10 ಅಂಕಿಯ ಭಾರತೀಯ ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ';

  @override
  String get errorParentPhoneIsYours =>
      'ನಿಮ್ಮ ಸಂಖ್ಯೆಯಲ್ಲ, ನಿಮ್ಮ ಪೋಷಕರ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ.';

  @override
  String get errorResendTooSoon =>
      'ಇನ್ನೊಂದು ಕೋಡ್ ಕೇಳುವ ಮೊದಲು ಒಂದು ನಿಮಿಷ ಕಾಯಿರಿ.';

  @override
  String get errorDailyLimit =>
      'ಇಂದು ಹಲವು ಕೋಡ್‌ಗಳನ್ನು ಕಳುಹಿಸಲಾಗಿದೆ. ನಾಳೆ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get errorCodeNotSent =>
      'ಕೋಡ್ ಕಳುಹಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ. ಒಂದು ನಿಮಿಷದ ನಂತರ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';
}
