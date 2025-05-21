import 'package:flutter/material.dart';
import 'tflite_detector.dart';
import 'detection_painter.dart';

class DetectionResultCard extends StatelessWidget {
  final DetectionResult result;
  final int? count;
  final double? percentage;
  final VoidCallback? onTap;

  const DetectionResultCard({
    Key? key,
    required this.result,
    this.count,
    this.percentage,
    this.onTap,
  }) : super(key: key);

  Color get diseaseColor {
    return DetectionPainter.diseaseColors[result.label] ?? Colors.grey;
  }

  String _formatLabel(String label) {
    switch (label.toLowerCase()) {
      case 'backterial_blackspot':
        return 'Bacterial black spot';
      case 'powdery_mildew':
        return 'Powdery Mildew';
      case 'tip_burn':
        return 'Tip Burn';
      default:
        return label
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  IconData _getSeverityIcon() {
    if (percentage != null) {
      if (percentage! > 0.8) return Icons.warning_amber_rounded;
      if (percentage! > 0.5) return Icons.warning_rounded;
      return Icons.info_outline;
    }
    return Icons.info_outline;
  }

  // Disease information (copied from homepage)
  static const Map<String, Map<String, dynamic>> diseaseInfo = {
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
        'Angular black lesions with yellow halos often appear along veins and can lead to early leaf drop (Ploetz, 2003).',
      ],
      'treatments': [
        'Apply copper hydroxide or copper oxychloride sprays to suppress bacterial activity on the leaf surface.',
        'Remove and properly dispose of infected leaves to reduce inoculum sources.',
        'Avoid causing wounds on leaves during handling, as these can be entry points for bacteria.',
      ],
    },
    'healthy': {
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
    'tip_burn': {
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

  void _showDiseaseRecommendations(BuildContext context) {
    final label = result.label.toLowerCase();
    final info = diseaseInfo[label];
    final isHealthy = label == 'healthy';
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
                            Icon(
                              isHealthy
                                  ? Icons.check_circle
                                  : Icons.medical_services_outlined,
                              color: isHealthy ? Colors.green : diseaseColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _formatLabel(result.label),
                                style: const TextStyle(
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
                        if (info != null) ...[
                          const Text(
                            'Symptoms',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...info['symptoms'].map<Widget>(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '• $s',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Treatment & Recommendations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...info['treatments'].map<Widget>(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '• $t',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                        ] else ...[
                          const Text('No detailed information available.'),
                        ],
                      ],
                    ),
                  ),
                ),
          ),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(
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
                        const SizedBox(height: 40),
                        const Center(
                          child: Text(
                            'N/A',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'No additional information for healthy leaves.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHealthy = result.label.toLowerCase() == 'healthy';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap:
            () =>
                isHealthy
                    ? _showHealthyStatus(context)
                    : _showDiseaseRecommendations(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: diseaseColor.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: diseaseColor, width: 2),
                    ),
                    child: Icon(
                      isHealthy ? Icons.check_circle : _getSeverityIcon(),
                      color: diseaseColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _formatLabel(result.label),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (count != null && count! > 1) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: diseaseColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'x$count',
                                  style: TextStyle(
                                    color: diseaseColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (percentage != null)
                          Text(
                            'Percentage: ${(percentage! * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: diseaseColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isHealthy
                          ? Icons.info_outline
                          : Icons.medical_services_outlined,
                      color: diseaseColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isHealthy ? 'View Status' : 'See Recommendation',
                      style: TextStyle(
                        color: diseaseColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
