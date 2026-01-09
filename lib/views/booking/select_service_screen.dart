import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/venue_viewmodel.dart';
import 'booking_flow_args.dart';
import 'widgets/booking_progress_bar.dart';

const kGreen = Color(0xFF65BF61);

class SelectServiceScreen extends StatefulWidget {
  const SelectServiceScreen({super.key});

  @override
  State<SelectServiceScreen> createState() => _SelectServiceScreenState();
}

class _SelectServiceScreenState extends State<SelectServiceScreen> {
  final _search = TextEditingController();
  String? selectedVenueId;
  String? selectedVenueName;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<VenueViewModel>().loadVenues());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _continue() {
    if (selectedVenueId == null || selectedVenueName == null) return;

    final draft = BookingDraft(
      venueId: selectedVenueId!,
      venueName: selectedVenueName!,
    );

    Navigator.pushNamed(context, '/choose-branch', arguments: draft);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VenueViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: kGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Progress area like your UI
          Container(
            width: double.infinity,
            color: kGreen,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: const BookingProgressBar(step: 1),
          ),

          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Service',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search venue...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => vm.loadVenues(search: v),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: Builder(
              builder: (_) {
                if (vm.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (vm.error != null) {
                  return Center(child: Text(vm.error!));
                }
                if (vm.venues.isEmpty) {
                  return const Center(child: Text('No venues found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: vm.venues.length,
                  itemBuilder: (context, i) {
                    final v = vm.venues[i];
                    final isSelected = selectedVenueId == v.id;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedVenueId = v.id;
                          selectedVenueName = v.name;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? kGreen : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // ✅ Logo
                            Container(
                              width: 54,
                              height: 34,
                              alignment: Alignment.centerLeft,
                              child: v.logoUrl.isEmpty
                                  ? const Icon(Icons.apartment, color: kGreen)
                                  : Image.network(
                                      v.logoUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.apartment, color: kGreen),
                                    ),
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Text(
                                v.name,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),

                            if (isSelected)
                              const Icon(Icons.check_circle, color: kGreen),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  disabledBackgroundColor: kGreen.withOpacity(0.35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: selectedVenueId == null ? null : _continue,
                child: const Text('Continue'),
              ),
            ),
          )
        ],
      ),
    );
  }
}
