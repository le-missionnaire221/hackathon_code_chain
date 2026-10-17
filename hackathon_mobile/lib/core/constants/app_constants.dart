class AppConstants {
  // URLs du Backend
  static const String productionBackendUrl = 'https://hackathon-code-chain.onrender.com';
  static const String defaultWebBackendUrl = 'http://localhost:5000';
  static const String defaultAndroidBackendUrl = 'http://10.0.2.2:5000';

  static String get initialBackendUrl => productionBackendUrl;

  // Taux de change et conversions
  static const double satRateInFcfa = 0.65; // 1 Sat ≈ 0.65 FCFA

  // Informations utilisateur & hackathon
  static const String developerName = 'Idrissa Coulibaly';
  static const String developerInitials = 'IC';
  static const String developerGithub = '@le-missionnaire221';
  static const String hackathonName = 'Code & Chain Dakar 2026';
  static const String hackathonLocation = 'Dakar, Sénégal 🇸🇳';
  static const String blinkLightningAddress = 'le-missionnaire221@blink.sv';

  // Montants rapides pour le POS (Point de Vente)
  static const List<String> quickSatsPresets = ['50', '100', '500', '1000', '5000'];
}
