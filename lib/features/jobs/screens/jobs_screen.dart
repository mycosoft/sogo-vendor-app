import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../requests/screens/request_details_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  JobsScreenState createState() => JobsScreenState();
}

class JobsScreenState extends State<JobsScreen> {
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      final res = await providerApi.availableJobs();
      final data = res['data'];
      if (data is Map && data['items'] is List)
        return List<Map<String, dynamic>>.from(data['items'] as List);
      if (data is Map && data['data'] is List)
        return List<Map<String, dynamic>>.from(data['data'] as List);
      if (data is List) return List<Map<String, dynamic>>.from(data);
      return const [];
    } catch (_) {
      // Offline or unverified - show the empty state instead of an error.
      return const [];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  /// Called by the tab shell every time the Jobs tab is selected, so the
  /// list reflects the current online status without waiting for a timer.
  Future<void> refresh() => _refresh();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Available jobs')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError)
              return Center(child: Text(snapshot.error.toString()));
            return const Center(child: CircularProgressIndicator());
          }
          final jobs = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: jobs.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Icon(Icons.work_outline,
                          size: 48, color: SogoColors.textMuted),
                      SizedBox(height: SogoSpacing.md),
                      Center(
                        child: Text(
                          'No jobs available right now.\nGo online from the dashboard to receive job requests.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: SogoColors.textSecondary),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(SogoSpacing.lg),
                    itemCount: jobs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: SogoSpacing.md),
                    itemBuilder: (context, i) => SogoCard(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RequestDetailsScreen(
                              request: jobs[i], readOnly: false))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: Text('#${jobs[i]['reference'] ?? ''}',
                                      style: SogoText.bodySm.copyWith(
                                          color: SogoColors.textMuted))),
                              SogoBadge(label: 'AVAILABLE'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                              '${jobs[i]['category']?['name'] ?? 'Service request'}',
                              style: SogoText.headlineMd),
                          const SizedBox(height: 4),
                          Text('${jobs[i]['pickup_address'] ?? ''}',
                              style: SogoText.bodySm
                                  .copyWith(color: SogoColors.textSecondary)),
                          const SizedBox(height: SogoSpacing.md),
                          SogoButton(
                              label: 'Open job',
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => RequestDetailsScreen(
                                          request: jobs[i], readOnly: false)))),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
