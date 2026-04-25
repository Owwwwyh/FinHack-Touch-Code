class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/v1',
  );

  static const apiBearerToken = String.fromEnvironment(
    'API_BEARER_TOKEN',
    defaultValue: 'demo-token',
  );

  static const deviceId = String.fromEnvironment(
    'DEVICE_ID',
    defaultValue: 'did:tng:device:demo',
  );
}
