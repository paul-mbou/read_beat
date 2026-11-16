import 'package:appwrite/appwrite.dart';
import 'package:read_beat/core/config/environment.dart';

/// Global Appwrite client for the ReadBeat project.
final Client client = Client()
    .setProject(Environment.appwriteProjectId)
    .setEndpoint(Environment.appwritePublicEndpoint);
