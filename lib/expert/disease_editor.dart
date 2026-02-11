import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Map disease names to asset image paths (same as farmer side)
const Map<String, String> diseaseImages = {
  'Anthracnose': 'assets/replace_disease/anthracnose_image.jpg',
  'Bacterial black spot': 'assets/replace_disease/bacterial_image.jpg',
  'Dieback': 'assets/replace_disease/dieback_image.jpg',
  'Powdery mildew': 'assets/replace_disease/powdery_image.jpg',
};

const List<String> mainDiseases = [
  'Anthracnose',
  'Bacterial black spot',
  'Dieback',
  'Powdery mildew',
];

// Color coding for diseases (matching your analytics colors)
const Map<String, Color> diseaseColors = {
  'Anthracnose': Color(0xFFFF9800), // Orange
  'Bacterial black spot': Color(0xFF9C27B0), // Purple
  'Dieback': Color(0xFFF44336), // Red
  'Powdery mildew': Color(0xFF1B5E20), // Dark Green
};

class DiseaseEditor extends StatefulWidget {
  const DiseaseEditor({Key? key}) : super(key: key);

  @override
  State<DiseaseEditor> createState() => _DiseaseEditorState();
}

class _DiseaseEditorState extends State<DiseaseEditor> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('diseases').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No diseases found.'));
          }
          // Filter only the main diseases
          final docs =
              snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return mainDiseases.contains(data['name']);
              }).toList();
          // Sort by mainDiseases order
          docs.sort(
            (a, b) => mainDiseases
                .indexOf((a.data() as Map<String, dynamic>)['name'])
                .compareTo(
                  mainDiseases.indexOf(
                    (b.data() as Map<String, dynamic>)['name'],
                  ),
                ),
          );
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unknown';
              final imagePath =
                  diseaseImages[name] ??
                  'assets/replace_disease/healthy_image.jpg';
              final symptomsCount = (data['symptoms'] as List?)?.length ?? 0;
              final treatmentsCount =
                  (data['treatments'] as List?)?.length ?? 0;
              final diseaseColor = diseaseColors[name] ?? Colors.green;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => DiseaseEditorScreen(
                                docId: doc.id,
                                data: data,
                                imagePath: imagePath,
                              ),
                        ),
                      ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image header with gradient overlay
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            child: Image.asset(
                              imagePath,
                              width: double.infinity,
                              height: 140,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            height: 140,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 12,
                            left: 12,
                            right: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data['scientificName'] ?? '',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: diseaseColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.local_hospital,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Content section
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.list_alt,
                                    size: 20,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$symptomsCount Symptoms',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.healing,
                                    size: 20,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$treatmentsCount Treatments',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.green,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Full-screen editor
class DiseaseEditorScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic> data;
  final String imagePath;

  const DiseaseEditorScreen({
    Key? key,
    required this.docId,
    required this.data,
    required this.imagePath,
  }) : super(key: key);

  @override
  State<DiseaseEditorScreen> createState() => _DiseaseEditorScreenState();
}

class _DiseaseEditorScreenState extends State<DiseaseEditorScreen> {
  late List<TextEditingController> symptomControllers;
  late List<TextEditingController> treatmentControllers;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    symptomControllers = List<TextEditingController>.from(
      (widget.data['symptoms'] ?? ['']).map<TextEditingController>(
        (s) =>
            TextEditingController(text: s)
              ..addListener(() => setState(() => _hasUnsavedChanges = true)),
      ),
    );
    treatmentControllers = List<TextEditingController>.from(
      (widget.data['treatments'] ?? ['']).map<TextEditingController>(
        (t) =>
            TextEditingController(text: t)
              ..addListener(() => setState(() => _hasUnsavedChanges = true)),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in symptomControllers) {
      controller.dispose();
    }
    for (var controller in treatmentControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addSymptomField() {
    setState(() {
      final controller =
          TextEditingController()
            ..addListener(() => setState(() => _hasUnsavedChanges = true));
      symptomControllers.add(controller);
    });
  }

  void _removeSymptomField(int idx) {
    if (symptomControllers.length > 1) {
      setState(() {
        symptomControllers[idx].dispose();
        symptomControllers.removeAt(idx);
        _hasUnsavedChanges = true;
      });
    }
  }

  void _addTreatmentField() {
    setState(() {
      final controller =
          TextEditingController()
            ..addListener(() => setState(() => _hasUnsavedChanges = true));
      treatmentControllers.add(controller);
    });
  }

  void _removeTreatmentField(int idx) {
    if (treatmentControllers.length > 1) {
      setState(() {
        treatmentControllers[idx].dispose();
        treatmentControllers.removeAt(idx);
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Unsaved Changes'),
            content: const Text(
              'You have unsaved changes. Are you sure you want to leave?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
    );

    return shouldPop ?? false;
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      final symptoms =
          symptomControllers
              .map((c) => c.text.trim())
              .where((s) => s.isNotEmpty)
              .toList();
      final treatments =
          treatmentControllers
              .map((c) => c.text.trim())
              .where((t) => t.isNotEmpty)
              .toList();

      final docData = {
        'name': widget.data['name'],
        'scientificName': widget.data['scientificName'],
        'symptoms': symptoms,
        'treatments': treatments,
        'confirmedBy': widget.data['confirmedBy'] ?? 'Agricultural Office',
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance
            .collection('diseases')
            .doc(widget.docId)
            .set(docData);
      }

      setState(() {
        _isSaving = false;
        _hasUnsavedChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final diseaseColor = diseaseColors[widget.data['name']] ?? Colors.green;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Edit ${widget.data['name']}'),
          backgroundColor: diseaseColor,
          elevation: 0,
          actions: [
            if (_hasUnsavedChanges)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 4),
                    Text('Unsaved', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Disease header image
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => FullScreenImageViewer(
                            imagePath: widget.imagePath,
                            diseaseName: widget.data['name'] ?? '',
                          ),
                    ),
                  );
                },
                child: Stack(
                  children: [
                    Image.asset(
                      widget.imagePath,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.zoom_in, color: Colors.white, size: 20),
                            SizedBox(width: 4),
                            Text(
                              'Tap to enlarge',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.data['name'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.data['scientificName'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Symptoms section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list_alt, color: diseaseColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Symptoms',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${symptomControllers.length} items',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      symptomControllers.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: diseaseColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          color: diseaseColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${symptomControllers[i].text.length} chars',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed:
                                          symptomControllers.length > 1
                                              ? () => _removeSymptomField(i)
                                              : null,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: symptomControllers[i],
                                  decoration: const InputDecoration(
                                    hintText: 'Enter symptom description...',
                                    border: OutlineInputBorder(),
                                  ),
                                  minLines: 3,
                                  maxLines: null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Symptom'),
                        onPressed: _addSymptomField,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: diseaseColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Treatments section
                    Row(
                      children: [
                        Icon(Icons.healing, color: diseaseColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Treatments',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${treatmentControllers.length} items',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      treatmentControllers.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: diseaseColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          color: diseaseColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${treatmentControllers[i].text.length} chars',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed:
                                          treatmentControllers.length > 1
                                              ? () => _removeTreatmentField(i)
                                              : null,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: treatmentControllers[i],
                                  decoration: const InputDecoration(
                                    hintText: 'Enter treatment description...',
                                    border: OutlineInputBorder(),
                                  ),
                                  minLines: 3,
                                  maxLines: null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Treatment'),
                        onPressed: _addTreatmentField,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: diseaseColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 80), // Space for FAB
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isSaving ? null : _saveChanges,
          backgroundColor: diseaseColor,
          foregroundColor: Colors.white,
          icon:
              _isSaving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : const Icon(Icons.save, color: Colors.white),
          label: Text(
            _isSaving ? 'Saving...' : 'Save Changes',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// Full-screen image viewer
class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  final String diseaseName;

  const FullScreenImageViewer({
    Key? key,
    required this.imagePath,
    required this.diseaseName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(diseaseName, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
