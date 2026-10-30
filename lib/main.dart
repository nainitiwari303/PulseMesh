
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const PulseMeshApp());

const bg = Color(0xFF080B12);
const panel = Color(0xFF101622);
const border = Color(0xFF202B3B);
const cyan = Color(0xFF48D9E8);
const green = Color(0xFF53E0A0);
const red = Color(0xFFFF667D);
const amber = Color(0xFFFFC66D);
const muted = Color(0xFF8492A8);

class PulseMeshApp extends StatelessWidget {
  const PulseMeshApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PulseMesh',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: cyan,
            brightness: Brightness.dark,
          ),
          fontFamily: 'Arial',
          useMaterial3: true,
        ),
        home: const Dashboard(),
      );
}

class ServiceNode {
  ServiceNode(this.name, this.description, this.latency, this.requests,
      this.errors, this.icon);

  final String name;
  final String description;
  double latency;
  int requests;
  double errors;
  final IconData icon;
  bool forcedFailure = false;

  String get status =>
      forcedFailure ? 'DEGRADED' : errors > 4 ? 'DEGRADED' : 'HEALTHY';
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final random = math.Random();
  Timer? timer;
  int selectedNav = 0;
  bool paused = false;
  int totalRequests = 128430;
  int totalIncidents = 3;
  double overallLatency = 84;
  final List<double> latencyHistory =
      List.generate( thirtySamples, (i) => 65 + (i % 8) * 4.0);

  static const int thirtySamples = 30;

  late final List<ServiceNode> services = [
    ServiceNode('api-gateway', 'Entry point · :8080', 42, 48210, 0.4,
        Icons.hub_outlined),
    ServiceNode('auth-service', 'Identity · :8081', 28, 28640, 0.2,
        Icons.lock_outline),
    ServiceNode('payments-core', 'Transactions · :8082', 116, 19430, 1.8,
        Icons.account_balance_wallet_outlined),
    ServiceNode('event-stream', 'Message bus · :8083', 64, 32710, 0.7,
        Icons.swap_horiz),
    ServiceNode('data-store', 'Persistence · :5432', 35, 9440, 0.1,
        Icons.storage_outlined),
  ];

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || paused) return;
      setState(() {
        totalRequests += 18 + random.nextInt(45);
        overallLatency = services
                .where((s) => !s.forcedFailure)
                .fold<double>(0, (sum, s) => sum + s.latency) /
            services.where((s) => !s.forcedFailure).length;
        for (final service in services) {
          service.requests += random.nextInt(13);
          if (!service.forcedFailure) {
            service.latency =
                (service.latency + random.nextDouble() * 12 - 5)
                    .clamp(15, 250);
          } else {
            service.latency = 450 + random.nextDouble() * 250;
          }
        }
        latencyHistory.add(overallLatency);
        if (latencyHistory.length > thirtySamples) {
          latencyHistory.removeAt(0);
        }
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void toggleFailure(ServiceNode service) {
    setState(() {
      service.forcedFailure = !service.forcedFailure;
      if (service.forcedFailure) {
        service.errors = 12 + random.nextDouble() * 8;
        totalIncidents++;
      } else {
        service.errors = 0.5;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(service.forcedFailure
          ? 'Failure injected into ${service.name}'
          : '${service.name} recovered in demo simulation'),
      backgroundColor: service.forcedFailure ? red : green,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;
    final healthy =
        services.where((s) => s.status == 'HEALTHY').length;
    final failures =
        services.where((s) => s.status != 'HEALTHY').length;

    return Scaffold(
      body: Row(
        children: [
          if (!compact) _sidebar(),
          Expanded(
            child: Column(
              children: [
                _topbar(compact),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(compact ? 16 : 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _heading(compact),
                        const SizedBox(height: 24),
                        _metrics(width),
                        const SizedBox(height: 22),
                        if (width > 1050)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _latencyPanel()),
                              const SizedBox(width: 18),
                              Expanded(flex: 2, child: _healthPanel()),
                            ],
                          )
                        else ...[
                          _latencyPanel(),
                          const SizedBox(height: 18),
                          _healthPanel(),
                        ],
                        const SizedBox(height: 22),
                        _sectionTitle('Service topology',
                            'LIVE DEPENDENCY MAP'),
                        const SizedBox(height: 12),
                        _topology(compact),
                        const SizedBox(height: 22),
                        _sectionTitle(
                            'Service inventory', '$healthy HEALTHY · $failures DEGRADED'),
                        const SizedBox(height: 12),
                        _serviceTable(compact),
                        const SizedBox(height: 22),
                        _sectionTitle(
                            'Recent incidents', '$totalIncidents EVENTS IN SESSION'),
                        const SizedBox(height: 12),
                        _incidents(),
                        const SizedBox(height: 26),
                        Center(
                          child: Text(
                            'PULSEMESH  /  LOCAL DEMO TELEMETRY  /  NO EXTERNAL SERVICES',
                            style: TextStyle(
                                color: muted.withValues(alpha: 0.7),
                                fontSize: 10,
                                letterSpacing: 1.3),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar() => Container(
        width: 224,
        decoration: const BoxDecoration(
          color: Color(0xFF0B1019),
          border: Border(right: BorderSide(color: border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 24, 12, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 37,
                height: 37,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [cyan, Color(0xFF6776FF)]),
                    borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.graphic_eq,
                    color: bg, size: 25),
              ),
              const SizedBox(width: 10),
              const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PulseMesh',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800)),
                    Text('OBSERVABILITY',
                        style: TextStyle(
                            color: muted,
                            fontSize: 9,
                            letterSpacing: 1.6)),
                  ]),
            ]),
            const SizedBox(height: 36),
            const Text('WORKSPACE',
                style: TextStyle(
                    color: muted, fontSize: 10, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            _navItem(0, Icons.grid_view_rounded, 'Overview'),
            _navItem(1, Icons.hub_outlined, 'Services'),
            _navItem(2, Icons.timeline_rounded, 'Metrics'),
            _navItem(3, Icons.warning_amber_rounded, 'Incidents'),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: panel,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(12)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.circle, size: 8, color: green),
                    SizedBox(width: 7),
                    Text('LOCAL SIMULATOR',
                        style: TextStyle(fontSize: 10, color: green)),
                  ]),
                  SizedBox(height: 8),
                  Text('Telemetry is generated locally.',
                      style: TextStyle(color: muted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _navItem(int index, IconData icon, String label) {
    final active = selectedNav == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => setState(() => selectedNav = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF152834) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: active
                ? Border.all(color: const Color(0xFF244650))
                : null,
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: active ? cyan : muted),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: active ? Colors.white : muted,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ]),
        ),
      ),
    );
  }

  Widget _topbar(bool compact) => Container(
        height: 66,
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 28),
        decoration: const BoxDecoration(
            color: Color(0xFF0B1019),
            border: Border(bottom: BorderSide(color: border))),
        child: Row(children: [
          if (compact)
            const Icon(Icons.graphic_eq, color: cyan, size: 24),
          const Text('Infrastructure',
              style: TextStyle(color: muted, fontSize: 12)),
          const Icon(Icons.chevron_right, size: 17, color: muted),
          const Text('Overview',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
                color: const Color(0xFF10261F),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFF20523D))),
            child: const Row(children: [
              Icon(Icons.circle, size: 7, color: green),
              SizedBox(width: 7),
              Text('ALL SYSTEMS',
                  style: TextStyle(
                      color: green, fontSize: 10, letterSpacing: 0.5)),
            ]),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: paused ? 'Resume live updates' : 'Pause live updates',
            onPressed: () => setState(() => paused = !paused),
            icon: Icon(paused ? Icons.play_arrow : Icons.pause,
                color: muted, size: 20),
          ),
        ]),
      );

  Widget _heading(bool compact) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text('System overview',
                  style: TextStyle(
                      fontSize: compact ? 25 : 31,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                  color: panel,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.calendar_today_outlined, size: 13, color: muted),
                SizedBox(width: 7),
                Text('Last 5 minutes',
                    style: TextStyle(color: muted, fontSize: 11)),
              ]),
            ),
          ]),
          const SizedBox(height: 7),
          const Text(
              'Monitor service health, traffic, and distributed-system behavior.',
              style: TextStyle(color: muted, fontSize: 12)),
        ],
      );

  Widget _metrics(double width) {
    final items = [
      _MetricData('REQUESTS / SESSION', _format(totalRequests),
          '+12.8%', Icons.swap_vert_rounded, cyan),
      _MetricData('AVG. LATENCY', '${overallLatency.toStringAsFixed(0)} ms',
          'P50 approx.', Icons.bolt, amber),
      _MetricData('ERROR RATE',
          '${services.fold<double>(0, (s, x) => s + x.errors) / services.length ~/ 1}%',
          'Simulated', Icons.error_outline, red),
      _MetricData('HEALTHY SERVICES',
          '${services.where((s) => s.status == 'HEALTHY').length}/${services.length}',
          'Service status', Icons.check_circle_outline, green),
    ];
    final columns = width > 1200 ? 4 : width > 720 ? 2 : 1;
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: columns == 1 ? 3.1 : columns == 2 ? 2.0 : 1.65,
      children: items.map(_metricCard).toList(),
    );
  }

  Widget _metricCard(_MetricData data) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
            color: panel,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(13)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(data.label,
                  style: const TextStyle(
                      color: muted, fontSize: 9, letterSpacing: 1.1)),
            ),
            Icon(data.icon, color: data.color, size: 18),
          ]),
          const Spacer(),
          Text(data.value,
              style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7)),
          const SizedBox(height: 6),
          Text(data.caption,
              style: TextStyle(color: data.color, fontSize: 10)),
        ]),
      );

  Widget _latencyPanel() => _panel(
        title: 'Request latency',
        subtitle: 'Rolling average · milliseconds',
        trailing: const Text('LIVE',
            style: TextStyle(color: cyan, fontSize: 10, letterSpacing: 1.4)),
        child: SizedBox(
          height: 205,
          width: double.infinity,
          child: CustomPaint(
            painter: _ChartPainter(latencyHistory),
          ),
        ),
      );

  Widget _healthPanel() => _panel(
        title: 'Service health',
        subtitle: 'Current health distribution',
        trailing: const Icon(Icons.more_horiz, color: muted),
        child: Column(children: [
          const SizedBox(height: 12),
          Row(children: [
            SizedBox(
              width: 102,
              height: 102,
              child: CustomPaint(
                painter: _DonutPainter(
                    services.where((s) => s.status == 'HEALTHY').length,
                    services.length),
                child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                            '${services.where((s) => s.status == 'HEALTHY').length}',
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w800)),
                        const Text('HEALTHY',
                            style: TextStyle(color: muted, fontSize: 8)),
                      ]),
                ),
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(children: [
                _legend(green, 'Healthy',
                    services.where((s) => s.status == 'HEALTHY').length),
                const SizedBox(height: 15),
                _legend(red, 'Degraded',
                    services.where((s) => s.status != 'HEALTHY').length),
                const SizedBox(height: 15),
                _legend(muted, 'Total services', services.length),
              ]),
            ),
          ]),
          const SizedBox(height: 15),
          const Divider(color: border),
          const SizedBox(height: 8),
          const Row(children: [
            Icon(Icons.shield_outlined, size: 16, color: green),
            SizedBox(width: 8),
            Expanded(
              child: Text('Health checks running',
                  style: TextStyle(color: muted, fontSize: 11)),
            ),
            Text('2s interval',
                style: TextStyle(color: green, fontSize: 10)),
          ]),
        ]),
      );

  Widget _legend(Color color, String text, int count) => Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(color: muted, fontSize: 11))),
        Text('$count',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      ]);

  Widget _sectionTitle(String title, String tag) => Row(children: [
        Expanded(
            child: Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        Text(tag,
            style: const TextStyle(
                color: muted, fontSize: 9, letterSpacing: 1)),
      ]);

  Widget _topology(bool compact) => _panel(
        title: 'Service dependency graph',
        subtitle: 'Click a service in the inventory below to inject a failure',
        trailing: const Icon(Icons.account_tree_outlined,
            color: cyan, size: 18),
        child: SizedBox(
          height: compact ? 165 : 190,
          child: CustomPaint(
            painter: _TopologyPainter(services),
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: services.map((s) {
                  final bad = s.status != 'HEALTHY';
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: bad
                          ? const Color(0xFF321B29)
                          : const Color(0xFF122A28),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: bad ? red : green),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(s.icon, size: 14, color: bad ? red : green),
                      const SizedBox(width: 6),
                      Text(s.name,
                          style: TextStyle(
                              fontSize: compact ? 9 : 10,
                              color: Colors.white)),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );

  Widget _serviceTable(bool compact) => _panel(
        title: 'Services',
        subtitle: 'Live simulated service metrics',
        trailing: const Icon(Icons.filter_list, color: muted),
        child: Column(
          children: services.map((s) {
            final bad = s.status != 'HEALTHY';
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration:
                  const BoxDecoration(border: Border(bottom: BorderSide(color: border))),
              child: Row(children: [
                Container(
                  width: 33,
                  height: 33,
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A2533),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(s.icon, size: 17, color: bad ? red : cyan),
                ),
                const SizedBox(width: 11),
                Expanded(
                  flex: 4,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(s.description,
                            style: const TextStyle(color: muted, fontSize: 9)),
                      ]),
                ),
                if (!compact) ...[
                  Expanded(
                    flex: 2,
                    child: Text('${s.latency.toStringAsFixed(0)} ms',
                        style: const TextStyle(
                            fontFeatures: [],
                            fontSize: 11,
                            color: muted)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(_format(s.requests),
                        style: const TextStyle(fontSize: 11, color: muted)),
                  ),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                      color: bad
                          ? const Color(0xFF351B29)
                          : const Color(0xFF102A22),
                      borderRadius: BorderRadius.circular(5)),
                  child: Text(s.status,
                      style: TextStyle(
                          color: bad ? red : green,
                          fontSize: 8,
                          letterSpacing: 0.4)),
                ),
                const SizedBox(width: 5),
                IconButton(
                  tooltip: s.forcedFailure
                      ? 'Recover service'
                      : 'Inject simulated failure',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => toggleFailure(s),
                  icon: Icon(
                      s.forcedFailure
                          ? Icons.restart_alt
                          : Icons.bug_report_outlined,
                      color: s.forcedFailure ? green : muted,
                      size: 17),
                ),
              ]),
            );
          }).toList(),
        ),
      );

  Widget _incidents() {
    final failed = services.where((s) => s.forcedFailure).toList();
    if (failed.isEmpty) {
      return _panel(
        title: 'No active incidents',
        subtitle: 'The simulator has no manually injected failures.',
        child: const Row(children: [
          Icon(Icons.check_circle_outline, color: green, size: 20),
          SizedBox(width: 12),
          Expanded(
              child: Text('All monitored services are operational.',
                  style: TextStyle(color: muted, fontSize: 12))),
          Text('RESOLVED',
              style: TextStyle(color: green, fontSize: 9, letterSpacing: 1)),
        ]),
      );
    }
    return Column(
      children: failed.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _panel(
            title: 'Elevated errors: ${s.name}',
            subtitle:
                'Simulated failure · ${s.latency.toStringAsFixed(0)} ms latency',
            trailing: const Icon(Icons.warning_amber, color: red),
            child: Row(children: [
              const Icon(Icons.error_outline, color: red, size: 19),
              const SizedBox(width: 9),
              const Expanded(
                  child: Text('Failure injection is active in the local demo.',
                      style: TextStyle(color: muted, fontSize: 11))),
              TextButton(
                onPressed: () => toggleFailure(s),
                child: const Text('Recover'),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    Widget? trailing,
    required Widget child,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: panel,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(13)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700))),
            if (trailing != null) trailing,
          ]),
          const SizedBox(height: 5),
          Text(subtitle,
              style: const TextStyle(color: muted, fontSize: 10)),
          const SizedBox(height: 15),
          child,
        ]),
      );

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _MetricData {
  const _MetricData(
      this.label, this.value, this.caption, this.icon, this.color);
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0;
    const right = 8.0;
    const top = 12.0;
    const bottom = 22.0;
    final chart = Rect.fromLTRB(
        left, top, size.width - right, size.height - bottom);

    final gridPaint = Paint()
      ..color = border
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(color: muted, fontSize: 9);
    for (int i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final label = TextPainter(
          text: TextSpan(text: '${200 - i * 50}', style: labelStyle),
          textDirection: TextDirection.ltr)
        ..layout();
      label.paint(canvas, Offset(0, y - 5));
    }
    if (values.length < 2) return;
    final minV = math.max(0, values.reduce(math.min) - 25);
    final maxV = values.reduce(math.max) + 25;
    final range = math.max(1.0, maxV - minV);
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = chart.left + chart.width * i / (values.length - 1);
      final y = chart.bottom -
          ((values[i] - minV) / range).clamp(0.0, 1.0) * chart.height;
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, chart.bottom)
      ..lineTo(points.first.dx, chart.bottom)
      ..close();
    canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            colors: [cyan.withValues(alpha: 0.24), cyan.withValues(alpha: 0.0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(chart));
    canvas.drawPath(
        path,
        Paint()
          ..color = cyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
         final labelIndices = <int>[
      0,
      values.length ~/ 2,
      values.length - 1,
    ];

    final labelTexts = <String>[
      'NOW - 58s',
      'NOW - 30s',
      'NOW',
    ];

    for (int j = 0; j < labelIndices.length; j++) {
      final i = labelIndices[j];

      if (i < 0 || i >= points.length) continue;

      final label = TextPainter(
        text: TextSpan(
          text: labelTexts[j],
          style: const TextStyle(
            color: muted,
            fontSize: 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      label.paint(
        canvas,
        Offset(
          points[i].dx - label.width / 2,
          chart.bottom + 7,
        ),
      );
    }

  }
  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.healthy, this.total);
  final int healthy;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..color = const Color(0xFF273244)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    final progress = Paint()
      ..color = green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(8), -math.pi / 2, math.pi * 2, false, base);
    canvas.drawArc(rect.deflate(8), -math.pi / 2,
        math.pi * 2 * healthy / total, false, progress);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      healthy != oldDelegate.healthy || total != oldDelegate.total;
}

class _TopologyPainter extends CustomPainter {
  _TopologyPainter(this.services);
  final List<ServiceNode> services;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cyan.withValues(alpha: 0.28)
      ..strokeWidth = 1.2;
    final center = Offset(size.width / 2, size.height / 2);
    final nodes = [
      Offset(size.width * 0.5, size.height * 0.15),
      Offset(size.width * 0.18, size.height * 0.35),
      Offset(size.width * 0.82, size.height * 0.35),
      Offset(size.width * 0.28, size.height * 0.8),
      Offset(size.width * 0.72, size.height * 0.8),
    ];
    for (final p in nodes) {
      canvas.drawLine(center, p, paint);
    }
    for (int i = 0; i < nodes.length; i++) {
      final bad = services[i].status != 'HEALTHY';
      canvas.drawCircle(
          nodes[i],
          4,
          Paint()..color = bad ? red : green);
    }
  }

  @override
  bool shouldRepaint(covariant _TopologyPainter oldDelegate) => true;
}
