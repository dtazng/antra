/// App-wide configuration constants.
/// Values are injected at build time via --dart-define.
/// After CDK deploy, copy values from backend/outputs.json.
class AppConfig {
  AppConfig._();

  static const apiGatewayBaseUrl = String.fromEnvironment(
    'API_GATEWAY_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const cognitoUserPoolId = String.fromEnvironment(
    'COGNITO_USER_POOL_ID',
    defaultValue: '',
  );

  static const cognitoClientId = String.fromEnvironment(
    'COGNITO_CLIENT_ID',
    defaultValue: '',
  );
}
