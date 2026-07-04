import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/imago_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _devotionals = [
    {
      'day': 'Today',
      'verse': 'Jeremiah 29:11',
      'text':
          '"For I know the plans I have for you," declares the Lord, "plans to prosper you and not to harm you, plans to give you hope and a future."',
      'theme': 'Purpose',
    },
    {
      'day': 'Yesterday',
      'verse': 'Philippians 4:6-7',
      'text':
          'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.',
      'theme': 'Peace',
    },
    {
      'day': 'Tuesday',
      'verse': 'Isaiah 41:10',
      'text':
          'Do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you.',
      'theme': 'Strength',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firstName = (user?.displayName ?? 'Beloved').split(' ').first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const CosmicBackground(children: []),

          // Ambient glow
          Positioned(
            top: 80,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5C6BC0).withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: const SizedBox.shrink(),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting,',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            firstName,
                            style: const TextStyle(
                              fontFamily: 'Cinzel',
                              color: ImagoColors.cream,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF5C6BC0), Color(0xFF3D5AFE)],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF1B1147),
                          child: Text(
                            firstName.isNotEmpty ? firstName[0] : 'I',
                            style: const TextStyle(
                              fontFamily: 'Cinzel',
                              color: ImagoColors.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Today's Date banner
                  Text(
                    DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 11,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Today's Word section
                  const Text(
                    "Today's Word",
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: ImagoColors.cream,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Devotional cards carousel
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _devotionals.length,
                      itemBuilder: (context, index) {
                        return _buildDevotionalCard(_devotionals[index], index);
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Quick access
                  const Text(
                    'Your Journey',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: ImagoColors.cream,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 16),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.4,
                    children: [
                      _quickCard(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Ask Imago',
                        sublabel: 'AI Counseling',
                        gradient: const [Color(0xFF5C6BC0), Color(0xFF3D5AFE)],
                      ),
                      _quickCard(
                        icon: Icons.volunteer_activism_rounded,
                        label: 'Prayer Mode',
                        sublabel: 'Talk with God',
                        gradient: const [Color(0xFF4285F4), Color(0xFF1976D2)],
                      ),
                      _quickCard(
                        icon: Icons.mic_rounded,
                        label: 'Sermons',
                        sublabel: 'Audio archive',
                        gradient: const [Color(0xFF9575CD), Color(0xFF673AB7)],
                      ),
                      _quickCard(
                        icon: Icons.menu_book_rounded,
                        label: 'Bible',
                        sublabel: 'Read the Word',
                        gradient: const [Color(0xFF4DB6AC), Color(0xFF009688)],
                      ),
                    ],
                  ),

                  const SizedBox(height: 100), // nav bar padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevotionalCard(Map<String, String> data, int index) {
    final colors = [
      [const Color(0xFF5C6BC0), const Color(0xFF3D5AFE)],
      [const Color(0xFF4285F4), const Color(0xFF1976D2)],
      [const Color(0xFF9575CD), const Color(0xFF673AB7)],
    ];
    final gradColors = colors[index % colors.length];

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: gradColors[0].withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: gradColors[0].withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        data['theme']!,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: gradColors[0],
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      data['day']!,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  data['verse']!,
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    color: ImagoColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    data['text']!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required List<Color> gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      sublabel,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
