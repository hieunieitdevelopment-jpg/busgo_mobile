class ApiConstants {
  ApiConstants._();

  // Google OAuth Configuration
  static const String GOOGLE_CLIENT_ID =
      "335430946794-8mkv3iqd0dvgq208ep9gf6t9hj07lsqc.apps.googleusercontent.com";

  // API Endpoints
  static const String AUTH_SIGN_IN = "/auth/sign-in";
  static const String AUTH_GOOGLE_VERIFY = "/auth/google/verify-token";
  static const String CUSTOMER_SIGN_UP = "/customer/sign-up";
  static const String CUSTOMER_PROFILE = "/customer/profile";
  static const String AUTH_LOGOUT = "/auth/logout";
}
