import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Returns localized treatment bullet points for known labels.
/// Falls back to `null` if we don't have localized strings for this label.
List<String>? getLocalizedTreatments(BuildContext context, String diseaseLabel) {
  final normalized = diseaseLabel.toLowerCase().replaceAll(' ', '_').trim();

  List<String> trList(String baseKey, int count) {
    return List<String>.generate(count, (i) => tr('${baseKey}_${i + 1}'));
  }

  switch (normalized) {
    case 'anthracnose':
      return trList('treat_anthracnose', 3);
    case 'powdery_mildew':
    case 'powdery mildew':
      return trList('treat_powdery_mildew', 3);
    case 'dieback':
      return trList('treat_dieback', 3);
    case 'backterial_blackspot':
    case 'bacterial_blackspot':
    case 'bacterial_black_spot':
    case 'bacterial black spot':
      return trList('treat_bacterial_blackspot', 3);
    case 'healthy':
      return trList('treat_healthy', 3);
    default:
      return null;
  }
}

