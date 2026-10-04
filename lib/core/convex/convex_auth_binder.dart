import '../errors/app_exception.dart';
import '../../features/auth/domain/auth_access_token_source.dart';
import '../../features/auth/domain/auth_user.dart';
import 'convex_document.dart';
import 'convex_gateway.dart';

class ConvexAuthBinder {
  ConvexAuthBinder({
    required ConvexGateway gateway,
    required AuthAccessTokenSource tokens,
  })  : _gateway = gateway,
        _tokens = tokens;

  final ConvexGateway _gateway;
  final AuthAccessTokenSource _tokens;
  Future<void>? _inFlight;
  var _bound = false;
  String? _domainUserId;
  String? _boundAuthSubject;

  bool get isBound => _bound;

  String? get domainUserId => _domainUserId;

  Future<void> sync(AuthUser? user) {
    final run = user == null ? _clear() : _bind(authSubject: user.id);
    _inFlight = run;
    return run;
  }

  Future<bool> ensureAuthenticated({String? authSubject}) async {
    final inFlight = _inFlight;
    if (inFlight != null) {
      await inFlight;
    }
    final token = await _tokens.accessToken();
    if (token == null) {
      if (_bound) {
        await _clear();
      }
      return false;
    }
    if (_bound) {
      if (authSubject != null &&
          _boundAuthSubject != null &&
          authSubject != _boundAuthSubject) {
        await _clear();
        await syncFromTokens(authSubject: authSubject);
        return _bound;
      }
      if (authSubject != null) {
        _boundAuthSubject = authSubject;
      }
      return true;
    }
    await syncFromTokens(authSubject: authSubject);
    return _bound;
  }

  Future<void> syncFromTokens({String? authSubject}) {
    final run = _bind(authSubject: authSubject);
    _inFlight = run;
    return run;
  }

  Future<void> dispose() async {
    await _clear();
  }

  Future<void> _bind({String? authSubject}) async {
    final token = await _tokens.accessToken();
    if (token == null) {
      await _clear();
      return;
    }
    try {
      await _gateway.setAuthWithRefresh(
        fetchToken: ({required bool forceRefresh}) {
          return _tokens.accessToken(forceRefresh: forceRefresh);
        },
      );
      final raw = await _gateway.mutate('users:ensureUser');
      _domainUserId = convexId(convexObject(raw, label: 'user'));
      _boundAuthSubject = authSubject;
      _bound = true;
    } catch (error) {
      _bound = false;
      _domainUserId = null;
      _boundAuthSubject = null;
      throw AppAuthException(
        'Impossible d authentifier Convex.',
        cause: error,
      );
    }
  }

  Future<void> _clear() async {
    _bound = false;
    _domainUserId = null;
    _boundAuthSubject = null;
    await _gateway.clearAuth();
  }
}
