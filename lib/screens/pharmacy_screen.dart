import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  List<Map<String, dynamic>> _pharmacies = [];

  // ✅ Use your Places API key
  final String apiKey = "AIzaSyBWb3bHEVNK2SgYFuep3iPjCtDvHOXmf4k";

  @override
  void initState() {
    super.initState();
    print("📍 initState called → Getting current location...");
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    print("🔎 Checking location services...");
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("❌ Location services disabled.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location services are disabled.")),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    print("📍 Permission before request: $permission");

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      print("📍 Permission after request: $permission");
      if (permission == LocationPermission.denied) {
        print("❌ Permission denied by user.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("❌ Permission permanently denied.");
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print("✅ Got location: ${position.latitude}, ${position.longitude}");

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      _fetchNearbyPharmacies(position.latitude, position.longitude);
    } catch (e) {
      print("❌ Error getting location: $e");
    }
  }

  Future<void> _fetchNearbyPharmacies(double lat, double lng) async {
    final url =
        "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
        "?location=$lat,$lng&radius=5000&type=pharmacy&key=$apiKey";

    print("🌍 Fetching pharmacies from: $url");

    try {
      final response = await http.get(Uri.parse(url));
      print("📡 API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("📦 API response body: ${data.toString().substring(0, 300)}...");

        if (data['results'] != null) {
          setState(() {
            _pharmacies = List<Map<String, dynamic>>.from(
              data['results'].map((place) {
                final double placeLat = place['geometry']['location']['lat'];
                final double placeLng = place['geometry']['location']['lng'];

                double distanceInMeters = Geolocator.distanceBetween(
                  lat,
                  lng,
                  placeLat,
                  placeLng,
                );
                double distanceInKm = distanceInMeters / 1000;

                return {
                  "name": place['name'],
                  "address": place['vicinity'],
                  "lat": placeLat,
                  "lng": placeLng,
                  "distance": distanceInKm,
                };
              }),
            );

            _pharmacies.sort((a, b) =>
                (a["distance"] as double).compareTo(b["distance"] as double));
          });

          print("✅ Pharmacies loaded: ${_pharmacies.length}");
        } else {
          print("⚠️ No results found in API response.");
        }
      } else {
        print("❌ Failed to fetch pharmacies: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to fetch pharmacies")),
        );
      }
    } catch (e) {
      print("❌ Error fetching pharmacies: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    print("🔄 build() called. Current position: $_currentPosition");

    return Scaffold(
      appBar: AppBar(title: const Text("Nearby Pharmacy")),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Google Map
          SizedBox(
            height: 300,
            child: GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                print("🗺️ Map created successfully.");
              },
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 14,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId("currentLocation"),
                  position: _currentPosition!,
                  infoWindow: const InfoWindow(title: "You are here"),
                ),
                ..._pharmacies.map(
                      (pharmacy) => Marker(
                    markerId: MarkerId(pharmacy["name"]),
                    position: LatLng(pharmacy["lat"], pharmacy["lng"]),
                    infoWindow: InfoWindow(
                      title: pharmacy["name"],
                      snippet:
                      "${pharmacy["address"]} • ${(pharmacy["distance"] as double).toStringAsFixed(2)} km",
                    ),
                  ),
                ),
              },
            ),
          ),

          const SizedBox(height: 10),

          // Pharmacy List
          Expanded(
            child: ListView.builder(
              itemCount: _pharmacies.length,
              itemBuilder: (context, index) {
                final pharmacy = _pharmacies[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.local_pharmacy,
                        color: Colors.blue),
                    title: Text(pharmacy["name"]),
                    subtitle: Text(
                        "${pharmacy["address"]}\nDistance: ${(pharmacy["distance"] as double).toStringAsFixed(2)} km"),
                    isThreeLine: true,
                    onTap: () {
                      print(
                          "📍 Tapped on ${pharmacy["name"]}, moving map...");
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(pharmacy["lat"], pharmacy["lng"]),
                          16,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
