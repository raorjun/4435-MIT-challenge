import 'package:flutter/material.dart';

class SteplightHomeScreen extends StatefulWidget {
  const SteplightHomeScreen({Key? key}) : super(key: key);

  @override
  State<SteplightHomeScreen> createState() => _SteplightHomeScreenState();
}

class _SteplightHomeScreenState extends State<SteplightHomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20), // Reduced vertical padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App Title - EXTRA LARGE
              const Text(
                'Steplight',
                style: TextStyle(
                  fontSize: 64, // HUGE
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12), // Reduced from 16
              
              // Subtitle
              const Text(
                'Navigate with confidence',
                style: TextStyle(
                  fontSize: 24, // Large
                  color: Color(0xFF00E5FF),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40), // Reduced from 80
              
              // START NAVIGATION - Big Button
              _buildSafeTapButton(
                label: 'Start Navigation',
                icon: Icons.navigation_rounded,
                color: const Color(0xFF7B8CFF), // Purple
                onTap: () {
                  _showComingSoon(context, 'Navigation starting...');
                },
              ),
              
              const SizedBox(height: 16), // Reduced from 24
              
              // GET HELP - Big Button
              _buildSafeTapButton(
                label: 'Get Help',
                icon: Icons.emergency_rounded,
                color: const Color(0xFF00E5FF), // Cyan
                onTap: () {
                  _showSafeTapOptions(context);
                },
                onLongPress: () {
                  _activateEmergency(context);
                },
              ),
              
              const SizedBox(height: 16), // Reduced from 24
              
              // SETTINGS - Big Button
              _buildSafeTapButton(
                label: 'Settings',
                icon: Icons.settings_rounded,
                color: const Color(0xFF0A0A0A), // Dark
                borderColor: const Color(0xFF7B8CFF),
                textColor: Colors.white, // White text for dark background
                onTap: () {
                  _showComingSoon(context, 'Settings coming soon');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // SafeTap Button Widget - Easy to hit!
  Widget _buildSafeTapButton({
    required String label,
    required IconData icon,
    required Color color,
    Color? borderColor,
    Color? textColor, // Add text color parameter
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 140, // HUGE touch target (120dp minimum for accessibility)
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: borderColor != null 
            ? Border.all(color: borderColor, width: 2)
            : null,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Icon(
              icon,
              size: 56, // Big icon
              color: Colors.white,
            ),
            
            const SizedBox(width: 20),
            
            // Text
            Text(
              label,
              style: TextStyle(
                fontSize: 32, // LARGE text
                fontWeight: FontWeight.bold,
                color: textColor ?? const Color(0xFF0A0A0A), // Use provided color or default to dark
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSafeTapOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF000000),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: const [
                Icon(
                  Icons.emergency_rounded,
                  color: Color(0xFF00E5FF),
                  size: 40,
                ),
                SizedBox(width: 16),
                Text(
                  'Get Help',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Option 1: Call Emergency
            _buildSafeTapOption(
              'Call Emergency Contact',
              Icons.phone_rounded,
              () {
                Navigator.pop(context);
                _showComingSoon(context, 'Calling emergency contact...');
              },
            ),
            
            const SizedBox(height: 20),
            
            // Option 2: Share Location
            _buildSafeTapOption(
              'Share My Location',
              Icons.location_on_rounded,
              () {
                Navigator.pop(context);
                _showComingSoon(context, 'Sharing your location...');
              },
            ),
            
            const SizedBox(height: 20),
            
            // Option 3: Alert Nearby
            _buildSafeTapOption(
              'Alert Nearby Help',
              Icons.notifications_active_rounded,
              () {
                Navigator.pop(context);
                _showComingSoon(context, 'Alerting nearby assistance...');
              },
            ),
            
            const SizedBox(height: 32),
            
            // Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 22,
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSafeTapOption(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 100, // Big touch target
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF7B8CFF),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF7B8CFF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 36,
                color: const Color(0xFF00E5FF),
              ),
            ),
            
            const SizedBox(width: 20),
            
            // Label
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 20, // Large text
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            
            // Arrow
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 24,
              color: Color(0xFF00E5FF),
            ),
          ],
        ),
      ),
    );
  }

  void _activateEmergency(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFF6B6B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emergency,
              color: Colors.white,
              size: 80,
            ),
            const SizedBox(height: 20),
            const Text(
              'EMERGENCY',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Emergency mode activated.\nCalling emergency contact now...',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFF6B6B),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 20),
        ),
        backgroundColor: const Color(0xFF7B8CFF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}