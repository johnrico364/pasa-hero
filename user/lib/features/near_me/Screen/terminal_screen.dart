import 'package:flutter/material.dart';
import '../../map/map.dart';

class TerminalScreen extends StatelessWidget {
  const TerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFEDF3F8),
        child: Column(
          children: [
            // Custom header with back button and title
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A8A),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Tamiya Terminal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the back button
                    ],
                  ),
                ),
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Map Section
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        height: 300,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            const MapWidget(),
                            // Red pin marker overlay (simplified representation)
                            Positioned(
                              bottom: 20,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: Color(0xFFC54742),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'View Terminal Location',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Active Buses at Terminal Section
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Active Buses at Terminal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),

                    // Active Bus Items
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _buildBusItem(
                            busTag: 'M1-04A',
                            busName: 'Bus M1-04A',
                            status: '4/5',
                            tagColor: const Color(0xFFFBB432),
                            statusColor: const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(height: 8),
                          _buildBusItem(
                            busTag: '21B',
                            busName: 'Bus 21B',
                            status: '4/5',
                            tagColor: const Color(0xFF508867),
                            statusColor: const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(height: 8),
                          _buildBusItem(
                            busTag: '13C',
                            busName: 'Bus 13C',
                            status: 'In-route',
                            tagColor: const Color(0xFFC54742),
                            statusColor: const Color(0xFF10B981),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Recent Arrivals & Departures Section
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Recent Arrivals & Departures',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),

                    // Recent Bus Items
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _buildBusItem(
                            busTag: 'M1-04A',
                            busName: 'Bus M1-04A',
                            status: '2 min ago',
                            tagColor: const Color(0xFFFBB432),
                            statusColor: const Color(0xFF3B82F6),
                          ),
                          const SizedBox(height: 8),
                          _buildBusItem(
                            busTag: '21B',
                            busName: 'Bus 21B',
                            status: '2 min ago',
                            tagColor: const Color(0xFF508867),
                            statusColor: const Color(0xFF3B82F6),
                          ),
                          const SizedBox(height: 8),
                          _buildBusItem(
                            busTag: '13C',
                            busName: 'Bus 13C',
                            status: '2 min ago',
                            tagColor: const Color(0xFFC54742),
                            statusColor: const Color(0xFF3B82F6),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusItem({
    required String busTag,
    required String busName,
    required String status,
    required Color tagColor,
    required Color statusColor,
  }) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // TAG
          SizedBox(
            width: 64,
            height: 28,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tagColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                busTag,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tagColor == const Color(0xFFFBB432)
                      ? Colors.black
                      : Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // NAME
          Expanded(
            child: Text(
              busName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),

          // STATUS
          SizedBox(
            width: 84,
            height: 28,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


}
