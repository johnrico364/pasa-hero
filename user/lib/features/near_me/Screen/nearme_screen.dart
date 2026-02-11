import 'package:flutter/material.dart';
import '../../../shared/bottom_navBar.dart';
import '../../../shared/search_bar.dart';
import '../../map/map.dart';
import '../Module/nearby_terminal.dart';
import '../Module/nearby_routes.dart';

class NearMeScreen extends StatelessWidget {
  const NearMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainNavigationScreen(
      nearMeContent: const _NearMeContent(),
    );
  }
}

class _NearMeContent extends StatefulWidget {
  const _NearMeContent();

  @override
  State<_NearMeContent> createState() => _NearMeContentState();
}

class _NearMeContentState extends State<_NearMeContent> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch(String query) {
    // TODO: Implement search functionality
    // Filter terminals and routes based on query
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFEDF3F8),
        child: Column(
          children: [
            // Custom rounded header container with title and search bar
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A8A),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(45),
                  bottomRight: Radius.circular(45),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Title
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
                      child: Text(
                        'Nearby Terminals and Routes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    // Search Bar inside the blue container
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: AppSearchBar(
                        controller: _searchController,
                        onChanged: _handleSearch,
                        onTap: () {
                          // TODO: Implement search functionality
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nearby Terminals Section
                    const NearbyTerminalsList(),
                    
                    const SizedBox(height: 16),
                    
                    // Map View
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const MapWidget(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Nearby Routes Section
                    const NearbyRoutesList(),
                    
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
}
