import 'package:flutter/material.dart';
import '../Screen/terminal_screen.dart';

class NearbyTerminal extends StatelessWidget {
  final String terminalName;
  final String distance;
  final List<String> routeTags;
  final VoidCallback? onTap;

  const NearbyTerminal({
    super.key,
    required this.terminalName,
    required this.distance,
    required this.routeTags,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.directions_bus,
                color: Color(0xFF3B82F6),
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      terminalName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      distance,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5D5D5D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: routeTags.map((tag) {
              Color backgroundColor;
              Color textColor;
              
              if (tag.startsWith('MI-')) {
                backgroundColor = const Color(0xFFFBB432);
                textColor = Colors.black;
              } else if (tag.contains('B')) {
                backgroundColor = const Color(0xFF508867);
                textColor = Colors.white;
              } else {
                backgroundColor = const Color(0xFFC54742);
                textColor = Colors.white;
              }
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ),
    );
  }
}

class NearbyTerminalsList extends StatelessWidget {
  const NearbyTerminalsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Nearby Terminals',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        SizedBox(
          height: 165,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              NearbyTerminal(
                terminalName: 'Tamiya Terminal',
                distance: '0.2 miles',
                routeTags: ['MI-04A', '21B', '13C'],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TerminalScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              NearbyTerminal(
                terminalName: 'Tamiya Terminal',
                distance: '0.2 miles',
                routeTags: ['MI-04A', '21B', '13C'],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TerminalScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              NearbyTerminal(
                terminalName: 'Tamiya Terminal',
                distance: '0.2 miles',
                routeTags: ['MI-04A', '21B', '13C'],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TerminalScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
