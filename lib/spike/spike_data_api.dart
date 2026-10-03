import 'package:dartvex/dartvex.dart';

import 'spike_convex.dart';

class SpikeMarkerRead {
  const SpikeMarkerRead({
    required this.authenticated,
    required this.subject,
    required this.marker,
  });

  final bool authenticated;
  final String? subject;
  final String? marker;
}

class SpikeMarkerWrite {
  const SpikeMarkerWrite({
    required this.subject,
    required this.marker,
  });

  final String subject;
  final String marker;
}

class SpikeDataApi {
  const SpikeDataApi();

  Future<SpikeMarkerRead> getMarker() async {
    final raw = await SpikeConvex.client.query('spike:getMarker');
    if (raw is! Map) {
      throw StateError('Unexpected getMarker response.');
    }
    final subject = raw['subject']?.toString();
    final marker = raw['marker']?.toString();
    return SpikeMarkerRead(
      authenticated: raw['authenticated'] == true,
      subject: (subject == null || subject.isEmpty) ? null : subject,
      marker: (marker == null || marker.isEmpty) ? null : marker,
    );
  }

  Future<SpikeMarkerWrite> setMarker(String marker) async {
    final raw = await SpikeConvex.client.mutate('spike:setMarker', {
      'marker': marker.trim(),
    });
    if (raw is! Map) {
      throw StateError('Unexpected setMarker response.');
    }
    final subject = raw['subject']?.toString();
    final written = raw['marker']?.toString();
    if (subject == null || subject.isEmpty || written == null || written.isEmpty) {
      throw StateError('setMarker did not return subject and marker.');
    }
    return SpikeMarkerWrite(subject: subject, marker: written);
  }

  ConvexSubscription watchMarker() {
    return SpikeConvex.client.subscribe('spike:getMarker');
  }

  Future<({String subject, String probe})> pingAuth(String probe) async {
    final raw = await SpikeConvex.client.action(
      'spike:pingAuth',
      {'probe': probe.trim()},
    );
    if (raw is! Map) {
      throw StateError('Unexpected pingAuth response.');
    }
    final subject = raw['subject']?.toString();
    final echoed = raw['probe']?.toString();
    if (subject == null || subject.isEmpty || echoed == null || echoed.isEmpty) {
      throw StateError('pingAuth did not return subject and probe.');
    }
    return (subject: subject, probe: echoed);
  }
}
