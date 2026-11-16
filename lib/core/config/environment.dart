/// Hardcoded Appwrite project credentials for ReadBeat.
abstract final class Environment {
  static const String appwriteProjectId = '6a7c5158001d3f13c15e';
  static const String appwriteProjectName = 'New project';
  static const String appwritePublicEndpoint =
      'https://fra.cloud.appwrite.io/v1';

  /// Deep-link scheme registered on Android/iOS for OAuth callbacks.
  static const String appwriteOAuthCallbackScheme =
      'appwrite-callback-$appwriteProjectId';
}
