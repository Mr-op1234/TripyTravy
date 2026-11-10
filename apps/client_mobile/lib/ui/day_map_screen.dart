import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tripytravy_core/tripytravy_core.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DayMapStop {
  final String label;
  final String query;
  const DayMapStop(this.label, this.query);
}

List<DayMapStop> dayMapStops(ItineraryDay day) {
  final stops = <DayMapStop>[];
  for (final event in day.events) {
    for (final location in event.locationCards) {
      final name = (location['locationName'] as String? ?? '').trim();
      final lat = location['latitude'] as num?;
      final lng = location['longitude'] as num?;
      final url = Uri.tryParse(location['rawUrl'] as String? ?? '');
      final query = lat != null && lng != null
          ? '$lat,$lng'
          : name.isNotEmpty && name != 'Location'
              ? name
              : url?.queryParameters['query'] ??
                  url?.queryParameters['q'] ??
                  '';
      if (query.isNotEmpty && (stops.isEmpty || stops.last.query != query)) {
        stops.add(DayMapStop(name.isNotEmpty ? name : query, query));
      }
    }
  }
  return stops;
}

Uri dayMapUrl(List<DayMapStop> stops, String mode,
    {bool embed = true, String apiKey = ''}) {
  if (stops.isEmpty) throw ArgumentError('A map requires a location.');
  if (apiKey.isNotEmpty && embed) {
    return Uri.https('www.google.com',
        '/maps/embed/v1/${stops.length == 1 ? 'place' : 'directions'}', {
      'key': apiKey,
      if (stops.length == 1) 'q': stops.first.query,
      if (stops.length > 1) ...{
        'origin': stops.first.query,
        'destination': stops.last.query,
        'mode': mode,
        if (stops.length > 2)
          'waypoints':
              stops.sublist(1, stops.length - 1).map((s) => s.query).join('|'),
      },
    });
  }
  if (!embed) {
    return Uri.https(
        'www.google.com', stops.length == 1 ? '/maps/search/' : '/maps/dir/', {
      'api': '1',
      if (stops.length == 1) 'query': stops.first.query,
      if (stops.length > 1) ...{
        'origin': stops.first.query,
        'destination': stops.last.query,
        'travelmode': mode,
        if (stops.length > 2)
          'waypoints':
              stops.sublist(1, stops.length - 1).map((s) => s.query).join('|'),
      },
    });
  }
  return Uri.https('maps.google.com', '/maps', {
    'output': 'embed',
    if (stops.length == 1) 'q': stops.first.query,
    if (stops.length > 1) ...{
      'saddr': stops.first.query,
      'daddr': stops.skip(1).map((s) => s.query).join(' to:'),
      'dirflg': {'driving': 'd', 'walking': 'w', 'bicycling': 'b'}[mode]!,
      'f': 'd',
    },
  });
}

class DayMapScreen extends StatefulWidget {
  final ItineraryDay day;
  const DayMapScreen({super.key, required this.day});
  @override
  State<DayMapScreen> createState() => _DayMapScreenState();
}

class _DayMapScreenState extends State<DayMapScreen> {
  late final List<DayMapStop> _stops;
  WebViewController? _controller;
  String _mode = 'driving';
  int _leg = -1;
  bool _loading = true;
  bool _failed = false;
  List<DayMapStop> get _selectedStops =>
      _leg < 0 ? _stops : _stops.sublist(_leg, _leg + 2);

  @override
  void initState() {
    super.initState();
    _stops = dayMapStops(widget.day);
    if (_stops.isEmpty) return;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if (mounted && error.isForMainFrame == true)
            setState(() {
              _loading = false;
              _failed = true;
            });
        },
        onNavigationRequest: (request) => request.url.startsWith('https://') ||
                request.url.startsWith('about:') ||
                request.url.startsWith('data:')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ));
    _loadMap();
  }

  Future<void> _loadMap() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final url = dayMapUrl(_selectedStops, _mode,
        apiKey: const String.fromEnvironment('GOOGLE_MAPS_EMBED_API_KEY'));
    final escaped = const HtmlEscape().convert(url.toString());
    await _controller!.loadHtmlString(
        '''<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>html,body{height:100%;margin:0}iframe{width:100%;height:100%;border:0}</style></head><body><iframe title="Day route" src="$escaped" allowfullscreen referrerpolicy="strict-origin-when-cross-origin"></iframe></body></html>''');
  }

  Future<void> _openExternally() async {
    try {
      await const MethodChannel('com.tripytravy.client_mobile/file_intent')
          .invokeMethod('openUrl', {
        'url': dayMapUrl(_selectedStops, _mode, embed: false).toString()
      });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Google Maps.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Day ${widget.day.dayNumber} · Map')),
        body: _stops.isEmpty
            ? const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child:
                        Text('No map locations are available for this day.')))
            : Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_stops.length} stops · itinerary order',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                              initialValue: _mode,
                              decoration: const InputDecoration(
                                  labelText: 'Travel mode',
                                  border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(
                                    value: 'driving', child: Text('Driving')),
                                DropdownMenuItem(
                                    value: 'walking', child: Text('Walking')),
                                DropdownMenuItem(
                                    value: 'bicycling',
                                    child: Text('Bike (bicycle)'))
                              ],
                              onChanged: _stops.length < 2
                                  ? null
                                  : (mode) {
                                      if (mode != null) {
                                        setState(() => _mode = mode);
                                        _loadMap();
                                      }
                                    }),
                          if (_stops.length > 1) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                                initialValue: _leg,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Route',
                                    border: OutlineInputBorder()),
                                items: [
                                  const DropdownMenuItem(
                                      value: -1, child: Text('Whole day')),
                                  for (var i = 0; i < _stops.length - 1; i++)
                                    DropdownMenuItem(
                                        value: i,
                                        child: Text(
                                            '${i + 1}. ${_stops[i].label} → ${_stops[i + 1].label}',
                                            overflow: TextOverflow.ellipsis))
                                ],
                                onChanged: (leg) {
                                  if (leg != null) {
                                    setState(() => _leg = leg);
                                    _loadMap();
                                  }
                                }),
                          ],
                          const SizedBox(height: 8),
                          const Text(
                              'Google Maps shows available route distances and times. Internet required; cycling routes may be unavailable in some regions.',
                              style: TextStyle(fontSize: 12)),
                        ])),
                if (_loading) const LinearProgressIndicator(),
                if (_failed)
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextButton(
                          onPressed: _loadMap,
                          child: const Text('Map could not load. Retry'))),
                Expanded(child: WebViewWidget(controller: _controller!)),
                SafeArea(
                    top: false,
                    child: TextButton.icon(
                        onPressed: _openExternally,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open in Google Maps'))),
              ]),
      );
}
