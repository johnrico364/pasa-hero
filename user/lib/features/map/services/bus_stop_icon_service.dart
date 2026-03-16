import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Service for loading and managing custom bus stop icons.
/// 
/// Handles:
/// - Loading custom bus stop icon from assets
/// - Resizing icons to appropriate size
/// - Providing fallback icons if loading fails
class BusStopIconService {
  static BusStopIconService? _instance;
  static BusStopIconService get instance {
    _instance ??= BusStopIconService._();
    return _instance!;
  }

  BusStopIconService._();

  BitmapDescriptor? _customBusStopIcon;
  BitmapDescriptor? _customClosestBusStopIcon;
  bool _iconsLoaded = false;

  /// Path to the custom bus stop icon asset.
  static const String _iconAssetPath = 'assets/images/logo/bustopSign.png';

  /// Target width for resizing the icon (in pixels).
  static const int _iconTargetWidth = 65;

  /// Loads the custom bus stop icon from assets and resizes it.
  /// Should be called during app initialization.
  Future<void> loadIcons() async {
    if (_iconsLoaded) return;

    try {
      // Load the custom bus stop icon
      final ByteData iconData = await rootBundle.load(_iconAssetPath);
      final Uint8List bytes = iconData.buffer.asUint8List();

      // Decode and resize the image
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _iconTargetWidth,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // Convert to bytes for BitmapDescriptor
      final ByteData? resizedData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (resizedData != null) {
        final Uint8List resizedBytes = resizedData.buffer.asUint8List();
        _customBusStopIcon = BitmapDescriptor.fromBytes(resizedBytes);
        _customClosestBusStopIcon = _customBusStopIcon;
      } else {
        throw Exception('Failed to convert resized image to bytes');
      }

      _iconsLoaded = true;
      print('✅ [BusStopIconService] Custom bus stop icon loaded and resized successfully');
    } catch (e) {
      print('⚠️ [BusStopIconService] Failed to load custom bus stop icon: $e');
      // Fallback to default icons
      _customBusStopIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      _customClosestBusStopIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      _iconsLoaded = true;
    }
  }

  /// Gets the default bus stop icon (custom or fallback).
  BitmapDescriptor get defaultIcon {
    if (!_iconsLoaded) {
      // If not loaded yet, return default (will be updated when loaded)
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
    return _customBusStopIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  }

  /// Gets the closest bus stop icon (custom or fallback).
  BitmapDescriptor get closestIcon {
    if (!_iconsLoaded) {
      // If not loaded yet, return default (will be updated when loaded)
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
    return _customClosestBusStopIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  }

  /// Checks if icons have been loaded.
  bool get isLoaded => _iconsLoaded;
}
