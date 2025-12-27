import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/venue_viewmodel.dart';

class SelectServiceScreen extends StatefulWidget {
  const SelectServiceScreen({super.key});

  @override
  State<SelectServiceScreen> createState() => _SelectServiceScreenState();
}

class _SelectServiceScreenState extends State<SelectServiceScreen> {
  final _search = TextEditingController();
  String? selectedVenueId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<VenueViewModel>().loadVenues();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VenueViewModel>();
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Book Appointment"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: const Color(0xFF7CD39A),
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          const Text(
            "Select Service",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: "Search venue...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                  return Center(child: Text("Error: ${vm.error}"));
                }
                if (vm.venues.isEmpty) {
                  return const Center(child: Text("No venues found"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: vm.venues.length,
                  itemBuilder: (context, i) {
                    final v = vm.venues[i];
                    final isSelected = selectedVenueId == v.id;

                    return GestureDetector(
                      onTap: () => setState(() => selectedVenueId = v.id),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? primary : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFEFF7F1),
                              child: Icon(Icons.apartment, color: Colors.green),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                v.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle,
                                  color: Colors.green),
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
                  backgroundColor: const Color(0xFF7CD39A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: selectedVenueId == null
                    ? null
                    : () {
                        // Next screen will be Choose Branch
                        Navigator.pushNamed(
                          context,
                          "/choose-branch",
                          arguments: selectedVenueId,
                        );
                      },
                child: const Text("Continue"),
              ),
            ),
          )
        ],
      ),
    );
  }
}
