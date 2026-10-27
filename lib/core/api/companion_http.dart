import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// True for hosts that can only be reached on a local or private network:
/// loopback, RFC 1918, link-local, CGNAT/Tailscale (100.64.0.0/10), IPv6
/// ULA, and local-only DNS suffixes.
///
/// A self-signed certificate is only trusted for these. On a public host an
/// invalid certificate means a possible man-in-the-middle, and the companion
/// API key it would capture can delete files on the server.
bool isPrivateNetworkHost(String host) {
  var h = host.toLowerCase();
  if (h.startsWith('[') && h.endsWith(']')) h = h.substring(1, h.length - 1);
  if (h == 'localhost' ||
      h.endsWith('.localhost') ||
      h.endsWith('.local') ||
      h.endsWith('.lan') ||
      h.endsWith('.home.arpa') ||
      h.endsWith('.internal')) {
    return true;
  }
  final ip = InternetAddress.tryParse(h);
  if (ip == null) return false;
  final b = ip.rawAddress;
  if (ip.type == InternetAddressType.IPv4) {
    return b[0] == 127 ||
        b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
        (b[0] == 192 && b[1] == 168) ||
        (b[0] == 169 && b[1] == 254) ||
        (b[0] == 100 && b[1] >= 64 && b[1] <= 127);
  }
  if (ip.isLoopback) return true;
  // fc00::/7 (unique local) and fe80::/10 (link local).
  return (b[0] & 0xfe) == 0xfc || (b[0] == 0xfe && (b[1] & 0xc0) == 0x80);
}

/// Lets [dio] accept a self-signed certificate from the companion, but only
/// when the companion lives on a private network (see [isPrivateNetworkHost]).
void allowSelfSignedOnPrivateHosts(Dio dio) {
  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () =>
      HttpClient()
        ..badCertificateCallback =
            (_, String host, __) => isPrivateNetworkHost(host);
}

/// Whether [url] points at the same scheme, host and port as [base], so
/// credentials meant for [base] may be sent to it.
bool isSameOrigin(Uri url, Uri base) =>
    url.scheme == base.scheme && url.host == base.host && url.port == base.port;
