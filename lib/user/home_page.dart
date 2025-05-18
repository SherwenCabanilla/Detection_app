import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_page.dart';
import 'detection_carousel_screen.dart';
import 'disease_details_page.dart';
import 'profile_page.dart';
import 'user_request_list.dart';
import 'scan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    // Home
    Container(), // Placeholder for home content
    // Scan
    const ScanPage(),
    // My Requests
    const UserRequestTabbedList(),
  ];

  int get _pendingCount =>
      userRequests.where((r) => r['status'] == 'pending_review').length;

  // Disease information
  final Map<String, Map<String, dynamic>> diseaseInfo = {
    'Anthracnose': {
      'scientificName': 'Colletotrichum gloeosporioides',
      'symptoms': [
        'Irregular black or brown spots that expand and merge, leading to necrosis and leaf drop (Li et al., 2024).',
      ],
      'treatments': [
        'Apply copper-based fungicides like copper oxychloride or Mancozeb during wet and humid conditions to prevent spore germination.',
        'Prune mango trees regularly to improve air circulation and reduce humidity around foliage.',
        'Remove and burn infected leaves to limit reinfection cycles.',
      ],
    },
    'Powdery Mildew': {
      'scientificName': 'Oidium mangiferae',
      'symptoms': [
        'A white, powdery fungal coating forms on young mango leaves, leading to distortion, yellowing, and reduced photosynthesis (Nasir, 2016).',
      ],
      'treatments': [
        'Use sulfur-based or systemic fungicides like tebuconazole at the first sign of infection and repeat at 10–14-day intervals.',
        'Avoid overhead irrigation which increases humidity and spore spread on leaf surfaces.',
        'Remove heavily infected leaves to reduce fungal load.',
      ],
    },
    'Dieback': {
      'scientificName': 'Lasiodiplodia theobromae',
      'symptoms': [
        'Browning of leaf tips, followed by downward necrosis and eventual branch dieback (Ploetz, 2003).',
      ],
      'treatments': [
        'Prune affected twigs at least 10 cm below the last symptom to halt pathogen progression.',
        'Apply systemic fungicides such as carbendazim to protect surrounding healthy leaves.',
        'Maintain plant vigor through balanced nutrition and irrigation to resist infection.',
      ],
    },
    'Bacterial black spot': {
      'scientificName': 'Xanthomonas campestris pv. mangiferaeindicae',
      'symptoms': [
        'Angular black lesions with yellow halos often appear along veins and can lead to early leaf drop (Ploetz, 2003).',
      ],
      'treatments': [
        'Apply copper hydroxide or copper oxychloride sprays to suppress bacterial activity on the leaf surface.',
        'Remove and properly dispose of infected leaves to reduce inoculum sources.',
        'Avoid causing wounds on leaves during handling, as these can be entry points for bacteria.',
      ],
    },
    'Healthy': {
      'scientificName': '',
      'symptoms': [
        'Vibrant green leaves without spots or lesions',
        'Normal growth pattern',
        'No visible signs of disease or pest damage',
      ],
      'treatments': [
        'Regular monitoring for early detection of problems',
        'Maintain proper irrigation and fertilization',
        'Practice good orchard sanitation',
      ],
    },
    'Tip Burn': {
      'scientificName': 'Physiological / Nutritional Leaf Disorder',
      'symptoms': [
        'The tips and edges of leaves turn brown and dry, often due to non-pathogenic causes such as nutrient imbalance or salt injury (Gardening Know How, n.d.).',
      ],
      'treatments': [
        'Ensure consistent, deep watering to avoid drought stress that can worsen tip burn symptoms.',
        'Avoid excessive use of nitrogen-rich or saline fertilizers which may lead to root toxicity and leaf damage.',
        'Supplement calcium or potassium via foliar feeding if nutrient deficiency is suspected.',
        'Conduct regular soil testing to detect salinity or imbalance that might affect leaf health.',
      ],
    },
  };

  Future<void> _selectFromGallery(BuildContext context) async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null && images.isNotEmpty) {
      if (images.length > 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 5 images can be selected'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => DetectionCarouselScreen(
                imagePaths: images.map((img) => img.path).toList(),
              ),
        ),
      );
    }
  }

  void _showDiseaseDetails(String name, String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => DiseaseDetailsPage(
              name: name,
              imagePath: imagePath,
              scientificName: diseaseInfo[name]?['scientificName'] ?? '',
              details: {
                'Symptoms': diseaseInfo[name]?['symptoms'] ?? [],
                'Treatments': diseaseInfo[name]?['treatments'] ?? [],
              },
            ),
      ),
    );
  }

  Widget _buildDiseaseCard(String name, String imagePath) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: InkWell(
        onTap: () => _showDiseaseDetails(name, imagePath),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  imagePath,
                  width: 100,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Green header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 30,
                          height: 30,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'MangoSense',
                        style: TextStyle(
                          color: Colors.yellow,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfilePage(),
                        ),
                      );
                    },
                    child: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
            // Main content
            Expanded(
              child:
                  _selectedIndex == 0
                      ? SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            // Welcome text
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Good day, Farmer 1',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Diseases section
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Diseases',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Disease cards (only those in labels.txt)
                            _buildDiseaseCard(
                              'Anthracnose',
                              'assets/diseases/anthracnose.jpg',
                            ),
                            _buildDiseaseCard(
                              'Bacterial black spot',
                              'assets/diseases/backterial_blackspot1.jpg',
                            ),
                            _buildDiseaseCard(
                              'Dieback',
                              'assets/diseases/dieback.jpg',
                            ),
                            _buildDiseaseCard(
                              'Powdery Mildew',
                              'assets/diseases/powdery_mildew.jpg',
                            ),
                            const SizedBox(height: 16),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'None Disease',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            _buildDiseaseCard(
                              'Healthy',
                              'assets/diseases/healthy.jpg',
                            ),
                            const SizedBox(height: 16),
                            // Tip Burn recommendation card (not detected, info only)
                            _buildDiseaseCard(
                              'Tip Burn',
                              'assets/diseases/tip_burn.jpg',
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      )
                      : _pages[_selectedIndex],
            ),
            // Bottom navigation bar
            BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              selectedItemColor: Colors.green,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.camera_alt),
                  label: 'Scan',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.list_alt, size: 28),
                      if (_pendingCount > 0)
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.all(0),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              border: Border.all(color: Colors.white, width: 2),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 22,
                              minHeight: 22,
                            ),
                            child: Center(
                              child: Text(
                                '$_pendingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'My Requests',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
