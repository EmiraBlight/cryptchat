class UserSession {
  static String? username;
  static String? email;
  static String? uid;

  static void clear() {
    username = null;
    email = null;
    uid = null;
  }
}