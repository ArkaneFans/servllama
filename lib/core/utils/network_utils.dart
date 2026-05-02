import 'dart:io';

class NetworkUtils {
  NetworkUtils._();

  // get native ipv4 address
  static Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
