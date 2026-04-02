import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/checkin_service.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});
  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Bonus Feature: Map Controller for Zoom and Panning
  final MapController _mapController = MapController();

  String addressText = 'Waiting for location...';
  double? currentLat, currentLng;
  int totalPoints = 0;
  bool isAtFair = false;

  // Fair Details
  final String fairName = "Southern Career Fair 2026";
  final int fairPoints = 50;
  static const double targetLat = 1.5336;
  static const double targetLng = 103.6819;
  static const double allowRadius = 500.0;

  @override
  void initState() {
    super.initState();
    _loadTotalPoints();
    _updateLocation(); // Bonus: Auto-locate on startup
  }

  // Calculate total points
  Future<void> _loadTotalPoints() async {
    final history = await CheckInService.getHistory();
    int sum = 0;
    for (var entry in history) {
      String loc = entry['location'] ?? "";
      List<String> parts = loc.split("|||");
      if (parts.length >= 2) {
        sum += int.tryParse(parts[1]) ?? 0;
      }
    }
    setState(() {
      totalPoints = sum;
    });
  }

  // Fetch location and validate
  Future<void> _updateLocation() async {
    try {
      setState(() {
        addressText = "Locating...";
      });

      final service = LocationService();
      final pos = await service.getCurrentLocation();
      final address = await service.getAddressFromCoordinates(pos);

      double distance = service.calculateDistance(
        pos.latitude,
        pos.longitude,
        targetLat,
        targetLng,
      );

      setState(() {
        currentLat = pos.latitude;
        currentLng = pos.longitude;
        addressText = (address == "Unknown location" || address.isEmpty)
            ? "Address unavailable"
            : address;
        isAtFair = distance <= allowRadius;
      });

      // Bonus: Smoothly pan map to the user's location
      _mapController.move(LatLng(pos.latitude, pos.longitude), 17.0);
    } catch (e) {
      setState(() {
        addressText = "Failed to get location.";
      });
    }
  }

  // Map Controls
  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _recenterMap() {
    if (currentLat != null && currentLng != null) {
      _mapController.move(LatLng(currentLat!, currentLng!), 17.0);
    }
  }

  Future<void> _handleJoinFair() async {
    if (currentLat != null && currentLng != null) {
      String addressLine = "You are at $addressText";
      String coordsLine = "(Lat: $currentLat, Lng: $currentLng)";

      // Hidden data packing structure
      String dataToSave =
          "$fairName|||$fairPoints|||$addressLine|||$coordsLine";
      await CheckInService.addCheckIn(dataToSave);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Check-in successful!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadTotalPoints();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please refresh location first!"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- 这里是修改后的 AppBar 部分 ---
      appBar: AppBar(
        centerTitle: true, // 标题居中
        title: const Text(
          'Event Explorer', // 更有个性的名字
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.blueAccent], // 渐变色效果
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
      ),

      // --- AppBar 修改结束 ---
      body: Stack(
        children: [
          // 背景：地图层
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(targetLat, targetLng),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: const LatLng(targetLat, targetLng),
                    color: Colors.blueAccent.withOpacity(0.2),
                    borderColor: Colors.blueAccent,
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                    radius: allowRadius,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  const Marker(
                    point: LatLng(targetLat, targetLng),
                    child: Icon(Icons.stars, color: Colors.redAccent, size: 45),
                  ),
                  if (currentLat != null)
                    Marker(
                      point: LatLng(currentLat!, currentLng!),
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blueAccent,
                        size: 45,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 地图控制按钮（右侧）
          Positioned(
            top: 20,
            right: 15,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "btn_loc",
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _recenterMap,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "btn_in",
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, color: Colors.black87),
                ),
                const SizedBox(height: 5),
                FloatingActionButton(
                  heroTag: "btn_out",
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, color: Colors.black87),
                ),
              ],
            ),
          ),

          // 底部 UI 面板
          Positioned(
            bottom: 20,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fairName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Location: Southern University College | Earn: $fairPoints pts",
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const Divider(height: 25, thickness: 1),

                  // 状态指示器
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isAtFair
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAtFair ? Icons.check_circle : Icons.cancel,
                          color: isAtFair ? Colors.green : Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAtFair ? "Status: At Fair" : "Status: Not At Fair",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isAtFair ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 地址信息
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          "$addressText\n${currentLat != null ? '(Lat: $currentLat, Lng: $currentLng)' : ''}",
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // 总分显示
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          "Total Points Earned: $totalPoints",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 按钮组
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _updateLocation,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text("Refresh"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _handleJoinFair,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo, // 这里也改成了靛蓝色，呼应顶栏
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "JOIN FAIR",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HistoryScreen(),
                      ),
                    ),
                    child: const Text(
                      "View Participation History",
                      style: TextStyle(color: Colors.indigo), // 统一颜色
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
