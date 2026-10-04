import '../../../core/convex/convex_action.dart';
import '../../../core/convex/convex_auth_binder.dart';
import '../../../core/convex/convex_document.dart';
import '../../../core/convex/convex_gateway.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/windows_download_client.dart';

class ConvexWindowsDownloadClient implements WindowsDownloadClient {
  ConvexWindowsDownloadClient({
    required ConvexGateway gateway,
    required ConvexAuthBinder binder,
  })  : _gateway = gateway,
        _binder = binder;

  final ConvexGateway _gateway;
  final ConvexAuthBinder _binder;

  @override
  Future<Uri> requestDownloadUri() async {
    final raw = await convexAction(
      gateway: _gateway,
      binder: _binder,
      name: 'downloads:createWindowsDownload',
      timeout: convexBillingTimeout,
    );
    final json = convexObject(raw, label: 'download');
    final url = json['download_url']?.toString().trim() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const NetworkException('Lien de telechargement absent.');
    }
    return uri;
  }
}
