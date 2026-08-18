/// True when an image URL points at a private/local host a phone can't reach
/// (localhost, 10.x, 192.168.x, 172.16–31.x). Loading such a URL with
/// Image.network hangs for minutes until the TCP connection times out — so
/// callers should skip it and show a fallback instead.
bool isUnreachableImageUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final host = Uri.tryParse(url)?.host ?? '';
  if (host.isEmpty) return false;
  if (host == 'localhost' || host == '127.0.0.1') return true;
  if (RegExp(r'^10\.').hasMatch(host)) return true;
  if (RegExp(r'^192\.168\.').hasMatch(host)) return true;
  if (RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(host)) return true;
  return false;
}

/// A URL safe to hand to an image widget: the original if reachable, else null.
String? safeImageUrl(String? url) =>
    (url != null && url.isNotEmpty && !isUnreachableImageUrl(url)) ? url : null;
