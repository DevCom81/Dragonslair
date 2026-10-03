import 'dart:async';
import 'dart:convert';

import 'package:dartvex/dartvex.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'spike_auth_api.dart';
import 'spike_config.dart';
import 'spike_convex.dart';
import 'spike_data_api.dart';
import 'spike_session_store.dart';

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DragonsLair LOT 0A',
      debugShowCheckedModeBanner: true,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          error: AppColors.danger,
        ),
      ),
      home: const SpikeWhoamiScreen(),
    );
  }
}

class SpikeWhoamiScreen extends StatefulWidget {
  const SpikeWhoamiScreen({super.key});

  @override
  State<SpikeWhoamiScreen> createState() => _SpikeWhoamiScreenState();
}

class _SpikeWhoamiScreenState extends State<SpikeWhoamiScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _marker = TextEditingController(text: 'web-1');
  final _authApi = const SpikeAuthApi();
  final _dataApi = const SpikeDataApi();

  var _busy = false;
  String? _pendingAuthenticationToken;
  String? _pendingEmail;
  String? _whoamiSubject;
  String _status = 'Not signed in.';
  String _subStatus = 'Subscription idle.';
  var _subSuccessCount = 0;
  ConvexSubscription? _markerWatch;
  StreamSubscription<QueryResult>? _markerWatchListen;
  StreamSubscription<ConnectionStatus>? _connectionListen;
  String _wsStatus = '[WS] idle';

  @override
  void initState() {
    super.initState();
    unawaited(_tryRestore());
  }

  @override
  void dispose() {
    _connectionListen?.cancel();
    _stopMarkerWatch();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _marker.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Signing in…';
      _pendingAuthenticationToken = null;
      _pendingEmail = null;
      _whoamiSubject = null;
      _subStatus = 'Subscription idle.';
      _subSuccessCount = 0;
    });
    _stopMarkerWatch();
    try {
      if (!SpikeConfig.isConfigured) {
        throw StateError(
          'CONVEX_URL is missing. Pass --dart-define=CONVEX_URL=...',
        );
      }
      final result = await _authApi.signInWithPassword(
        email: _email.text,
        password: _password.text,
      );
      switch (result) {
        case SpikeSignedIn():
          await _applySignedIn(result);
        case SpikeEmailVerificationRequired(
            :final email,
            :final pendingAuthenticationToken,
          ):
          setState(() {
            _pendingEmail = email;
            _pendingAuthenticationToken = pendingAuthenticationToken;
            _status =
                'Email verification required for $email. Enter the code from WorkOS.';
          });
      }
    } catch (error) {
      setState(() {
        _status = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _verifyEmail() async {
    final pending = _pendingAuthenticationToken;
    if (_busy || pending == null) {
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Verifying email…';
    });
    try {
      final signedIn = await _authApi.verifyEmailCode(
        code: _code.text,
        pendingAuthenticationToken: pending,
      );
      _pendingAuthenticationToken = null;
      _code.clear();
      await _applySignedIn(signedIn);
    } catch (error) {
      setState(() {
        _status = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _tryRestore() async {
    if (!SpikeConfig.isConfigured) {
      return;
    }
    if (!await SpikeSessionStore.hasRefreshToken()) {
      return;
    }
    setState(() {
      _busy = true;
      _status = '[RESTORE] stored session found…';
    });
    try {
      await SpikeConvex.bindRefreshableAuth(
        fetchToken: _authApi.fetchStoredWorkosToken,
      );
      await _loadWhoami();
      if (_whoamiSubject != null) {
        _startMarkerWatch();
        if (mounted) {
          setState(() {
            _status =
                '[RESTORE] session restored without password\nsubject=$_whoamiSubject';
          });
        }
      } else {
        await SpikeSessionStore.clear();
      }
    } catch (error) {
      await SpikeSessionStore.clear();
      if (mounted) {
        setState(() {
          _status = '[RESTORE] failed: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _applySignedIn(SpikeSignedIn signedIn) async {
    final claims = _inspectJwtPayloadClaims(signedIn.accessToken);
    await SpikeSessionStore.save(
      accessToken: signedIn.accessToken,
      refreshToken: signedIn.refreshToken,
    );
    await SpikeConvex.bindRefreshableAuth(
      fetchToken: _authApi.fetchStoredWorkosToken,
    );
    await _loadWhoami();
    if (_whoamiSubject != null) {
      _startMarkerWatch();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _status = '$claims\n\n$_status';
    });
  }

  /// Payload-only inspection. Never returns header, signature, or raw token.
  String _inspectJwtPayloadClaims(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return 'JWT payload: unexpected structure.';
      }
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) {
        return 'JWT payload: not an object.';
      }
      return [
        'iss = ${_formatIss(payload['iss'])}',
        'aud = ${_formatAud(payload['aud'])}',
        'client_id = ${_formatIss(payload['client_id'])}',
        'sub = ${_formatClaim(payload['sub'])}',
        'iat = ${_formatClaim(payload['iat'])}',
        'exp = ${_formatClaim(payload['exp'])}',
      ].join('\n');
    } catch (_) {
      return 'JWT payload: decode failed.';
    }
  }

  String _formatIss(Object? value) {
    if (value is! String || value.isEmpty) {
      return 'ABSENT';
    }
    return value;
  }

  String _formatAud(Object? value) {
    if (value == null) {
      return 'ABSENT';
    }
    if (value is String) {
      return value.isEmpty ? 'ABSENT' : value;
    }
    if (value is List) {
      if (value.isEmpty) {
        return 'ABSENT';
      }
      return jsonEncode(value);
    }
    return value.toString();
  }

  String _formatClaim(Object? value) {
    if (value == null) {
      return 'ABSENT';
    }
    return value.toString();
  }

  Future<void> _loadWhoami() async {
    final raw = await SpikeConvex.client.query('spike:whoami');
    if (raw is! Map) {
      setState(() {
        _status = 'whoami returned an unexpected payload.';
      });
      return;
    }
    final authenticated = raw['authenticated'] == true;
    final subject = raw['subject']?.toString();
    final issuer = raw['issuer']?.toString();
    if (!authenticated || subject == null || subject.isEmpty) {
      _whoamiSubject = null;
      setState(() {
        _status =
            'Convex identity is null. Check WorkOS JWT aud/iss vs auth.config.ts.';
      });
      return;
    }
    _whoamiSubject = subject;
    setState(() {
      _status =
          'authenticated=true\nsubject=$subject\nissuer=${issuer ?? ''}';
    });
  }

  Future<void> _setMarker() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Setting marker…';
    });
    try {
      final written = await _dataApi.setMarker(_marker.text);
      _showMarkerStatus(
        source: '[MUT]',
        markerSubject: written.subject,
        marker: written.marker,
      );
    } catch (error) {
      setState(() {
        _status = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _getMarker() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Reading marker…';
    });
    try {
      final read = await _dataApi.getMarker();
      if (!read.authenticated) {
        setState(() {
          _status =
              '[GET]\nauthenticated=false\nsubject=null\nmarker=null';
        });
        return;
      }
      _showMarkerStatus(
        source: '[GET]',
        markerSubject: read.subject,
        marker: read.marker,
      );
    } catch (error) {
      setState(() {
        _status = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _showMarkerStatus({
    required String source,
    required String? markerSubject,
    required String? marker,
  }) {
    final whoamiSubject = _whoamiSubject;
    final match = whoamiSubject != null &&
            markerSubject != null &&
            whoamiSubject == markerSubject
        ? 'yes'
        : 'no';
    setState(() {
      _status = [
        source,
        'whoami subject=${whoamiSubject ?? 'ABSENT'}',
        'marker subject=${markerSubject ?? 'ABSENT'}',
        'marker=${marker ?? 'ABSENT'}',
        'subjects match=$match',
      ].join('\n');
    });
  }

  Future<void> _pingAuth() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _status = '[ACT] pingAuth…';
    });
    try {
      final result = await _dataApi.pingAuth('web-action');
      final match = _whoamiSubject != null && _whoamiSubject == result.subject
          ? 'yes'
          : 'no';
      setState(() {
        _status = [
          '[ACT]',
          'whoami subject=${_whoamiSubject ?? 'ABSENT'}',
          'action subject=${result.subject}',
          'probe=${result.probe}',
          'subjects match=$match',
        ].join('\n');
      });
    } catch (error) {
      setState(() {
        _status = '[ACT] $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _forceRefresh() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _status = '[REFRESH] requesting new access token…';
    });
    try {
      final token = await _authApi.fetchStoredWorkosToken(forceRefresh: true);
      if (token == null) {
        throw StateError('No stored refresh session.');
      }
      await SpikeConvex.client.updateAuthToken(token);
      await _loadWhoami();
      if (mounted) {
        setState(() {
          _status =
              '[REFRESH] new access token applied\nsubject=${_whoamiSubject ?? 'ABSENT'}';
        });
      }
    } catch (error) {
      setState(() {
        _status = '[REFRESH] $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _reconnect() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _status = '[WS] reconnectNow…';
    });
    try {
      await SpikeConvex.client.reconnectNow('spike-manual');
      if (mounted) {
        setState(() {
          _status = '[WS] reconnectNow completed';
        });
      }
    } catch (error) {
      setState(() {
        _status = '[WS] reconnect failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
    });
    _stopMarkerWatch();
    try {
      await SpikeConvex.client.clearAuth();
      await SpikeSessionStore.clear();
      if (mounted) {
        setState(() {
          _whoamiSubject = null;
          _subStatus = 'Subscription idle.';
          _subSuccessCount = 0;
          _wsStatus = '[WS] idle';
          _status = 'Signed out. Stored session cleared.';
        });
      }
    } catch (error) {
      setState(() {
        _status = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _startMarkerWatch() {
    _stopMarkerWatch();
    _subSuccessCount = 0;
    final watch = _dataApi.watchMarker();
    _markerWatch = watch;
    _markerWatchListen = watch.stream.listen(_onMarkerWatchResult);
    _connectionListen?.cancel();
    _connectionListen = SpikeConvex.client.connectionStatus.listen((status) {
      if (!mounted) {
        return;
      }
      setState(() {
        _wsStatus =
            '[WS] ${status.state.name} retries=${status.connectionRetries} count=${status.connectionCount}';
      });
    });
    _wsStatus =
        '[WS] ${SpikeConvex.client.currentConnectionStatus.state.name}';
  }

  void _stopMarkerWatch() {
    _markerWatchListen?.cancel();
    _markerWatchListen = null;
    _markerWatch?.cancel();
    _markerWatch = null;
    _connectionListen?.cancel();
    _connectionListen = null;
  }

  void _onMarkerWatchResult(QueryResult result) {
    switch (result) {
      case QueryLoading():
        return;
      case QueryError(:final message):
        if (!mounted) {
          return;
        }
        setState(() {
          _subStatus = '[SUB error]\n$message';
        });
      case QuerySuccess(:final value):
        _subSuccessCount += 1;
        if (!mounted) {
          return;
        }
        final parsed = _readMarkerQueryValue(value);
        setState(() {
          _subStatus = [
            '[SUB #$_subSuccessCount]',
            'marker=${parsed.marker ?? 'ABSENT'}',
            'subject=${parsed.subject ?? 'ABSENT'}',
          ].join('\n');
        });
    }
  }

  SpikeMarkerRead _readMarkerQueryValue(Object? value) {
    if (value is! Map) {
      return const SpikeMarkerRead(
        authenticated: false,
        subject: null,
        marker: null,
      );
    }
    final subject = value['subject']?.toString();
    final marker = value['marker']?.toString();
    return SpikeMarkerRead(
      authenticated: value['authenticated'] == true,
      subject: (subject == null || subject.isEmpty) ? null : subject,
      marker: (marker == null || marker.isEmpty) ? null : marker,
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsCode = _pendingAuthenticationToken != null;
    return Scaffold(
      appBar: AppBar(title: const Text('LOT 0A — whoami')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                SpikeConfig.isConfigured
                    ? 'CONVEX_URL is set.'
                    : 'CONVEX_URL is missing.',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                enabled: !needsCode,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                enabled: !needsCode,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (needsCode) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: InputDecoration(
                    labelText: 'Email verification code',
                    helperText: _pendingEmail == null
                        ? null
                        : 'Sent to $_pendingEmail',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (!needsCode)
                FilledButton(
                  onPressed: _busy ? null : _signIn,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign in + whoami'),
                )
              else
                FilledButton(
                  onPressed: _busy ? null : _verifyEmail,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify email + whoami'),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _marker,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Marker'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _setMarker,
                child: const Text('Set marker'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _getMarker,
                child: const Text('Get marker'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _pingAuth,
                child: const Text('Ping auth action'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _forceRefresh,
                child: const Text('Force token refresh'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _reconnect,
                child: const Text('Reconnect WS'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : _signOut,
                child: const Text('Sign out'),
              ),
              const SizedBox(height: 16),
              SelectableText(
                _wsStatus,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              SelectableText(
                _subStatus,
                style: const TextStyle(color: AppColors.gold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    _status,
                    style: const TextStyle(color: AppColors.cream),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
