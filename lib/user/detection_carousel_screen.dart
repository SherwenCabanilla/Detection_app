import 'package:flutter/material.dart';
import 'dart:io';
import 'detection_screen.dart';
import 'detection_painter.dart';
import 'tflite_detector.dart';
import 'detection_result_card.dart';
import 'analysis_summary_screen.dart';

class DetectionCarouselScreen extends StatefulWidget {
  final List<String> imagePaths;
  final Function(int)? onProgressUpdate;
  final Map<int, List<DetectionResult>>? initialResults;
  final Map<int, Size>? initialImageSizes;

  const DetectionCarouselScreen({
    Key? key,
    required this.imagePaths,
    this.onProgressUpdate,
    this.initialResults,
    this.initialImageSizes,
  }) : super(key: key);

  @override
  State<DetectionCarouselScreen> createState() =>
      _DetectionCarouselScreenState();
}

class _DetectionCarouselScreenState extends State<DetectionCarouselScreen> {
  int _currentIndex = 0;
  final Map<int, List<DetectionResult>> _resultsCache = {};
  final Map<int, Size> _imageSizeCache = {};
  bool _isLoading = true;
  final Map<int, Widget> _cachedScreens = {};
  int _processedImages = 0;
  late final PageController _pageController;
  bool showBoundingBoxes = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    if (widget.initialResults != null && widget.initialImageSizes != null) {
      _resultsCache.addAll(widget.initialResults!);
      _imageSizeCache.addAll(widget.initialImageSizes!);
      _buildCachedScreens();
      setState(() => _isLoading = false);
    } else {
      _preloadAllImages();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _preloadAllImages() async {
    final detector = TFLiteDetector();
    await detector.loadModel();

    // Process images sequentially to ensure proper progress updates
    for (int index = 0; index < widget.imagePaths.length; index++) {
      try {
        final results = await detector.detectDiseases(widget.imagePaths[index]);
        final image = File(widget.imagePaths[index]);
        final decodedImage = await image.readAsBytes();
        final imageInfo = await decodeImageFromList(decodedImage);

        setState(() {
          _resultsCache[index] = results;
          _imageSizeCache[index] = Size(
            imageInfo.width.toDouble(),
            imageInfo.height.toDouble(),
          );

          // Pre-build the detection screen
          _cachedScreens[index] = DetectionScreen(
            imagePath: widget.imagePaths[index],
            showAppBar: false,
            results: results,
            imageSize: _imageSizeCache[index]!,
          );

          _processedImages++;
        });

        // Update progress in the loading dialog immediately
        widget.onProgressUpdate?.call(_processedImages);
      } catch (e) {
        print('Error processing image $index: $e');
        // Continue with next image even if one fails
        setState(() {
          _processedImages++;
        });
        widget.onProgressUpdate?.call(_processedImages);
      }
    }

    detector.closeModel();
    setState(() => _isLoading = false);
  }

  void _buildCachedScreens() {
    for (int index = 0; index < widget.imagePaths.length; index++) {
      _cachedScreens[index] = DetectionScreen(
        imagePath: widget.imagePaths[index],
        showAppBar: false,
        results: _resultsCache[index] ?? [],
        imageSize: _imageSizeCache[index]!,
      );
    }
  }

  Map<String, int> _getOverallResults() {
    final Map<String, int> overallCounts = {};
    for (var results in _resultsCache.values) {
      for (var result in results) {
        overallCounts[result.label] = (overallCounts[result.label] ?? 0) + 1;
      }
    }
    return overallCounts;
  }

  Widget _buildResultsList(List<DetectionResult> results) {
    // Group detections by label
    final Map<String, List<DetectionResult>> grouped = {};
    for (var result in results) {
      grouped.putIfAbsent(result.label, () => []).add(result);
    }
    final groupedEntries = grouped.entries.toList();
    final totalLeaves = results.length;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedEntries.length,
      itemBuilder: (context, index) {
        final label = groupedEntries[index].key;
        final detections = groupedEntries[index].value;
        final count = detections.length;
        final percentage = count / totalLeaves;
        // Use the first detection as a representative for the card
        final representative = detections.first;
        return DetectionResultCard(
          result: representative,
          count: count,
          percentage: percentage,
          onTap: () {
            // TODO: Navigate to detailed disease information
          },
        );
      },
    );
  }

  Widget _buildImageWithBoundingBox(
    BuildContext context,
    String imagePath,
    List<DetectionResult> results,
    Size imageSize,
    bool showBoundingBoxes,
    Function() onTap,
  ) {
    print('🖼️ Building image with ${results.length} bounding boxes');
    print('🖼️ Image size: $imageSize');

    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final widgetW = constraints.maxWidth;
          final widgetH = constraints.maxHeight;
          final imgW = imageSize.width;
          final imgH = imageSize.height;

          if (imgW == 0 || imgH == 0) {
            return const Center(child: CircularProgressIndicator());
          }

          // Calculate scale and offset for BoxFit.contain (not cover)
          final widgetAspect = widgetW / widgetH;
          final imageAspect = imgW / imgH;
          double displayW, displayH, dx = 0, dy = 0;

          // Use contain logic for more accurate bounding box placement
          if (widgetAspect > imageAspect) {
            // Widget is wider than image - height constrained
            displayH = widgetH;
            displayW = widgetH * imageAspect;
            dx = (widgetW - displayW) / 2;
          } else {
            // Widget is taller than image - width constrained
            displayW = widgetW;
            displayH = widgetW / imageAspect;
            dy = (widgetH - displayH) / 2;
          }

          print('📏 Widget dimensions: ${widgetW}x${widgetH}');
          print('📏 Image dimensions: ${imgW}x${imgH}');
          print('📏 Displayed dimensions: ${displayW}x${displayH}');
          print('📏 Offset: ($dx, $dy)');

          final displayedImageSize = Size(displayW, displayH);
          final displayedImageOffset = Offset(dx, dy);

          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain, // Use contain to match the calculations
                ),
              ),
              if (showBoundingBoxes && results.isNotEmpty)
                CustomPaint(
                  painter: DetectionPainter(
                    results: results,
                    originalImageSize: imageSize,
                    displayedImageSize: displayedImageSize,
                    displayedImageOffset: displayedImageOffset,
                    debugMode: true, // Enable debug mode for visibility
                  ),
                  size: Size(widgetW, widgetH),
                ),
              if (results.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${results.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Processing Images',
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.green,
          elevation: 0,
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: _processedImages / widget.imagePaths.length,
                      ),
                      duration: const Duration(milliseconds: 400),
                      builder: (context, value, child) {
                        return CircularProgressIndicator(
                          value: value,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.green,
                          ),
                          strokeWidth: 3,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Analyzing Images',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Processing image $_processedImages of ${widget.imagePaths.length}',
                  style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we analyze your images...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _processedImages / widget.imagePaths.length,
                          backgroundColor: Colors.green.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.green,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${((_processedImages / widget.imagePaths.length) * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
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

    final overallResults = _getOverallResults();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Analysis Results'),
        centerTitle: true,
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Ink(
              decoration: BoxDecoration(
                color: showBoundingBoxes ? Colors.green[700] : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    showBoundingBoxes = !showBoundingBoxes;
                  });
                },
                icon: Icon(Icons.visibility, color: Colors.white),
                tooltip:
                    showBoundingBoxes
                        ? 'Hide Bounding Boxes'
                        : 'Show Bounding Boxes',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.summarize),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => AnalysisSummaryScreen(
                        allResults: _resultsCache,
                        imagePaths: widget.imagePaths,
                      ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 300, // Increased height for the image carousel
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imagePaths.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final results = _resultsCache[index] ?? [];
                final imageSize = _imageSizeCache[index] ?? const Size(1, 1);
                return Stack(
                  children: [
                    _buildImageWithBoundingBox(
                      context,
                      widget.imagePaths[index],
                      results,
                      imageSize,
                      showBoundingBoxes,
                      () {
                        // Show full screen image with bounding boxes
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              print(
                                '🔎 Opening detail view for image: ${widget.imagePaths[index]}',
                              );
                              print('🔎 Passing ${results.length} results');
                              for (var result in results) {
                                print(
                                  '🔎 Result: ${result.label} (${result.confidence}) at ${result.boundingBox}',
                                );
                              }
                              return DetectionScreen(
                                imagePath: widget.imagePaths[index],
                                results: results,
                                imageSize: imageSize,
                                showAppBar: true,
                                showBoundingBoxes: showBoundingBoxes,
                              );
                            },
                          ),
                        );
                      },
                    ),
                    if (index > 0)
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    if (index < widget.imagePaths.length - 1)
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Detected Issues',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${(_resultsCache[_currentIndex] ?? []).length} found',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildResultsList(_resultsCache[_currentIndex] ?? []),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentIndex > 0)
                ElevatedButton.icon(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green,
                    elevation: 0,
                    side: const BorderSide(color: Colors.green),
                  ),
                )
              else
                const SizedBox.shrink(),
              if (_currentIndex < widget.imagePaths.length - 1)
                ElevatedButton.icon(
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    // Ensure all images have been processed
                    if (_processedImages == widget.imagePaths.length) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => AnalysisSummaryScreen(
                                allResults: Map.from(
                                  _resultsCache,
                                ), // Create a new map to ensure data is fresh
                                imagePaths: List.from(
                                  widget.imagePaths,
                                ), // Create a new list to ensure data is fresh
                              ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please wait for all images to be processed',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class OverallSummary extends StatelessWidget {
  final Map<String, int> results;
  const OverallSummary({Key? key, required this.results}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorMap = DetectionPainter.diseaseColors;
    final totalLeaves = results.values.fold(0, (a, b) => a + b);

    return Container(
      width: double.infinity,
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall Results:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...colorMap.entries.map((entry) {
            final count = results[entry.key] ?? 0;
            if (count == 0) return SizedBox.shrink();
            final percentage = count / totalLeaves;
            return Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: entry.value,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black12),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${entry.key}: $count (${(percentage * 100).toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class DetectionLegend extends StatelessWidget {
  final List<DetectionResult> results;
  const DetectionLegend({Key? key, required this.results}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Map<String, int> labelCounts = {};
    for (var r in results) {
      labelCounts[r.label] = (labelCounts[r.label] ?? 0) + 1;
    }
    final colorMap = DetectionPainter.diseaseColors;
    final totalLeaves = results.length;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Image:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...colorMap.entries.map((entry) {
            final count = labelCounts[entry.key] ?? 0;
            final percentage = count / totalLeaves;
            return Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: entry.value,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black12),
                  ),
                ),
                Expanded(
                  child: Text(
                    count > 0
                        ? '${entry.key} ($count - ${(percentage * 100).toStringAsFixed(1)}%)'
                        : entry.key,
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
