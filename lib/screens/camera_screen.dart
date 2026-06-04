import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/pest_detection_service.dart';

// ─────────────────────────────────────────────
//  Design tokens — change once, applies everywhere
// ─────────────────────────────────────────────
class _AppColors {
  // Backgrounds
  static const bg = Color(0xFFF6FBF6); // soft green-tinted background
  static const surface = Color(0xFFFFFFFF); // cards, dialogs
  static const surfaceAlt = Color(0xFFF0FDF4); // light green surface
  static const border = Color(0xFFD1E7D6); // subtle green border

  // Brand / Nature colors
  static const accent = Color(0xFF22C55E); // primary green
  static const accentSoft = Color(0xFF4ADE80); // lighter green
  static const accentDim = Color(0xFF166534); // deep green

  // Text
  static const textPrimary = Color(0xFF1F2937); // dark gray
  static const textSecondary = Color(0xFF4B5563); // medium gray
  static const textMuted = Color(0xFF6B7280); // muted gray

  // Status
  static const danger = Color(0xFFDC2626); // red
  static const info = Color(0xFF2563EB); // blue
}

// ─────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────

/// Parses the result text and returns a list of {label, body} maps
/// so each section (Ugonjwa, Dalili, Kitendo, Kinga …) can be
/// rendered in its own styled bubble.
List<Map<String, String>> _parseSections(String text) {
  final sectionKeys = [
    'Ugonjwa',
    'Dalili',
    'Kitendo',
    'Kinga',
    'Ushauri',
    'Ulichagua',
  ];
  final lines = text.split('\n');
  final sections = <Map<String, String>>[];
  String currentLabel = '';
  final buffer = StringBuffer();

  void flush() {
    final body = buffer.toString().trim();
    if (body.isNotEmpty) {
      sections.add({'label': currentLabel, 'body': body});
    }
    buffer.clear();
  }

  for (final line in lines) {
    final trimmed = line.trim();
    bool matched = false;
    for (final key in sectionKeys) {
      if (trimmed.startsWith('$key:') || trimmed.startsWith('💡 $key:')) {
        flush();
        currentLabel = key;
        final rest = trimmed
            .replaceFirst(RegExp(r'^(💡 )?' + key + r':'), '')
            .trim();
        if (rest.isNotEmpty) buffer.writeln(rest);
        matched = true;
        break;
      }
    }
    if (!matched) {
      buffer.writeln(line);
    }
  }
  flush();
  return sections;
}

IconData _iconForLabel(String label) {
  switch (label) {
    case 'Ugonjwa':
      return Icons.biotech_rounded;
    case 'Dalili':
      return Icons.warning_amber_rounded;
    case 'Kitendo':
      return Icons.build_rounded;
    case 'Kinga':
      return Icons.shield_rounded;
    case 'Ushauri':
      return Icons.lightbulb_rounded;
    case 'Ulichagua':
      return Icons.check_circle_rounded;
    default:
      return Icons.info_rounded;
  }
}

Color _colorForLabel(String label) {
  switch (label) {
    case 'Ugonjwa':
      return const Color(0xFFFF6B6B);
    case 'Dalili':
      return const Color(0xFFFFB347);
    case 'Kitendo':
      return const Color(0xFF60A5FA);
    case 'Kinga':
      return _AppColors.accent;
    case 'Ushauri':
      return const Color(0xFFA78BFA);
    case 'Ulichagua':
      return _AppColors.accentSoft;
    default:
      return _AppColors.textSecondary;
  }
}

// ─────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with TickerProviderStateMixin {
  File? _capturedImage;
  bool _isProcessing = false;
  String _displayText = '';
  String _fullText = '';
  int _typingIndex = 0;
  bool _isTyping = false;
  final ImagePicker _picker = ImagePicker();
  PestDetectionResult? _lastResult;

  late final AnimationController _pulseController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Image capture ────────────────────────────
  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo != null) await _saveAndDetect(photo);
    } catch (e) {
      _showError('Camera error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) await _saveAndDetect(image);
    } catch (e) {
      _showError('Gallery error: $e');
    }
  }

  Future<void> _saveAndDetect(XFile file) async {
    final appDir = await getApplicationDocumentsDirectory();
    final saved = await File(file.path).copy(
      path.join(
        appDir.path,
        'pest_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    );
    setState(() {
      _capturedImage = saved;
      _displayText = '';
      _fullText = '';
      _typingIndex = 0;
      _isTyping = false;
      _lastResult = null;
    });
    _fadeController.forward(from: 0);
    _detectPest();
  }

  // ── Detection ────────────────────────────────
  Future<void> _detectPest() async {
    if (_capturedImage == null) return;
    setState(() => _isProcessing = true);
    try {
      final result = await PestDetectionService().predict(_capturedImage!);
      setState(() {
        _isProcessing = false;
        _lastResult = result;
        if (result.isSuccess) {
          _fullText = '${result.message}\n\n${result.advice ?? ''}';
          _startTyping();
        } else if (result.alternatives.isNotEmpty) {
          _showManualSelection(result.alternatives);
        } else {
          _fullText = result.message;
          _startTyping();
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _fullText = 'Hitilafu: $e';
        _startTyping();
      });
    }
  }

  // ── Typing animation (fast: 8ms/char) ────────
  void _startTyping() {
    setState(() {
      _displayText = '';
      _typingIndex = 0;
      _isTyping = true;
    });
    _typeNext();
  }

  void _typeNext() {
    if (_typingIndex < _fullText.length) {
      // Chunk 3 chars per tick for Claude-like speed
      final end = (_typingIndex + 3).clamp(0, _fullText.length);
      setState(() {
        _displayText = _fullText.substring(0, end);
        _typingIndex = end;
      });
      Future.delayed(const Duration(milliseconds: 8), _typeNext);
    } else {
      setState(() => _isTyping = false);
    }
  }

  // ── Manual selection sheet ───────────────────
  void _showManualSelection(List<AlternativeClass> alts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Icon(
                      Icons.manage_search_rounded,
                      color: _AppColors.accent,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Chagua Ugonjwa',
                      style: TextStyle(
                        color: _AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Warning card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        color: Colors.amber.shade700,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Matokeo Hayajathibitishwa',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mfumo haujaweza kutambua ugonjwa au wadudu kwa uhakika kutoka kwenye picha hii. Tafadhali chagua ugonjwa unaofanana zaidi na dalili zilizopo.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                ...alts.map(
                  (a) => _AltTile(
                    alt: a,
                    onTap: () async {
                      Navigator.pop(ctx);

                      final advice = await _getAdviceForClass(a.name);

                      setState(() {
                        _fullText = 'Ulichagua: ${a.displayName}\n\n$advice';
                        _startTyping();
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<String> _getAdviceForClass(String className) async {
    final service = PestDetectionService();
    await service.loadModel();
    return await service.getAdviceForClass(className);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: _AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _clear() {
    setState(() {
      _capturedImage = null;
      _displayText = '';
      _fullText = '';
      _typingIndex = 0;
      _isTyping = false;
      _lastResult = null;
    });
    _fadeController.reset();
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.bg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _capturedImage == null
                  ? _buildEmptyState()
                  : _buildResultView(),
            ),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _AppColors.bg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: _capturedImage != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: _AppColors.textSecondary,
              onPressed: _clear,
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _AppColors.accentDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.eco_rounded,
              color: _AppColors.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'WaduduScan AI',
            style: TextStyle(
              color: _AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        if (_capturedImage != null && !_isTyping && _displayText.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: _AppColors.textSecondary,
            tooltip: 'Changanua tena',
            onPressed: _detectPest,
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Empty State ──────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: _AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: _AppColors.border, width: 1.5),
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              size: 42,
              color: _AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Piga Picha au Chagua',
            style: TextStyle(
              color: _AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'AI itachunguza mmea wako na kutoa ushauri kamili wa kilimo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Feature chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: const [
              _FeatureChip(icon: Icons.bolt_rounded, label: 'Haraka'),
              _FeatureChip(icon: Icons.verified_rounded, label: 'Sahihi'),
              _FeatureChip(icon: Icons.translate_rounded, label: 'Kiswahili'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Result View ──────────────────────────────
  Widget _buildResultView() {
    final sections = _parseSections(_displayText);
    return FadeTransition(
      opacity: _fadeAnim,
      child: CustomScrollView(
        slivers: [
          // Image hero
          SliverToBoxAdapter(child: _buildImageHero()),

          // Processing indicator
          if (_isProcessing) SliverToBoxAdapter(child: _buildProcessingCard()),

          // AI response header
          if (_displayText.isNotEmpty && !_isProcessing)
            SliverToBoxAdapter(child: _buildResponseHeader()),

          // Section cards
          if (sections.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _SectionCard(
                  label: sections[i]['label'] ?? '',
                  body: sections[i]['body'] ?? '',
                ),
                childCount: sections.length,
              ),
            )
          else if (_displayText.isNotEmpty && !_isProcessing)
            // Fallback: plain text bubble if no sections detected
            SliverToBoxAdapter(child: _buildPlainTextCard()),

          // Typing cursor row
          if (_isTyping)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 8),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, _) => Opacity(
                    opacity: _pulseController.value,
                    child: Container(
                      width: 10,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _AppColors.accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  // ── Image hero ───────────────────────────────
  Widget _buildImageHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.file(_capturedImage!, fit: BoxFit.cover),
            ),
            // Subtle bottom gradient
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                  ),
                ),
              ),
            ),
            // Badge
            Positioned(
              bottom: 12,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.image_rounded, size: 12, color: Colors.white70),
                    SizedBox(width: 5),
                    Text(
                      'Picha iliyochaguliwa',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Processing card ──────────────────────────
  Widget _buildProcessingCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AppColors.border),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, child) => Opacity(
              opacity: 0.5 + _pulseController.value * 0.5,
              child: child,
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _AppColors.accentDim,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: _AppColors.accent,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WaduduScan AI inachunguza...',
                  style: TextStyle(
                    color: _AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, _) {
                    final dots =
                        '.' *
                        (1 + (_pulseController.value * 3).floor().clamp(0, 2));
                    return Text(
                      'Inachanganua picha$dots',
                      style: const TextStyle(
                        color: _AppColors.textMuted,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation(_AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  // ── Response header ──────────────────────────
  Widget _buildResponseHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _AppColors.accentDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.eco_rounded,
              color: _AppColors.accent,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'WaduduScan AI',
            style: TextStyle(
              color: _AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _AppColors.accentDim,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Mshauri wa Kilimo',
              style: TextStyle(
                color: _AppColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Plain text fallback ──────────────────────
  Widget _buildPlainTextCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AppColors.border),
      ),
      child: Text(
        _displayText,
        style: const TextStyle(
          color: _AppColors.textPrimary,
          fontSize: 14,
          height: 1.7,
        ),
      ),
    );
  }

  // ── Action Bar ───────────────────────────────
  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: _AppColors.bg,
        border: Border(top: BorderSide(color: _AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Camera
          Expanded(
            child: _ActionButton(
              icon: Icons.camera_alt_rounded,
              label: 'Kamera',
              color: _AppColors.accent,
              onTap: _takePicture,
            ),
          ),
          const SizedBox(width: 10),
          // Gallery
          Expanded(
            child: _ActionButton(
              icon: Icons.photo_library_rounded,
              label: 'Nyaraka',
              color: _AppColors.info,
              onTap: _pickFromGallery,
            ),
          ),
          if (_capturedImage != null) ...[
            const SizedBox(width: 10),
            // Clear
            _ActionButton(
              icon: Icons.delete_outline_rounded,
              label: 'Futa',
              color: _AppColors.danger,
              onTap: _clear,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Section Card Widget
// ─────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String label;
  final String body;
  const _SectionCard({required this.label, required this.body});

  @override
  Widget build(BuildContext context) {
    final color = _colorForLabel(label);
    final icon = _iconForLabel(label);
    final isFirst = label == 'Ugonjwa' || label == 'Ulichagua';

    return Container(
      margin: EdgeInsets.fromLTRB(16, isFirst ? 8 : 6, 16, 0),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: _FormattedBody(text: body, accentColor: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Formatted Body — renders numbered lists,
//  bold keywords, and plain paragraphs
// ─────────────────────────────────────────────
class _FormattedBody extends StatelessWidget {
  final String text;
  final Color accentColor;
  const _FormattedBody({required this.text, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Numbered list item: "1.", "2.", etc.
      final numberedMatch = RegExp(r'^(\d+)\.\s+(.+)').firstMatch(line);
      if (numberedMatch != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1, right: 10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      numberedMatch.group(1)!,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    numberedMatch.group(2)!,
                    style: const TextStyle(
                      color: _AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.65,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Dash list item: "- ..." or "• ..."
      final dashMatch = RegExp(r'^[-•]\s+(.+)').firstMatch(line);
      if (dashMatch != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 10),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    dashMatch.group(1)!,
                    style: const TextStyle(
                      color: _AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.65,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Plain paragraph
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            line,
            style: const TextStyle(
              color: _AppColors.textPrimary,
              fontSize: 14,
              height: 1.7,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

// ─────────────────────────────────────────────
//  Alternative selection tile
// ─────────────────────────────────────────────
class _AltTile extends StatelessWidget {
  final AlternativeClass alt;
  final VoidCallback onTap;
  const _AltTile({required this.alt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = (alt.confidence * 100).toStringAsFixed(1);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _AppColors.accentDim,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: _AppColors.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alt.displayName,
                    style: const TextStyle(
                      color: _AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Uwezekano: $pct%',
                    style: const TextStyle(
                      color: _AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Confidence bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$pct%',
                  style: const TextStyle(
                    color: _AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: alt.confidence.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Action Button
// ─────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            if (!compact) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Feature chip (empty state)
// ─────────────────────────────────────────────
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _AppColors.accent, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
