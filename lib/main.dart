import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '570712793802-jdh0oans9k8r2o70o040mc39dt8k7to5.apps.googleusercontent.com',
    scopes: [
      'https://www.googleapis.com/auth/spreadsheets.readonly',
      'https://www.googleapis.com/auth/drive.readonly',
    ],
  );

  List<drive.File>? _trips;
  bool _isLoading = false;
  String? _error;

  static const List<List<Color>> _coverGradients = [
    [Color(0xFF1A4A3A), Color(0xFF2A7A5F), Color(0xFF3ABFA0)],
    [Color(0xFF2A1A4A), Color(0xFF5A3A8A), Color(0xFF8A6FD0)],
    [Color(0xFF4A1A1A), Color(0xFF8A3A30), Color(0xFFE86050)],
    [Color(0xFF1A2A4A), Color(0xFF2A5A8A), Color(0xFF4A9EE8)],
    [Color(0xFF3A2A10), Color(0xFF8A6A20), Color(0xFFE8A838)],
  ];

  Future<void> _sync() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _isLoading = false);
        return;
      }
      final client = await _googleSignIn.authenticatedClient();
      if (client == null) throw Exception('Auth failed');
      final driveApi = drive.DriveApi(client);
      final folders = await driveApi.files.list(
        q: "name = 'Trip' and mimeType = 'application/vnd.google-apps.folder'",
      );
      if (folders.files == null || folders.files!.isEmpty) {
        throw Exception("No 'Trip' folder found in Google Drive.");
      }
      final folderId = folders.files!.first.id;
      final files = await driveApi.files.list(
        q: "'$folderId' in parents and mimeType = 'application/vnd.google-apps.spreadsheet'",
      );
      setState(() => _trips = files.files ?? []);
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
            child: _ListHeader(onSync: _sync, isLoading: _isLoading),
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
                        name: trip.name ?? 'Untitled',
                        gradient: gradient,
                        index: index,
                        onTap: () => Navigator.push(
                          context,
                          _slideRoute(
                            ItineraryScreen(
                              spreadsheetId: trip.id!,
                              tripName: trip.name ?? 'Itinerary',
                              gradient: gradient,
                              googleSignIn: _googleSignIn,
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
          if (_trips == null && !_isLoading)
            SliverFillRemaining(
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
  const _ListHeader({required this.onSync, required this.isLoading});

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
            'Sync your itineraries from\nGoogle Drive to get started.',
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
                  Text('Sync from Google Drive',
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
  final List<Color> gradient;
  final VoidCallback onTap;
  final int index;
  const _TripCard(
      {required this.name,
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
              bottom: 18,
              left: 18,
              right: 60,
              child: Text(
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
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Itinerary Screen ─────────────────────────────────────────────────────────

class ItineraryScreen extends StatefulWidget {
  final String spreadsheetId;
  final String tripName;
  final List<Color> gradient;
  final GoogleSignIn googleSignIn;

  const ItineraryScreen({
    super.key,
    required this.spreadsheetId,
    required this.tripName,
    required this.gradient,
    required this.googleSignIn,
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
    _tripFuture = _fetchTrip();
  }

  Future<Trip> _fetchTrip() async {
    final client = await widget.googleSignIn.authenticatedClient();
    if (client == null) throw Exception('Not authenticated');
    final api = sheets.SheetsApi(client);
    final response = await api.spreadsheets.values.get(
      widget.spreadsheetId,
      'Sheet1!A2:H100',
    );
    final rows = response.values ?? [];
    if (rows.isEmpty) throw Exception('Spreadsheet is empty');

    Map<String, List<Event>> dayEventsMap = {};
    Map<String, List<String>> lodgingMap = {};
    Set<String> daysOrder = {};
    Map<String, Set<String>> locationMap = {};

    for (var row in rows) {
      if (row.length < 5) continue;
      String day = row[0].toString();
      String date = row[1].toString();
      String time = row[2].toString();
      String title = row[3].toString();
      String type = row[4].toString();
      String loc = row.length > 5 ? row[5].toString() : "";
      
      String dayKey = "$day|$date";
      daysOrder.add(dayKey);
      
      if (loc.isNotEmpty) {
        locationMap.putIfAbsent(dayKey, () => {}).add(loc);
      }
      String addr = row.length > 6 ? row[6].toString() : "";
      String note = row.length > 7 ? row[7].toString() : "";

      if (type.toLowerCase() == 'lodging') {
        lodgingMap[dayKey] = [title, addr];
      } else {
        dayEventsMap
            .putIfAbsent(dayKey, () => [])
            .add(Event(time, title, type, loc, addr, note));
      }
    }

    List<String> sortedDays = daysOrder.toList()..sort();
    List<TripDay> tripDays = sortedDays.map((key) {
      var parts = key.split('|');
      var lodgingData = lodgingMap[key] ?? ['', ''];
      
      return TripDay(
        date: parts[1],
        lodgingTitle: lodgingData[0],
        lodgingAddress: lodgingData[1],
        locations: locationMap[key] ?? {},
        events: dayEventsMap[key] ?? [],
      );
    }).toList();

    return Trip(
        id: widget.spreadsheetId, name: widget.tripName, days: tripDays);
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
                tripName: widget.tripName,
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
    final query = parts.isNotEmpty ? parts.last : 'travel';
    try {
      final url = Uri.parse('https://api.unsplash.com/search/photos?query=$query&client_id=kBduwH2JVZAUVQ-Y_6gHJJJJguTjibCMy3GDis59FpY&per_page=1');
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
    setState(() => _weatherData = []);

    for (String loc in widget.day.locations) {
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
            final country = res['country'];
            
            final weatherUrl = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code&temperature_unit=fahrenheit');
            final weatherResponse = await http.get(weatherUrl);
            
            if (weatherResponse.statusCode == 200 && mounted) {
              final data = json.decode(weatherResponse.body);
              final current = data['current'];
              setState(() {
                _weatherData.add({
                  'city': city,
                  'country': country,
                  'temp': (current['temperature_2m'] as num).toDouble(),
                  'code': current['weather_code'].toString()
                });
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Weather error for $loc: $e');
      }
    }
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.day.date,
                style: const TextStyle(
                  fontSize: 24,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _weatherData.map((w) => _WeatherChip(
            city: w['city'],
            country: w['country'],
            tempF: w['temp'],
            icon: w['code'],
          )).toList(),
        ),
        const SizedBox(height: 20),
        if (widget.day.lodgingTitle.isNotEmpty) ...[
          _LodgingCard(
              title: widget.day.lodgingTitle,
              address: widget.day.lodgingAddress),
          const SizedBox(height: 28),
        ],
        const Row(
          children: [
            _SectionLabel('SCHEDULE'),
            SizedBox(width: 12),
            Expanded(child: Divider(color: AppColors.cardBorder)),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(
          widget.day.events.length,
          (i) => _EventCard(
            event: widget.day.events[i],
            originAddress: origins[i],
          ),
        ),
      ],
    );
  }
}

// ─── Weather Chip ─────────────────────────────────────────────────────────────

class _WeatherChip extends StatelessWidget {
  final String city;
  final String country;
  final double tempF;
  final String icon;
  const _WeatherChip(
      {required this.city, required this.country, required this.tempF, required this.icon});

  String _emoji(String code) {
    final c = int.parse(code);
    if (c == 0) return '☀️';
    if (c <= 3) return '⛅';
    if (c <= 48) return '🌫️';
    if (c <= 67) return '🌧️';
    if (c <= 77) return '❄️';
    if (c <= 99) return '⛈️';
    return '🌡️';
  }
  
  String _desc(String code) {
    final c = int.parse(code);
    if (c == 0) return "Sunny";
    if (c <= 3) return "Cloudy";
    if (c <= 48) return "Foggy";
    if (c <= 67) return "Rain";
    if (c <= 77) return "Snow";
    if (c <= 99) return "Thunderstorm";
    return "Weather";
  }

  @override
  Widget build(BuildContext context) {
    final tempC = ((tempF - 32) * 5 / 9).round();
    return Container(
      width: 120,
      height: 130, // Increased height slightly to accommodate content
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_emoji(icon), style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(
            '${tempF.round()}°F',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            _desc(icon),
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.teal,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            city,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.muted,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Lodging Card ─────────────────────────────────────────────────────────────

class _LodgingCard extends StatelessWidget {
  final String title;
  final String address;
  const _LodgingCard({required this.title, required this.address});

  Future<void> _launchMaps(String addr) async {
    final uri = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amber.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.amberGlow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.amber.withOpacity(0.3)),
            ),
            child: const Icon(Icons.bed_rounded,
                color: AppColors.amber, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TONIGHT\'S STAY',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.5,
                    color: AppColors.amber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: () => _launchMaps(address),
                    child: Text(
                      address,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.blue.withOpacity(0.85),
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.blue.withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.muted, size: 20),
        ],
      ),
    );
  }
}

// ─── Event Card ───────────────────────────────────────────────────────────────

class _EventCard extends StatefulWidget {
  final Event event;
  final String originAddress;
  const _EventCard({required this.event, required this.originAddress});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  String? _duration;
  static const String _mapsApiKey =
      "AIzaSyBchw8wI1aCaPqXAY9C45vcszNd1eylL10";

  @override
  void initState() {
    super.initState();
    if (widget.originAddress.isNotEmpty &&
        widget.event.address.isNotEmpty) {
      _fetchTravelTime();
    }
  }

  Future<void> _fetchTravelTime() async {
    final t = widget.event.type.toLowerCase();
    final mode = t.contains('transit') ? 'transit' : 'driving';
    final targetUrl =
        'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=${Uri.encodeComponent(widget.originAddress)}'
        '&destinations=${Uri.encodeComponent(widget.event.address)}'
        '&mode=$mode'
        '&key=$_mapsApiKey';
    final proxyUrl = Uri.parse('https://corsproxy.io/?$targetUrl');

    try {
      final response = await http.get(proxyUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final rows = data['rows'] as List<dynamic>?;
        if (rows != null && rows.isNotEmpty) {
          final elements = rows[0]['elements'] as List<dynamic>;
          if (elements.isNotEmpty &&
              elements[0]['status'] == 'OK') {
            final durationText =
                elements[0]['duration']['text'] as String;
            if (mounted) {
              setState(() => _duration = durationText);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _launchMaps(String address) async {
    final uri = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.event.type.toLowerCase();
    IconData icon;
    Color accent;
    Color bg;
    if (t.contains('driving')) {
      icon = Icons.directions_car_rounded;
      accent = AppColors.inkSoft;
      bg = AppColors.card;
    } else if (t.contains('dining')) {
      icon = Icons.restaurant_rounded;
      accent = AppColors.amber;
      bg = AppColors.amberGlow;
    } else if (t.contains('activity')) {
      icon = Icons.explore_rounded;
      accent = AppColors.teal;
      bg = AppColors.tealGlow;
    } else if (t.contains('transit')) {
      icon = Icons.directions_transit_rounded;
      accent = AppColors.blue;
      bg = AppColors.blueGlow;
    } else if (t.contains('flight')) {
      icon = Icons.flight_rounded;
      accent = AppColors.violet;
      bg = AppColors.violetGlow;
    } else {
      icon = Icons.radio_button_checked_rounded;
      accent = AppColors.teal;
      bg = AppColors.tealGlow;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withOpacity(0.25)),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.event.time,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          if (_duration != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.blueGlow,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppColors.blue.withOpacity(0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.navigation_rounded,
                                      size: 10, color: AppColors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    _duration!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.blue,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.event.title,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      if (widget.event.address.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        GestureDetector(
                          onTap: () => _launchMaps(widget.event.address),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 12,
                                  color: AppColors.blue),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  widget.event.address,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.blue.withOpacity(0.85),
                                    decoration: TextDecoration.underline,
                                    decorationColor:
                                        AppColors.blue.withOpacity(0.4),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.event.note.isNotEmpty)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border(
                  top: BorderSide(color: AppColors.cardBorder),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      size: 13, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.event.note,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
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
}

// ─── Loading & Error ──────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                  color: AppColors.teal, strokeWidth: 2),
            ),
            SizedBox(height: 20),
            Text('Loading itinerary…',
                style:
                    TextStyle(color: AppColors.muted, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.coralGlow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    size: 30, color: AppColors.coral),
              ),
              const SizedBox(height: 20),
              const Text(
                'Couldn\'t load itinerary',
                style: TextStyle(
                    fontSize: 18,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.muted, height: 1.6),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded,
                          color: AppColors.inkSoft, size: 16),
                      SizedBox(width: 8),
                      Text('Go back',
                          style: TextStyle(
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w500)),
                    ],
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