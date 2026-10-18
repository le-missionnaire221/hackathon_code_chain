class AppConstants {
  // URLs du Backend
  static const String productionBackendUrl = 'https://hackathon-code-chain.onrender.com';

  static String get initialBackendUrl => productionBackendUrl;

  // Taux de change et conversions
  static const double satRateInFcfa = 0.65; // 1 Sat ≈ 0.65 FCFA

  // Branding par défaut (surchagé via /branding + admin)
  static const String defaultAppName = 'RAK TAK CASH';
  static const String defaultLogoAsset = 'assets/logo_rak_tak_cash.png';

  // Informations développeur & hackathon
  static const String developerName = 'Idrissa Coulibaly';
  static const String developerInitials = 'IC';
  static const String developerGithub = '@le-missionnaire221';
  static const String hackathonName = 'Code & Chain Dakar 2026';
  static const String hackathonLocation = 'Dakar, Sénégal';

  // Montants rapides pour le POS (Point de Vente)
  static const List<String> quickSatsPresets = ['50', '100', '500', '1000', '5000'];
}
