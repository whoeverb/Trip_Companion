import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'trip_service.dart';

void main() => runApp(const TravelApp());

// ─── Theme ───────────────────────────────────────────────────────────────────

class AppColors {
  static const bg = Color(0xFF0F1117);
  static const surface = Color(0xFF181B24);
  static const card = Color(0xFF1E222E);
  static const cardBorder = Color(0xFF2A2F3E);
  static const ink = Color(0xFFF0EDE8);
  static const inkSoft = Color(0xFFB8B4AC);
  static const muted = Color(0xFF6B6880);

  static const amber = Color(0xFFE8A838);
  static const amberGlow = Color(0x22E8A838);
  static const amberLight = Color(0xFFF5D08A);

  static const teal = Color(0xFF2ABFAA);
  static const tealGlow = Color(0x222ABFAA);
  static const tealDark = Color(0xFF1A8A78);

  static const coral = Color(0xFFE8604A);
  static const coralGlow = Color(0x22E8604A);

  static const blue = Color(0xFF4A9EE8);
  static const blueGlow = Color(0x224A9EE8);

  static const violet = Color(0xFF8B6FE8);
  static const violetGlow = Color(0x228B6FE8);
}

// ─── Models ──────────────────────────────────────────────────────────────────

class Trip {
  final String id;
  final String name;
  final List<TripDay> days;
  Trip({required this.id, required this.name, required this.days});
}

class TripDay {
  final String date;
  final String lodgingTitle;
  final String lodgingAddress;
  final Set<String> locations;
  final List<Event> events;
  TripDay({
    required this.date,
    required this.lodgingTitle,
    required this.lodgingAddress,
    required this.locations,
    required this.events,
  });
}

class Event {
  final String time;
  final String title;
  final String type;
  final String location;
  final String address;
  final String note;
  Event(this.time, this.title, this.type, this.location, this.address,
      this.note);
}

// ─── App root ────────────────────────────────────────────────────────────────

class TravelApp extends StatelessWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'DM Sans',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.dark(
          primary: AppColors.teal,
          surface: AppColors.surface,
        ),
      ),
      home: const TripListScreen(),
    );
  }
}

// ─── Trip List Screen ─────────────────────────────────────────────────────────

class TripListScreen extends StatefulWidget {
  const TripListScreen({super.key});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  List<TripMeta>? _trips;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String? _error;
  String? _lastSynced;

  static const List<List<Color>> _coverGradients = [
    [Color(0xFF1A4A3A), Color(0xFF2A7A5F), Color(0xFF3ABFA0)],
    [Color(0xFF2A1A4A), Color(0xFF5A3A8A), Color(0xFF8A6FD0)],
    [Color(0xFF4A1A1A), Color(0xFF8A3A30), Color(0xFFE86050)],
    [Color(0xFF1A2A4A), Color(0xFF2A5A8A), Color(0xFF4A9EE8)],
    [Color(0xFF3A2A10), Color(0xFF8A6A20), Color(0xFFE8A838)],
  ];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      setState(() => _lastSynced = p.getString('last_synced'));
    });
    TripService.fetchIndex().then((trips) {
      if (mounted) setState(() { _trips = trips; _isInitialLoading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _isInitialLoading = false);
    });
  }

  Future<void> _sync() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final trips = await TripService.fetchIndex(forceRefresh: true);
      final now = DateTime.now().toIso8601String();
      SharedPreferences.getInstance().then((p) => p.setString('last_synced', now));
      setState(() {
        _trips = trips;
        _lastSynced = now;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _ListHeader(onSync: _sync, isLoading: _isLoading, lastSynced: _lastSynced),
          ),
          if (_error != null)
            SliverToBoxAdapter(child: _ErrorBanner(message: _error!)),
          if (_trips != null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 32, 24, 14),
                child: Row(
                  children: [
                    _SectionLabel('YOUR TRIPS'),
                    SizedBox(width: 12),
                    Expanded(child: Divider(color: AppColors.cardBorder)),
                  ],
                ),
              ),
            ),
          if (_trips != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final trip = _trips![index];
                    final gradient =
                        _coverGradients[index % _coverGradients.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _TripCard(
                        name: trip.displayName,
                        dateRange: (trip.startDate.isEmpty && trip.endDate.isEmpty)
                          ? ''
                          : trip.startDate == trip.endDate
                            ? trip.startDate
                            : '${trip.startDate} – ${trip.endDate}',
                        gradient: gradient,
                        index: index,
                        onTap: () => Navigator.push(
                          context,
                          _slideRoute(
                            ItineraryScreen(
                              meta: trip,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _trips!.length,
                ),
              ),
            ),
          if (_trips == null)
            _isInitialLoading
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                        child: CircularProgressIndicator(color: AppColors.teal)),
                  )
                : const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  ),
        ],
      ),
    );
  }

  PageRoute _slideRoute(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      );
}

// ─── List Header ─────────────────────────────────────────────────────────────

class _ListHeader extends StatelessWidget {
  final VoidCallback onSync;
  final bool isLoading;
  final String? lastSynced;
  const _ListHeader({required this.onSync, required this.isLoading, this.lastSynced});

  String _formatLastSynced(String? isoString) {
    if (isoString == null) return '';
    final last = DateTime.tryParse(isoString);
    if (last == null) return '';
    final diff = DateTime.now().difference(last);
    if (diff.inMinutes < 1) return 'Last synced: just now';
    if (diff.inMinutes < 60) return 'Last synced: ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'Last synced: ${diff.inHours} hours ago';
    return 'Last synced: ${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 32,
        left: 24,
        right: 24,
        bottom: 28,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.tealGlow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                ),
                child: const Text(
                  '✈  TRAVEL LOG',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: AppColors.teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Your\nJourneys',
            style: TextStyle(
              fontSize: 40,
              height: 1.1,
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 24),
          _SyncButton(onTap: onSync, isLoading: isLoading),
          if (lastSynced != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatLastSynced(lastSynced),
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 2,
          color: AppColors.muted,
          fontWeight: FontWeight.w600,
        ),
      );
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.tealGlow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.teal.withOpacity(0.2)),
            ),
            child: const Icon(Icons.flight_takeoff_rounded,
                size: 32, color: AppColors.teal),
          ),
          const SizedBox(height: 20),
          const Text(
            'No trips yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap Sync Trips to load your itineraries',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.muted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error Banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.coralGlow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.coral.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.coral, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, color: AppColors.coral),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sync Button ─────────────────────────────────────────────────────────────

class _SyncButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;
  const _SyncButton({required this.onTap, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black54),
                  ),
                  SizedBox(width: 10),
                  Text('Syncing…',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sync_rounded, size: 18, color: Colors.black),
                  SizedBox(width: 8),
                  Text('Sync Trips',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black)),
                ],
              ),
      ),
    );
  }
}

// ─── Trip Card ───────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final String name;
  final String dateRange;
  final List<Color> gradient;
  final VoidCallback onTap;
  final int index;
  const _TripCard(
      {required this.name,
      required this.dateRange,
      required this.gradient,
      required this.onTap,
      required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.5),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(Icons.arrow_outward_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  'TRIP ${index + 1}',
                  style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.5,
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 14,
              left: 18,
              right: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateRange,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white60,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Itinerary Screen ─────────────────────────────────────────────────────────

class ItineraryScreen extends StatefulWidget {
  final TripMeta meta;

  const ItineraryScreen({
    super.key,
    required this.meta,
  });

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  late Future<Trip> _tripFuture;
  int _selectedDay = 0;

  @override
  void initState() {
    super.initState();
    _tripFuture = TripService.fetchTrip(widget.meta);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FutureBuilder<Trip>(
        future: _tripFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(message: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const _LoadingView();
          }
          final trip = snapshot.data!;
          final day = trip.days[_selectedDay];

          final previousDayLodging =
              _selectedDay > 0 ? trip.days[_selectedDay - 1].lodgingAddress : '';

          return Column(
            children: [
              _ImageHeader(
                tripName: widget.meta.displayName,
                dayCount: trip.days.length,
              ),
              _DayNavBar(
                days: trip.days,
                selectedIndex: _selectedDay,
                onSelected: (i) => setState(() => _selectedDay = i),
              ),
              Expanded(
                child: _DayContent(
                  day: day,
                  firstEventOrigin: day.lodgingAddress.isNotEmpty
                      ? day.lodgingAddress
                      : previousDayLodging,
                  key: ValueKey(_selectedDay),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Image Header ──────────────────────────────────────────────────────────

class _ImageHeader extends StatefulWidget {
  final String tripName;
  final int dayCount;
  const _ImageHeader({required this.tripName, required this.dayCount});

  @override
  State<_ImageHeader> createState() => _ImageHeaderState();
}

class _ImageHeaderState extends State<_ImageHeader> {
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _fetchImage();
  }

  void _fetchImage() async {
    final parts = widget.tripName.split('_');
    final commonWords = {
      'trip', 'may', 'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
      'summer', 'winter', 'spring', 'fall'
    };
    final filtered = parts.where((p) {
      final lower = p.toLowerCase();
      if (int.tryParse(p) != null) return false;
      if (commonWords.contains(lower)) return false;
      return true;
    }).toList();
    
    final queryParts = filtered.length > 2 ? filtered.sublist(filtered.length - 2) : filtered;
    final query = queryParts.isEmpty ? 'travel landscape' : queryParts.join(' ');

    try {
      final url = Uri.parse('https://api.unsplash.com/search/photos?query=${Uri.encodeComponent(query)}&client_id=kBduwH2JVZAUVQ-Y_6gHJJJJguTjibCMy3GDis59FpY&per_page=1&orientation=landscape&content_filter=high&order_by=relevant');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          setState(() => _imageUrl = data['results'][0]['urls']['regular']);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _imageUrl != null 
            ? Image.network(
                _imageUrl!, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: AppColors.card),
              )
            : Container(color: AppColors.card),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.8),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 16,
            child: const _BackButton(),
          ),
          Positioned(
            bottom: 22,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.dayCount}-DAY ITINERARY',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white70,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.tripName,
                  style: const TextStyle(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 16),
      ),
    );
  }
}

// ─── Day Nav Bar ─────────────────────────────────────────────────────────────

class _DayNavBar extends StatefulWidget {
  final List<TripDay> days;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _DayNavBar(
      {required this.days,
      required this.selectedIndex,
      required this.onSelected});

  @override
  State<_DayNavBar> createState() => _DayNavBarState();
}

class _DayNavBarState extends State<_DayNavBar> {
  final ScrollController _sc = ScrollController();

  @override
  void didUpdateWidget(_DayNavBar old) {
    super.didUpdateWidget(old);
    if (widget.selectedIndex != old.selectedIndex) {
      final offset = widget.selectedIndex * 88.0 - 40;
      if (_sc.hasClients) {
        _sc.animateTo(
          offset.clamp(0.0, _sc.position.maxScrollExtent),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: AppColors.surface,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _sc,
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: widget.days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final selected = i == widget.selectedIndex;
                return GestureDetector(
                  onTap: () => widget.onSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.teal : AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            selected ? AppColors.teal : AppColors.cardBorder,
                      ),
                    ),
                    child: Text(
                      'Day ${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.black : AppColors.inkSoft,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
        ],
      ),
    );
  }
}

// ─── Day Content ─────────────────────────────────────────────────────────────

class _DayContent extends StatefulWidget {
  final TripDay day;
  final String firstEventOrigin;
  const _DayContent(
      {required this.day, required this.firstEventOrigin, super.key});

  @override
  State<_DayContent> createState() => _DayContentState();
}

class _DayContentState extends State<_DayContent> {
  List<Map<String, dynamic>> _weatherData = [];
  bool _weatherLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  @override
  void didUpdateWidget(covariant _DayContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day.locations != widget.day.locations) {
      _fetchWeather();
    }
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _weatherData = [];
      _weatherLoading = true;
    });

    final seenCities = <String>{};
    final uniqueLocations = <String>[];
    for (String loc in widget.day.locations) {
      final city = loc.split(',')[0].trim().toLowerCase();
      if (seenCities.add(city)) uniqueLocations.add(loc);
    }

    for (String loc in uniqueLocations) {
      String query = loc.split(',')[0].trim();
      try {
        final geoUrl = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(query)}&count=1&language=en&format=json');
        final geoResponse = await http.get(geoUrl);
        
        if (geoResponse.statusCode == 200) {
          final geoData = json.decode(geoResponse.body);
          if (geoData['results'] != null && (geoData['results'] as List).isNotEmpty) {
            final res = geoData['results'][0];
            final lat = res['latitude'];
            final lon = res['longitude'];
            final city = res['name'];
            final country = (res['country_code'] ?? '').toString().toLowerCase();
            
            final dt = DateTime.tryParse(widget.day.date);
            final tripDateStr = widget.day.date;
            DateTime? parsedDate;

            // Attempt to parse different date formats
            try {
                parsedDate = DateTime.parse(tripDateStr); // ISO format (YYYY-MM-DDTHH:MM:SS.sssZ)
            } catch (_) {
                try {
                    // Try parsing 'DayOfWeek Month Day, Year' format
                    final parts = tripDateStr.split(' ');
                    if (parts.length >= 3) {
                        final monthStr = parts[1];
                        final dayStr = parts[2].replaceAll(',', '');
                        final yearStr = parts[3];
                        
                        int month;
                        switch (monthStr.toLowerCase()) {
                            case 'jan': month = 1; break;
                            case 'feb': month = 2; break;
                            case 'mar': month = 3; break;
                            case 'apr': month = 4; break;
                            case 'may': month = 5; break;
                            case 'jun': month = 6; break;
                            case 'jul': month = 7; break;
                            case 'aug': month = 8; break;
                            case 'sep': month = 9; break;
                            case 'oct': month = 10; break;
                            case 'nov': month = 11; break;
                            case 'dec': month = 12; break;
                            default: month = -1; 
                        }
                        if (month != -1) {
                            parsedDate = DateTime.parse('$yearStr-$month-$dayStr');
                        }
                    }
                } catch (_) {
                    debugPrint("Could not parse date: $tripDateStr, using today's date for logic.");
                }
            }

            // Fallback to today's date if parsing failed
            parsedDate ??= DateTime.now();
            
            final tripDate = "${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}";
            final today = DateTime.now();
            final daysFromToday = parsedDate.difference(today).inDays;
            
            Uri? weatherUrl;
            if (daysFromToday < 0) {
                weatherUrl = Uri.parse('https://archive-api.open-meteo.com/v1/archive?latitude=$lat&longitude=$lon&daily=temperature_2m_max,temperature_2m_min,weather_code&temperature_unit=fahrenheit&timezone=auto&start_date=$tripDate&end_date=$tripDate');
            } else if (daysFromToday <= 16) {
                weatherUrl = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&daily=temperature_2m_max,temperature_2m_min,weather_code&temperature_unit=fahrenheit&timezone=auto&start_date=$tripDate&end_date=$tripDate');
            }

            if (weatherUrl == null) {
                setState(() {
                    _weatherData.add({
                        'city': city,
                        'country': country,
                        'tempMax': 0.0,
                        'tempMin': 0.0,
                        'code': '-1'
                    });
                });
                continue;
            }

            final weatherResponse = await http.get(weatherUrl);
            
            if (weatherResponse.statusCode == 200 && mounted) {
              final data = json.decode(weatherResponse.body);
              final daily = data['daily'];
              final tempMaxList = daily['temperature_2m_max'] as List?;
              final tempMinList = daily['temperature_2m_min'] as List?;
              final codeList = daily['weather_code'] as List?;

              if (tempMaxList == null || tempMaxList.isEmpty) continue;

              final tempMax = (tempMaxList[0] as num).toDouble();
              final tempMin = (tempMinList![0] as num).toDouble();
              final code = codeList![0].toString();

              setState(() {
                _weatherData.add({
                  'city': city,
                  'country': country,
                  'tempMax': tempMax,
                  'tempMin': tempMin,
                  'code': code
                });
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Weather error for $loc: $e');
      }
    }
    if (mounted) setState(() => _weatherLoading = false);
  }

  List<String> _buildOrigins() {
    final origins = <String>[];
    for (int i = 0; i < widget.day.events.length; i++) {
      if (i == 0) {
        origins.add(widget.firstEventOrigin);
      } else {
        origins.add(widget.day.events[i - 1].address);
      }
    }
    return origins;
  }

  @override
  Widget build(BuildContext context) {
    final origins = _buildOrigins();
    
    String displayDate = widget.day.date;
    try {
      final parts = widget.day.date.split(' ');
      if (parts.length >= 2) {
        final datePart = parts[1]; // e.g. "5/29/26"
        final dateParts = datePart.split('/');
        if (dateParts.length == 3) {
          final month = int.parse(dateParts[0]);
          final day = int.parse(dateParts[1]);
          final year = 2000 + int.parse(dateParts[2]);
          final dt = DateTime(year, month, day);
          const months = ['January','February','March','April','May','June',
            'July','August','September','October','November','December'];
          const weekdays = ['Monday','Tuesday','Wednesday','Thursday',
            'Friday','Saturday','Sunday'];
          displayDate = '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
        }
      }
    } catch (_) {}

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: