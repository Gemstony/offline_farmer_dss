import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../providers/farm_provider.dart';
import '../providers/weather_provider.dart';
import '../models/farm_model.dart';
import '../models/weather_model.dart';
import '../widgets/loading_indicator.dart';
import '../services/ai_chat_service.dart';

class AdviceScreen extends ConsumerStatefulWidget {
  const AdviceScreen({super.key});

  @override
  ConsumerState<AdviceScreen> createState() => _AdviceScreenState();
}

class _AdviceScreenState extends ConsumerState<AdviceScreen> {
  bool _isChatOpen = false;
  List<Map<String, String>> _chatMessages = [];
  final ValueNotifier<List<Map<String, String>>> _chatMessagesNotifier =
      ValueNotifier([]);
  final ValueNotifier<bool> _isAiThinkingNotifier = ValueNotifier(false);
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final selectedFarmAsync = ref.watch(selectedFarmProvider);
    final weatherAsync = ref.watch(weatherDataProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(selectedFarmProvider);
          ref.invalidate(weatherDataProvider);
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.green.shade50, Colors.green.shade100],
            ),
          ),
          child: selectedFarmAsync.when(
            data: (farm) {
              if (farm == null) {
                return _buildEmptyState(context);
              }
              return weatherAsync.when(
                data: (weatherList) {
                  if (weatherList.isEmpty) {
                    return _buildNoWeatherState(context, ref);
                  }
                  return _buildAdviceContent(farm, weatherList, ref);
                },
                loading: () => const LoadingIndicator(),
                error: (err, stack) => _buildErrorState(
                  context,
                  'Imeshindwa kupata taarifa za hali ya hewa: $err',
                  () => ref.invalidate(weatherDataProvider),
                ),
              );
            },
            loading: () => const LoadingIndicator(),
            error: (err, stack) => _buildErrorState(
              context,
              'Imeshindwa kupata taarifa za shamba: $err',
              () => ref.invalidate(selectedFarmProvider),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openChatPanel(),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        child: const Icon(Icons.chat_bubble_outline_rounded),
        tooltip: 'Uliza AI',
      ),
    );
  }

  // ─── Open Chat Panel ──────────────────────────────────────────────
  void _openChatPanel() {
    final farm = ref.read(selectedFarmProvider).valueOrNull;
    final weather = ref.read(weatherDataProvider).valueOrNull;

    if (farm == null || weather == null || weather.isEmpty) {
      _showError('Hakuna data ya shamba au hali ya hewa.');
      return;
    }

    // Build context for AI
    final next3 = weather.take(3).toList();
    final weatherSummary = next3
        .map(
          (day) =>
              '${_formatShortDate(day.date)}: ${day.minTemp}°C – ${day.maxTemp}°C, Mvua ${day.rainfallMm} mm',
        )
        .join('\n');

    final systemPrompt =
        'You are an expert agricultural advisor for smallholder farmers in Tanzania. '
        'The farmer has the following farm:\n'
        'Crop: ${farm.cropType.toUpperCase()}\n'
        'Area: ${farm.areaHectares} hectares\n'
        'Soil type: ${farm.soilType}\n'
        'Planting date: ${_formatDate(farm.plantingDate)}\n'
        '3-day weather forecast:\n$weatherSummary\n\n'
        'Provide practical, easy‑to‑follow advice in Swahili or English. '
        'Be friendly, clear, and suggest actionable steps. '
        'If the farmer asks about something you don\'t know, suggest they contact a local agricultural officer.';

    _chatMessages = [
      {'role': 'system', 'content': systemPrompt},
      {
        'role': 'assistant',
        'content':
            '🌾 Mambo! Nina habari za shamba lako. '
            'Unaweza kuniuliza swali lolote kuhusu kilimo, mbolea, kumwagilia, au wadudu.',
      },
    ];
    _chatMessagesNotifier.value = List.from(_chatMessages);
    _isAiThinkingNotifier.value = false;
    _chatController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChatPanel(
        messagesNotifier: _chatMessagesNotifier,
        onSend: _sendChatMessage,
        isThinkingNotifier: _isAiThinkingNotifier,
        scrollController: _chatScrollController,
        onClose: () {
          setState(() => _isChatOpen = false);
        },
      ),
    ).then((_) {
      setState(() => _isChatOpen = false);
    });
    setState(() => _isChatOpen = true);
  }

  // ─── Send Message ──────────────────────────────────────────────────
  Future<void> _sendChatMessage(String userMessage) async {
    if (userMessage.trim().isEmpty) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      _showError('Huna mtandao. Tafadhali washa data au Wi‑Fi.');
      return;
    }

    _chatMessages.add({'role': 'user', 'content': userMessage.trim()});
    _chatMessagesNotifier.value = List.from(_chatMessages);
    _isAiThinkingNotifier.value = true;
    _scrollToBottom();

    try {
      final service = AiChatService();
      final reply = await service.sendMessage(_chatMessages);
      _chatMessages.add({'role': 'assistant', 'content': reply});
      _chatMessagesNotifier.value = List.from(_chatMessages);
      _isAiThinkingNotifier.value = false;
      _scrollToBottom();
    } catch (e) {
      _isAiThinkingNotifier.value = false;
      _showError('Imeshindwa kupata jibu: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
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
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─── Existing UI Methods (unchanged) ──────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    // ... (keep your existing code)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.agriculture_outlined,
            size: 80,
            color: Colors.green.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            'Hakuna shamba lililochaguliwa',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tafadhali chagua au ongeza shamba kwanza',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
            label: const Text('Chagua Shamba'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/add_farm'),
            icon: const Icon(Icons.add),
            label: const Text('Ongeza Shamba Mpya'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoWeatherState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 80, color: Colors.green.shade700),
          const SizedBox(height: 16),
          Text(
            'Hakuna taarifa za hali ya hewa',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Sasisha hali ya hewa kwa kuvuta chini au bonyeza kitufe cha ku refresh',
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(weatherDataProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Sasisha Sasa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    String message,
    VoidCallback onRetry,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text('Jaribu tena'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceContent(
    Farm farm,
    List<WeatherData> weatherList,
    WidgetRef ref,
  ) {
    final recommendations = _generateRecommendations(farm, weatherList);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFarmInfoCard(farm),
          const SizedBox(height: 16),
          _buildWeatherContextCard(weatherList),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'Ushauri wako',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recommendations.map((rec) => _buildRecommendationCard(rec)),
        ],
      ),
    );
  }

  Widget _buildFarmInfoCard(Farm farm) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.green.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getCropIcon(farm.cropType),
                      color: Colors.green.shade800,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          farm.cropType.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Eneo: ${farm.areaHectares} hekta',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildInfoChip(Icons.terrain, farm.soilType)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoChip(
                      Icons.calendar_today,
                      _formatDate(farm.plantingDate),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherContextCard(List<WeatherData> weatherList) {
    final next3 = weatherList.take(3).toList();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_queue, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Hali ya hewa (siku 3 zijazo)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...next3.map(
              (day) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _getWeatherIcon(day.rainfallMm, day.maxTemp),
                      size: 24,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_formatShortDate(day.date)}: ${day.minTemp}°C – ${day.maxTemp}°C, Mvua ${day.rainfallMm} mm',
                        style: const TextStyle(fontSize: 14),
                      ),
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

  Widget _buildRecommendationCard(RecommendationItem rec) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(rec.category).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCategoryIcon(rec.category),
                      color: _getCategoryColor(rec.category),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rec.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (rec.isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'HARAKA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                rec.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<RecommendationItem> _generateRecommendations(
    Farm farm,
    List<WeatherData> forecast,
  ) {
    // ... (keep your existing logic)
    List<RecommendationItem> list = [];

    final next3Days = forecast.take(3);
    double totalRain = next3Days.fold(0, (sum, day) => sum + day.rainfallMm);

    if (totalRain < 10) {
      list.add(
        RecommendationItem(
          title: 'Kumwagilia Mazao',
          description:
              'Kiasi cha mvua kinachotarajiwa katika siku 3 zijazo ni kidogo. Inashauriwa kuanza kumwagilia mapema asubuhi au jioni ili kusaidia mimea kupata maji ya kutosha kwa ukuaji mzuri. Epuka kumwagilia wakati wa jua kali ili kupunguza upotevu wa maji.',
          category: 'irrigation',
          isUrgent: true,
        ),
      );
    } else if (totalRain > 50) {
      list.add(
        RecommendationItem(
          title: 'Tahadhari ya Mvua Kubwa',
          description:
              'Mvua kubwa inatarajiwa. Hakikisha mifereji ya kupitisha maji ipo wazi na maji hayatakusanyika shambani kwani hali hiyo inaweza kusababisha kuoza kwa mizizi, kuharibika kwa mazao au mmomonyoko wa udongo.',
          category: 'general',
          isUrgent: true,
        ),
      );
    }

    if (farm.cropType == 'maize') {
      if (farm.soilType == 'sandy') {
        list.add(
          RecommendationItem(
            title: 'Matumizi ya Mbolea kwa Mahindi',
            description:
                'Kwa udongo wa mchanga, virutubisho hupotea kwa haraka. Inashauriwa kutumia mbolea ya DAP wakati wa kupanda, kisha kuongeza UREA katika hatua ya ukuaji wa majani. Hakikisha mbolea inawekwa kwa kiwango kinachofaa na ichanganywe vizuri.',
            category: 'fertilizer',
          ),
        );
      } else if (farm.soilType == 'clay') {
        list.add(
          RecommendationItem(
            title: 'Mbolea kwa Udongo wa Mfinyanzi',
            description:
                'Udongo wa mfinyanzi huhifadhi maji na virutubisho kwa muda mrefu. Inashauriwa kupunguza matumizi ya mbolea yenye nitrojeni nyingi. Tumia zaidi mbolea yenye fosforasi na potasiamu.',
            category: 'fertilizer',
          ),
        );
      }
    }

    if (forecast.any(
      (day) => day.rainfallMm > 15 && day.humidityPercent > 70,
    )) {
      list.add(
        RecommendationItem(
          title: 'Tahadhari ya Wadudu na Magonjwa',
          description:
              'Kiwango kikubwa cha unyevu pamoja na mvua kinaweza kuongeza hatari ya kushambuliwa na wadudu au magonjwa ya mimea. Inashauriwa kufanya ukaguzi wa mara kwa mara shambani. Ondoa mimea iliyoathirika na tumia dawa sahihi pale inapohitajika.',
          category: 'pest',
          isUrgent: true,
        ),
      );
    }

    if (farm.plantingDate.isBefore(DateTime.now())) {
      final daysSincePlanting = DateTime.now()
          .difference(farm.plantingDate)
          .inDays;
      if (farm.cropType == 'maize' &&
          daysSincePlanting > 90 &&
          daysSincePlanting < 120) {
        list.add(
          RecommendationItem(
            title: 'Muda wa Kuvuna Mahindi',
            description:
                'Mahindi yako yanaonekana kufikia hatua nzuri ya kuvunwa. Angalia kama maganda yamekauka, punje zimekuwa ngumu na mmea umeanza kubadilika rangi kuelekea ukavu. Kuvuna kwa wakati husaidia kupunguza hasara.',
            category: 'harvest',
            isUrgent: false,
          ),
        );
      }
    }

    if (list.isEmpty) {
      list.add(
        RecommendationItem(
          title: 'Hali nzuri',
          description:
              'Kwa sasa hakuna ushauri maalum. Endelea kulima kwa bidii na ufuate mbinu bora za kilimo.',
          category: 'general',
          isUrgent: false,
        ),
      );
    }

    return list;
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
  String _formatShortDate(DateTime date) => '${date.day}/${date.month}';

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'irrigation':
        return Colors.blue;
      case 'fertilizer':
        return Colors.brown;
      case 'pest':
        return Colors.red;
      case 'harvest':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'irrigation':
        return Icons.water_drop;
      case 'fertilizer':
        return Icons.agriculture;
      case 'pest':
        return Icons.bug_report;
      case 'harvest':
        return Icons.agriculture;
      default:
        return Icons.lightbulb;
    }
  }

  IconData _getWeatherIcon(double rain, double maxTemp) {
    if (rain > 20) return Icons.grain;
    if (rain > 5) return Icons.cloud_queue;
    if (maxTemp > 30) return Icons.wb_sunny;
    return Icons.wb_cloudy;
  }

  IconData _getCropIcon(String crop) {
    switch (crop.toLowerCase()) {
      case 'maize':
        return Icons.grass;
      case 'rice':
        return Icons.agriculture;
      case 'beans':
        return Icons.eco;
      case 'cassava':
        return Icons.forest;
      case 'tomatoes':
        return Icons.local_florist;
      default:
        return Icons.agriculture;
    }
  }
}

// ──────────────────────────────────────────────────────────────────────
//  Chat Panel Widgets (reused from camera screen)
// ──────────────────────────────────────────────────────────────────────

class _ChatPanel extends StatefulWidget {
  final ValueListenable<List<Map<String, String>>> messagesNotifier;
  final ValueListenable<bool> isThinkingNotifier;
  final Future<void> Function(String) onSend;
  final ScrollController scrollController;
  final VoidCallback onClose;

  const _ChatPanel({
    required this.messagesNotifier,
    required this.isThinkingNotifier,
    required this.onSend,
    required this.scrollController,
    required this.onClose,
  });

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final TextEditingController _inputController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = keyboardInset > 0
        ? screenHeight - keyboardInset - MediaQuery.of(context).padding.top - 16
        : screenHeight * 0.8;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF6FBF6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1E7D6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF166534),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF22C55E),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Mshauri wa AI',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: const Color(0xFF4B5563),
                  onPressed: () {
                    widget.onClose();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFD1E7D6)),
          Expanded(
            child: ValueListenableBuilder<List<Map<String, String>>>(
              valueListenable: widget.messagesNotifier,
              builder: (context, messages, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: widget.isThinkingNotifier,
                  builder: (context, isThinking, _) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (widget.scrollController.hasClients) {
                        widget.scrollController.animateTo(
                          widget.scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                    return ListView.builder(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: messages.length + (isThinking ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (isThinking && i == messages.length) {
                          return _TypingIndicator();
                        }
                        final msg = messages[i];
                        final isUser = msg['role'] == 'user';
                        return _MessageBubble(
                          text: msg['content']!,
                          isUser: isUser,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF6FBF6),
              border: Border(top: BorderSide(color: const Color(0xFFD1E7D6))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: 'Andika swali lako...',
                      hintStyle: TextStyle(color: const Color(0xFF6B7280)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
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

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    widget.onSend(text);
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  const _MessageBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF22C55E) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser
                ? const Radius.circular(20)
                : const Radius.circular(4),
            bottomRight: isUser
                ? const Radius.circular(4)
                : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF1F2937),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(delay: const Duration(milliseconds: 0)),
            _Dot(delay: const Duration(milliseconds: 200)),
            _Dot(delay: const Duration(milliseconds: 400)),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Duration delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    Future.delayed(widget.delay, () => _controller.repeat(reverse: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Color(0xFF4B5563).withOpacity(0.3 + 0.7 * _anim.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

// Small local model for recommendation items used by this screen.
class RecommendationItem {
  final String title;
  final String description;
  final String category;
  final bool isUrgent;

  RecommendationItem({
    required this.title,
    required this.description,
    required this.category,
    this.isUrgent = false,
  });
}
