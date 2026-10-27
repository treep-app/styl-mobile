/// Layout spacing and corner radii used across screens.
///
/// Radii map to Figma: inputs/buttons `10`, role cards `15`, sheets `25`.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal page inset from Figma (20 on 375-wide frames).
  static const double page = 20;
}

abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 15;
  static const double xl = 25;
  static const double pill = 999;
}

abstract final class AppAssets {
  static const String logo = 'assets/images/styl_logo.png';
  static const String roleCustomer = 'assets/images/role_customer.svg';
  static const String roleServiceProvider =
      'assets/images/role_service_provider.svg';
}
