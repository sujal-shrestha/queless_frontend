import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:queless_app/viewmodels/profile_viewmodel.dart';

import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/venue_viewmodel.dart';

import '../booking/select_service_screen.dart';
import '../history/booking_history_screen.dart';
import '../../viewmodels/booking_history_viewmodel.dart';
import '../profile/profile_screen.dart';

// ✅ NEW: your real queue screen
import '../queue/live_queue_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const primary = Color(0xFF65BF61);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().loadHome();
    });
  }

  void _goToBookingTab() {
    setState(() => _currentIndex = 1);
    context.read<VenueViewModel>().loadVenues();
  }

  void _goToQueueTab() {
    setState(() => _currentIndex = 2);
  }

  void _onTabTap(int index) {
    debugPrint('[HOME] tab tapped index=$index');

    setState(() => _currentIndex = index);

    if (index == 0) {
      debugPrint('[HOME] calling loadHome');
      context.read<HomeViewModel>().loadHome();
    }
    if (index == 1) {
      debugPrint('[HOME] calling loadVenues');
      context.read<VenueViewModel>().loadVenues();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _HomeTab(
              primary: primary,
              onBook: _goToBookingTab,
              onQueue: _goToQueueTab, // ✅ new
            ),

            // ✅ BOOK TAB
            const SelectServiceScreen(isTab: true),

            // ✅ QUEUE TAB (REAL PAGE)
            LiveQueueView(
              onGoToBooking: _goToBookingTab,
            ),

            // ✅ HISTORY TAB
            ChangeNotifierProvider(
              create: (_) => BookingHistoryViewModel(),
              child: const BookingHistoryScreen(),
            ),

            // ✅ PROFILE TAB
            ChangeNotifierProvider(
              create: (_) => ProfileViewModel(),
              child: const ProfileScreen(),
            ),

          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        onTap: _onTabTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.event_note_rounded), label: 'Book'),
          BottomNavigationBarItem(icon: Icon(Icons.query_stats_rounded), label: 'Queue'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final Color primary;
  final VoidCallback onBook;
  final VoidCallback onQueue;

  const _HomeTab({
    required this.primary,
    required this.onBook,
    required this.onQueue,
  });

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeViewModel>();

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF65BF61), Color(0xFF4BAA47)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back,', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      SizedBox(height: 4),
                      Text(
                        'User',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => context.read<HomeViewModel>().loadHome(),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _TopStatCard(
                    label: 'Appointments',
                    value: home.isLoading ? '...' : home.appointmentsCount.toString(),
                    icon: Icons.event_available_rounded,
                  ),
                  const SizedBox(width: 12),
                  _TopStatCard(
                    label: 'Queue Number',
                    value: home.isLoading ? '...' : home.queueNumber,
                    icon: Icons.confirmation_number_rounded,
                  ),
                  const SizedBox(width: 12),
                  _TopStatCard(
                    label: 'Est. Wait',
                    value: home.isLoading ? '...' : home.estWait,
                    icon: Icons.access_time_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (home.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      home.error!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),

                // Active booking card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFB9E4C9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F9ED),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              home.appointmentsCount > 0 ? 'Active' : 'No Booking',
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.monitor_heart_rounded, color: primary),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Text(home.activeTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(home.activeSubtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),

                      if (home.activeDateText.isNotEmpty || home.activeTimeText.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(home.activeDateText, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(width: 16),
                            const Icon(Icons.access_time_rounded, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(home.activeTimeText, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ],

                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6FB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _QueueInfoItem(title: 'Your Queue Number', value: home.queueNumber)),
                            const SizedBox(width: 12),
                            Expanded(child: _QueueInfoItem(title: 'People Ahead', value: home.peopleAhead)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: home.appointmentsCount == 0 ? onBook : onQueue,
                          child: Text(home.appointmentsCount == 0 ? 'Book Now' : 'View Live Queue'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _QuickActionCard(
                      icon: Icons.event_available_rounded,
                      label: 'Book Appointment',
                      onTap: onBook,
                    ),
                    const SizedBox(width: 12),
                    _QuickActionCard(
                      icon: Icons.query_stats_rounded,
                      label: 'Queue Status',
                      onTap: onQueue, // ✅ now works
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TopStatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _QueueInfoItem extends StatelessWidget {
  final String title;
  final String value;

  const _QueueInfoItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickActionCard({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: const Color(0xFF65BF61)),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
