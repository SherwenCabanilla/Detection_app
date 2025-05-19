import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import '../shared/review_manager.dart';

class ScanRequestDetail extends StatefulWidget {
  final Map<String, dynamic> request;

  const ScanRequestDetail({Key? key, required this.request}) : super(key: key);

  @override
  _ScanRequestDetailState createState() => _ScanRequestDetailState();
}

class _ScanRequestDetailState extends State<ScanRequestDetail> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _treatmentController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();
  final TextEditingController _precautionsController = TextEditingController();
  bool _isSubmitting = false;
  bool _showBoundingBoxes = true;
  String _selectedSeverity = 'medium';
  List<String> _selectedPreventiveMeasures = [];
  DateTime _nextScanDate = DateTime.now().add(const Duration(days: 7));
  bool _isEditing = false;
  final ReviewManager _reviewManager = ReviewManager();

  final List<String> _preventiveMeasures = [
    'Regular pruning',
    'Proper spacing between plants',
    'Adequate ventilation',
    'Regular watering',
    'Proper fertilization',
    'Pest monitoring',
    'Soil testing',
    'Crop rotation',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    _treatmentController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _precautionsController.dispose();
    super.dispose();
  }

  void _submitReview() {
    if (_commentController.text.isEmpty || _treatmentController.text.isEmpty)
      return;

    setState(() {
      _isSubmitting = true;
    });

    final expertReview = {
      'comment': _commentController.text,
      'severityAssessment': {
        'level': _selectedSeverity,
        'confidence': widget.request['diseaseSummary'][0]['averageConfidence'],
        'notes': 'Expert assessment based on image analysis',
      },
      'treatmentPlan': {
        'recommendations': [
          {
            'treatment': _treatmentController.text,
            'dosage': _dosageController.text,
            'frequency': _frequencyController.text,
            'precautions': _precautionsController.text,
          },
        ],
        'preventiveMeasures': _selectedPreventiveMeasures,
      },
    };

    _reviewManager.updateReview(
      reviewId: widget.request['id'],
      status: 'reviewed',
      expertReview: expertReview,
    );

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Review submitted successfully'),
        backgroundColor: Colors.green,
      ),
    );

    // Go back to the list
    Navigator.pop(context);
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      // Initialize form with existing review data
      final review = widget.request['expertReview'];
      if (review != null) {
        _selectedSeverity = review['severityAssessment']?['level'] ?? 'medium';
        _commentController.text = review['comment'] ?? '';

        final recommendations =
            review['treatmentPlan']?['recommendations'] as List?;
        if (recommendations != null && recommendations.isNotEmpty) {
          final treatment = recommendations[0];
          _treatmentController.text = treatment['treatment'] ?? '';
          _dosageController.text = treatment['dosage'] ?? '';
          _frequencyController.text = treatment['frequency'] ?? '';
          _precautionsController.text = treatment['precautions'] ?? '';
        }

        _selectedPreventiveMeasures = List<String>.from(
          review['treatmentPlan']?['preventiveMeasures'] ?? [],
        );
      }
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      // Reset form to original values
      final review = widget.request['expertReview'];
      if (review != null) {
        _selectedSeverity = review['severityAssessment']?['level'] ?? 'medium';
        _commentController.text = review['comment'] ?? '';

        final recommendations =
            review['treatmentPlan']?['recommendations'] as List?;
        if (recommendations != null && recommendations.isNotEmpty) {
          final treatment = recommendations[0];
          _treatmentController.text = treatment['treatment'] ?? '';
          _dosageController.text = treatment['dosage'] ?? '';
          _frequencyController.text = treatment['frequency'] ?? '';
          _precautionsController.text = treatment['precautions'] ?? '';
        }

        _selectedPreventiveMeasures = List<String>.from(
          review['treatmentPlan']?['preventiveMeasures'] ?? [],
        );
      }
    });
  }

  Widget _buildImageGrid() {
    final images = widget.request['images'] as List<dynamic>;
    return Column(
      children: [
        // Toggle button for bounding boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Show Bounding Boxes'),
            Switch(
              value: _showBoundingBoxes,
              onChanged: (value) {
                setState(() {
                  _showBoundingBoxes = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final image = images[index];
            final imagePath = image['path'] as String;
            final detections =
                (image['detections'] as List<dynamic>?)
                    ?.where(
                      (d) =>
                          d != null &&
                          d['disease'] != null &&
                          d['confidence'] != null,
                    )
                    .toList() ??
                [];

            return GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => Dialog(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final imageWidth = constraints.maxWidth;
                            final imageHeight = constraints.maxHeight;
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(imagePath),
                                    fit: BoxFit.contain,
                                    width: imageWidth,
                                    height: imageHeight,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.image_not_supported,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (_showBoundingBoxes)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        detections.isNotEmpty
                                            ? '${detections.length} Detections'
                                            : 'No Detections',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported),
                        );
                      },
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
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        detections.isNotEmpty
                            ? '${detections.length} Detections'
                            : 'No Detections',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // Helper to merge disease summary entries with the same disease
  List<Map<String, dynamic>> _mergeDiseaseSummary(List<dynamic> summary) {
    final Map<String, Map<String, dynamic>> merged = {};
    for (final entry in summary) {
      final disease = entry['label'] ?? entry['disease'] ?? entry['name'];
      final count = entry['count'] ?? 0;
      final percentage = entry['percentage'] ?? 0.0;
      if (!merged.containsKey(disease)) {
        merged[disease] = {
          'disease': disease,
          'count': count,
          'percentage': percentage,
        };
      } else {
        merged[disease]!['count'] += count;
        merged[disease]!['percentage'] += percentage;
      }
    }
    return merged.values.toList();
  }

  Widget _buildDiseaseSummary() {
    final rawSummary = widget.request['diseaseSummary'] as List<dynamic>? ?? [];
    final diseaseSummary = _mergeDiseaseSummary(rawSummary);
    final totalLeaves = diseaseSummary.fold<int>(
      0,
      (sum, disease) => sum + (disease['count'] as int? ?? 0),
    );

    // Sort diseases by percentage in descending order
    final sortedDiseases =
        diseaseSummary.toList()..sort((a, b) {
          final percentageA =
              (a['count'] as int? ?? 0) / (totalLeaves == 0 ? 1 : totalLeaves);
          final percentageB =
              (b['count'] as int? ?? 0) / (totalLeaves == 0 ? 1 : totalLeaves);
          return percentageB.compareTo(percentageA);
        });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Disease Summary',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...sortedDiseases.map((disease) {
          final diseaseName = disease['disease']?.toString() ?? 'Unknown';
          final color = _getDiseaseColor(diseaseName);
          final count = disease['count'] as int? ?? 0;
          final percentage = totalLeaves == 0 ? 0.0 : count / totalLeaves;
          final isHealthy = diseaseName.toLowerCase() == 'healthy';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                if (isHealthy) {
                  _showHealthyStatus(context);
                } else {
                  _showDiseaseRecommendations(context, diseaseName);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              isHealthy
                                  ? Icons.check_circle
                                  : Icons.local_florist,
                              size: 16,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _formatExpertLabel(diseaseName),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$count found',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Percentage of Total Leaves',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: percentage,
                                  backgroundColor: color.withOpacity(0.1),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    color,
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(percentage * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showHealthyStatus(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Healthy Leaves',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Plant Health Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStatusSection('Current Status', [
                          'Leaves show no signs of disease',
                          'Normal leaf color and texture',
                          'Proper leaf development',
                          'No visible damage or discoloration',
                        ]),
                        const SizedBox(height: 16),
                        _buildStatusSection('Maintenance Tips', [
                          'Continue regular watering schedule',
                          'Maintain proper fertilization',
                          'Monitor for any changes in leaf appearance',
                          'Keep up with regular pruning',
                          'Ensure adequate sunlight exposure',
                        ]),
                        const SizedBox(height: 16),
                        _buildStatusSection('Preventive Care', [
                          'Regular plant inspection',
                          'Maintain optimal growing conditions',
                          'Proper spacing between plants',
                          'Good air circulation',
                          'Regular soil testing',
                        ]),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _showDiseaseRecommendations(BuildContext context, String diseaseName) {
    final Map<String, Map<String, dynamic>> diseaseInfo = {
      'anthracnose': {
        'symptoms': [
          'Irregular black or brown spots that expand and merge, leading to necrosis and leaf drop (Li et al., 2024).',
        ],
        'treatments': [
          'Apply copper-based fungicides like copper oxychloride or Mancozeb during wet and humid conditions to prevent spore germination.',
          'Prune mango trees regularly to improve air circulation and reduce humidity around foliage.',
          'Remove and burn infected leaves to limit reinfection cycles.',
        ],
      },
      'powdery_mildew': {
        'symptoms': [
          'A white, powdery fungal coating forms on young mango leaves, leading to distortion, yellowing, and reduced photosynthesis (Nasir, 2016).',
        ],
        'treatments': [
          'Use sulfur-based or systemic fungicides like tebuconazole at the first sign of infection and repeat at 10–14-day intervals.',
          'Avoid overhead irrigation which increases humidity and spore spread on leaf surfaces.',
          'Remove heavily infected leaves to reduce fungal load.',
        ],
      },
      'dieback': {
        'symptoms': [
          'Browning of leaf tips, followed by downward necrosis and eventual branch dieback (Ploetz, 2003).',
        ],
        'treatments': [
          'Prune affected twigs at least 10 cm below the last symptom to halt pathogen progression.',
          'Apply systemic fungicides such as carbendazim to protect surrounding healthy leaves.',
          'Maintain plant vigor through balanced nutrition and irrigation to resist infection.',
        ],
      },
      'backterial_blackspot': {
        'symptoms': [
          'Small, water-soaked lesions that turn black and angular, often surrounded by yellow halos (Pruvost et al., 2014).',
        ],
        'treatments': [
          'Apply copper-based bactericides at the first sign of infection.',
          'Avoid overhead irrigation and minimize leaf wetness.',
          'Remove and destroy infected plant material.',
        ],
      },
      'tip_burn': {
        'symptoms': [
          'Browning and necrosis of leaf margins and tips, often due to environmental stress or nutrient imbalance.',
        ],
        'treatments': [
          'Maintain consistent soil moisture and avoid drought stress.',
          'Ensure proper calcium and magnesium levels in soil.',
          'Protect plants from excessive heat and wind exposure.',
        ],
      },
    };

    final info = diseaseInfo[diseaseName.toLowerCase()];
    if (info == null) return;

    // Convert internal name to display name
    String displayName = diseaseName;
    if (diseaseName.toLowerCase() == 'backterial_blackspot') {
      displayName = 'Bacterial Blackspot';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Symptoms',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...info['symptoms'].map(
                          (symptom) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(symptom)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Recommended Treatments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...info['treatments'].map(
                          (treatment) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 20,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(treatment)),
                              ],
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

  Widget _buildStatusSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Expert Review',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // Severity Assessment
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Severity Assessment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedSeverity,
                  decoration: const InputDecoration(
                    labelText: 'Select Severity Level',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      ['low', 'medium', 'high']
                          .map(
                            (level) => DropdownMenuItem(
                              value: level,
                              child: Text(level.toUpperCase()),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSeverity = value!;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Treatment Plan
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Treatment Plan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _treatmentController,
                  decoration: const InputDecoration(
                    labelText: 'Recommended Treatment',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _dosageController,
                  decoration: const InputDecoration(
                    labelText: 'Dosage',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _frequencyController,
                  decoration: const InputDecoration(
                    labelText: 'Application Frequency',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _precautionsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Precautions',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Preventive Measures
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preventive Measures',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _preventiveMeasures.map((measure) {
                        final isSelected = _selectedPreventiveMeasures.contains(
                          measure,
                        );
                        return FilterChip(
                          label: Text(measure),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedPreventiveMeasures.add(measure);
                              } else {
                                _selectedPreventiveMeasures.remove(measure);
                              }
                            });
                          },
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Expert Comment
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expert Comment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        'Enter your expert analysis and recommendations...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                _isSubmitting
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text(
                      'Submit Review',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedReview() {
    final review = widget.request['expertReview'];
    if (review == null) {
      return const Center(child: Text('No review data available'));
    }

    if (_isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Edit Expert Review',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _cancelEditing,
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildReviewForm(),
        ],
      );
    }

    final severity = review['severityAssessment']?['level'] ?? 'medium';
    final recommendations =
        review['treatmentPlan']?['recommendations'] as List?;
    final preventiveMeasures =
        review['treatmentPlan']?['preventiveMeasures'] as List?;
    final comment = review['comment'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Expert Review',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _startEditing,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Review'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Severity Assessment
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Severity Assessment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.warning, color: _getSeverityColor(severity)),
                    const SizedBox(width: 8),
                    Text(
                      severity.toString().toUpperCase(),
                      style: TextStyle(
                        color: _getSeverityColor(severity),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Treatment Plan
        if (recommendations != null && recommendations.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Treatment Plan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...recommendations.map((treatment) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (treatment['treatment'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Treatment: ${treatment['treatment']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (treatment['dosage'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('Dosage: ${treatment['dosage']}'),
                          ),
                        if (treatment['frequency'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('Frequency: ${treatment['frequency']}'),
                          ),
                        if (treatment['precautions'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Precautions: ${treatment['precautions']}',
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        // Preventive Measures
        if (preventiveMeasures != null && preventiveMeasures.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preventive Measures',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        preventiveMeasures.map<Widget>((measure) {
                          return Chip(
                            label: Text(measure.toString()),
                            backgroundColor: Colors.green.withOpacity(0.1),
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        // Expert Comment
        if (comment.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expert Comment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comment,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Color _getDiseaseColor(String diseaseName) {
    final Map<String, Color> diseaseColors = {
      'anthracnose': Colors.orange,
      'backterial_blackspot': Colors.purple,
      'dieback': Colors.red,
      'healthy': Color.fromARGB(255, 2, 119, 252),
      'powdery_mildew': Color.fromARGB(255, 9, 46, 2),
      'tip_burn': Colors.brown,
      'Unknown': Colors.grey,
    };
    return diseaseColors[diseaseName.toLowerCase()] ?? Colors.grey;
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<Size> _getImageSize(ImageProvider provider) async {
    final Completer<Size> completer = Completer();
    final ImageStreamListener listener = ImageStreamListener((
      ImageInfo info,
      bool _,
    ) {
      final myImage = info.image;
      completer.complete(
        Size(myImage.width.toDouble(), myImage.height.toDouble()),
      );
    });
    provider.resolve(const ImageConfiguration()).addListener(listener);
    final size = await completer.future;
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.request['userName']?.toString() ?? 'Asif';
    final submittedAt = widget.request['submittedAt']?.toString() ?? '';
    final reviewedAt =
        widget.request['expertReview']?['reviewedAt']?.toString() ?? '';
    final isCompleted = widget.request['status']?.toString() == 'reviewed';
    final totalImages = widget.request['images']?.length ?? 0;
    final totalDetections = widget.request['diseaseSummary']?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          'Analysis Review',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User and timestamp info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                color: Colors.grey[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Submitted:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            submittedAt.isNotEmpty ? submittedAt : '-',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      if (isCompleted && reviewedAt.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Reviewed:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              reviewedAt,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Metadata
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Images',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$totalImages',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Detections',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$totalDetections',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Analyzed Images',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildImageGrid(),
                ],
              ),
            ),
            // Disease Summary
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildDiseaseSummary(),
            ),
            // Review Section
            Padding(
              padding: const EdgeInsets.all(16),
              child:
                  widget.request['status']?.toString() == 'pending'
                      ? _buildReviewForm()
                      : _buildCompletedReview(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatExpertLabel(String label) {
    switch (label.toLowerCase()) {
      case 'backterial_blackspot':
      case 'bacterial blackspot':
      case 'bacterial black spot':
        return 'Bacterial black spot';
      case 'powdery_mildew':
      case 'powdery mildew':
        return 'Powdery Mildew';
      case 'tip_burn':
      case 'tip burn':
        return 'Tip Burn';
      default:
        return label
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) =>
                  word.isNotEmpty
                      ? word[0].toUpperCase() + word.substring(1)
                      : '',
            )
            .join(' ');
    }
  }
}
