class AuthService {

  static final Map<String, String> users = {};

  static bool register(String id, String password) {
    if (users.containsKey(id)) {
      return false;
    }

    users[id] = password;
    return true;
  }

  static bool login(String id, String password) {
    return users[id] == password;
  }
}
