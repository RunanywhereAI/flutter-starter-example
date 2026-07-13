import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:runanywhere/runanywhere.dart';

import '../services/model_service.dart';
import '../theme/app_theme.dart';
import '../widgets/model_loader_widget.dart';

// =============================================================================
// Data Models
// =============================================================================

class ToolCallInfo {
  final String toolName;
  final String arguments;
  final String? result;
  final String? error;
  final bool success;

  const ToolCallInfo({
    required this.toolName,
    required this.arguments,
    this.result,
    this.error,
    this.success = true,
  });
}

class ToolChatMessage {
  final String text;
  final bool isUser;
  final List<ToolCallInfo> toolCalls;
  final DateTime timestamp;

  const ToolChatMessage({
    required this.text,
    required this.isUser,
    this.toolCalls = const [],
    required this.timestamp,
  });
}

// =============================================================================
// Tool Calling View
// =============================================================================

class ToolCallingView extends StatefulWidget {
  const ToolCallingView({super.key});

  @override
  State<ToolCallingView> createState() => _ToolCallingViewState();
}

class _ToolCallingViewState extends State<ToolCallingView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ToolChatMessage> _messages = [];
  bool _isGenerating = false;
  bool _toolsRegistered = false;

  @override
  void initState() {
    super.initState();
    _registerDemoTools();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _registerDemoTools() {
    RunAnywhere.tools.clearTools();

    // 1. Weather Tool
    RunAnywhere.tools.registerTool(
      ToolDefinition(
        name: 'get_weather',
        description:
            'Gets the current weather for a given location using Open-Meteo API',
        parameters: [
          ToolParameter(
            name: 'location',
            type: ToolParameterType.TOOL_PARAMETER_TYPE_STRING,
            description:
                "City name (e.g., 'San Francisco', 'London', 'Tokyo')",
          ),
        ],
        category: 'Utility',
      ),
      _fetchWeather,
    );

    // 2. Time Tool
    RunAnywhere.tools.registerTool(
      ToolDefinition(
        name: 'get_current_time',
        description: 'Gets the current date, time, and timezone information',
        parameters: [],
        category: 'Utility',
      ),
      _getCurrentTime,
    );

    // 3. Calculator Tool
    RunAnywhere.tools.registerTool(
      ToolDefinition(
        name: 'calculate',
        description:
            'Performs math calculations. Supports +, -, *, /, and parentheses',
        parameters: [
          ToolParameter(
            name: 'expression',
            type: ToolParameterType.TOOL_PARAMETER_TYPE_STRING,
            description:
                "Math expression (e.g., '2 + 2 * 3', '(10 + 5) / 3')",
          ),
        ],
        category: 'Utility',
      ),
      _calculate,
    );

    setState(() => _toolsRegistered = true);
  }

  // ===========================================================================
  // Tool Executors
  // ===========================================================================

  Future<Map<String, dynamic>> _fetchWeather(Map<String, dynamic> args) async {
    final rawLocation = args['location'] as String?;
    if (rawLocation == null || rawLocation.isEmpty) {
      return {'error': 'Missing required argument: location'};
    }

    final location = _cleanLocationString(rawLocation);

    try {
      // Geocode the location
      final geocodeUrl = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search'
        '?name=${Uri.encodeComponent(location)}&count=5&language=en&format=json',
      );
      final geocodeResponse = await http.get(geocodeUrl);
      if (geocodeResponse.statusCode != 200) {
        throw Exception('Geocoding failed');
      }

      final geocodeData =
          jsonDecode(geocodeResponse.body) as Map<String, dynamic>;
      final results = geocodeData['results'] as List?;
      if (results == null || results.isEmpty) {
        return {
          'error': 'Could not find location: $location',
          'location': location,
        };
      }

      final first = results[0] as Map<String, dynamic>;
      final lat = first['latitude'] as num;
      final lon = first['longitude'] as num;
      final cityName = first['name'] as String? ?? location;

      // Fetch weather
      final weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
        '&temperature_unit=fahrenheit&wind_speed_unit=mph',
      );
      final weatherResponse = await http.get(weatherUrl);
      if (weatherResponse.statusCode != 200) {
        throw Exception('Weather fetch failed');
      }

      final weatherData =
          jsonDecode(weatherResponse.body) as Map<String, dynamic>;
      final current = weatherData['current'] as Map<String, dynamic>;
      final temp = current['temperature_2m'] as num? ?? 0;
      final humidity = current['relative_humidity_2m'] as num? ?? 0;
      final windSpeed = current['wind_speed_10m'] as num? ?? 0;
      final weatherCode = current['weather_code'] as int? ?? 0;

      return {
        'location': cityName,
        'temperature_fahrenheit': temp.toDouble(),
        'humidity_percent': humidity.toDouble(),
        'wind_speed_mph': windSpeed.toDouble(),
        'condition': _weatherCodeToCondition(weatherCode),
      };
    } catch (e) {
      return {'error': 'Weather fetch failed: $e', 'location': location};
    }
  }

  String _cleanLocationString(String location) {
    var cleaned = location.trim();
    final patterns = [
      RegExp(r',\s*(US|USA|United States)$', caseSensitive: false),
      RegExp(r',\s*[A-Z]{2}$'),
      RegExp(r',\s*[A-Z]{2},\s*(US|USA)$', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    const abbreviations = {
      'SF': 'San Francisco',
      'NYC': 'New York City',
      'LA': 'Los Angeles',
      'DC': 'Washington DC',
    };
    final upper = cleaned.toUpperCase();
    if (abbreviations.containsKey(upper)) return abbreviations[upper]!;
    return cleaned;
  }

  String _weatherCodeToCondition(int code) => switch (code) {
        0 => 'Clear sky',
        1 || 2 || 3 => 'Partly cloudy',
        45 || 48 => 'Foggy',
        51 || 53 || 55 => 'Drizzle',
        61 || 63 || 65 => 'Rain',
        71 || 73 || 75 => 'Snow',
        80 || 81 || 82 => 'Rain showers',
        95 || 96 || 99 => 'Thunderstorm',
        _ => 'Unknown',
      };

  Future<Map<String, dynamic>> _getCurrentTime(
    Map<String, dynamic> args,
  ) async {
    final now = DateTime.now();
    return {
      'date':
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'time':
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      'timezone': now.timeZoneName,
    };
  }

  Future<Map<String, dynamic>> _calculate(Map<String, dynamic> args) async {
    final expression = args['expression'] as String?;
    if (expression == null || expression.isEmpty) {
      return {'error': 'Missing required argument: expression'};
    }

    try {
      final result = _evaluateExpression(expression);
      return {'expression': expression, 'result': result};
    } catch (e) {
      return {'error': 'Calculation failed: $e', 'expression': expression};
    }
  }

  double _evaluateExpression(String expr) {
    final tokens = _tokenize(expr);
    final parser = _TokenParser(tokens);
    return _parseExpression(parser);
  }

  List<String> _tokenize(String expr) {
    final tokens = <String>[];
    final current = StringBuffer();
    for (final char in expr.runes.map(String.fromCharCode)) {
      if (RegExp(r'[\d.]').hasMatch(char)) {
        current.write(char);
      } else if ('+-*/()'.contains(char)) {
        if (current.isNotEmpty) {
          tokens.add(current.toString());
          current.clear();
        }
        tokens.add(char);
      } else if (char.trim().isEmpty) {
        if (current.isNotEmpty) {
          tokens.add(current.toString());
          current.clear();
        }
      }
    }
    if (current.isNotEmpty) tokens.add(current.toString());
    return tokens;
  }

  double _parseExpression(_TokenParser parser) {
    var left = _parseTerm(parser);
    while (parser.hasNext) {
      final op = parser.peek;
      if (op != '+' && op != '-') break;
      parser.next();
      final right = _parseTerm(parser);
      left = op == '+' ? left + right : left - right;
    }
    return left;
  }

  double _parseTerm(_TokenParser parser) {
    var left = _parseFactor(parser);
    while (parser.hasNext) {
      final op = parser.peek;
      if (op != '*' && op != '/') break;
      parser.next();
      final right = _parseFactor(parser);
      left = op == '*' ? left * right : left / right;
    }
    return left;
  }

  double _parseFactor(_TokenParser parser) {
    if (!parser.hasNext) return 0;
    final token = parser.next();
    if (token == '(') {
      final result = _parseExpression(parser);
      if (parser.hasNext) parser.next(); // consume ')'
      return result;
    }
    if (token == '-') return -_parseFactor(parser);
    return double.tryParse(token) ?? 0;
  }

  // ===========================================================================
  // Chat Logic
  // ===========================================================================

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isGenerating) return;

    setState(() {
      _messages.add(ToolChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _controller.clear();
      _isGenerating = true;
    });
    _scrollToBottom();

    try {
      final result = await RunAnywhere.tools.generateWithTools(
        text,
        options: ToolCallingOptions(
          maxToolCalls: 3,
          autoExecute: true,
          temperature: 0.7,
          maxTokens: 512,
          format: ToolCallFormatName.TOOL_CALL_FORMAT_NAME_JSON,
        ),
      );

      // Convert tool calls to UI-friendly format. `argumentsJson`/`resultJson`
      // are already JSON strings, so they can be displayed directly.
      final toolCallInfos = <ToolCallInfo>[];
      for (var i = 0; i < result.toolCalls.length; i++) {
        final call = result.toolCalls[i];
        final toolResult =
            i < result.toolResults.length ? result.toolResults[i] : null;

        toolCallInfos.add(ToolCallInfo(
          toolName: call.name,
          arguments: call.argumentsJson,
          result: (toolResult != null && toolResult.resultJson.isNotEmpty)
              ? toolResult.resultJson
              : null,
          error: (toolResult != null && toolResult.error.isNotEmpty)
              ? toolResult.error
              : null,
          success: toolResult?.success ?? false,
        ));
      }

      if (mounted) {
        setState(() {
          _messages.add(ToolChatMessage(
            text: result.text,
            isUser: false,
            toolCalls: toolCallInfos,
            timestamp: DateTime.now(),
          ));
          _isGenerating = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ToolChatMessage(
            text: 'Error: $e',
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isGenerating = false;
        });
      }
    }
  }

  void _clearChat() => setState(() => _messages.clear());

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ===========================================================================
  // Build
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tool Calling'),
            Text(
              'LLM + Function Execution',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.accentOrange,
                  ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _clearChat,
              tooltip: 'Clear chat',
            ),
        ],
      ),
      body: Consumer<ModelService>(
        builder: (context, modelService, child) {
          if (!modelService.isLLMLoaded) {
            return ModelLoaderWidget(
              title: 'LLM Model Required',
              subtitle:
                  'Download and load the language model to test tool calling',
              icon: Icons.build_rounded,
              accentColor: AppColors.accentOrange,
              isDownloading: modelService.isLLMDownloading,
              isLoading: modelService.isLLMLoading,
              progress: modelService.llmDownloadProgress,
              onLoad: () => modelService.downloadAndLoadLLM(),
            );
          }

          return Column(
            children: [
              // Tools info card
              if (_toolsRegistered) _buildToolsInfoCard(),

              // Chat messages
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessagesList(),
              ),

              // Input area
              _buildInputArea(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildToolsInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentOrange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.build_rounded, color: AppColors.accentOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3 Tools Available',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  'Weather \u2022 Time \u2022 Calculator',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.build_rounded,
                size: 48,
                color: AppColors.accentOrange,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 2000.ms,
                ),
            const SizedBox(height: 24),
            Text(
              'Tool Calling Demo',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Ask questions that require tools:',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip("What's the weather in San Francisco?"),
                _buildSuggestionChip('What time is it right now?'),
                _buildSuggestionChip('Calculate 15 * 7 + 23'),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      backgroundColor: AppColors.surfaceCard,
      side: BorderSide(color: AppColors.accentOrange.withOpacity(0.3)),
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.accentCyan,
          ),
      onPressed: () {
        _controller.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isGenerating ? 1 : 0),
      itemBuilder: (context, index) {
        // Generating indicator
        if (index == _messages.length && _isGenerating) {
          return _ToolChatBubble(
            message: ToolChatMessage(
              text: 'Thinking...',
              isUser: false,
              timestamp: DateTime.now(),
            ),
            isStreaming: true,
            onToolCallTap: (_) {},
          ).animate().fadeIn(duration: 300.ms);
        }

        return _ToolChatBubble(
          message: _messages[index],
          onToolCallTap: (info) => _showToolCallDetail(info),
        ).animate().fadeIn(duration: 300.ms).slideX(
              begin: _messages[index].isUser ? 0.1 : -0.1,
            );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.8),
        border: Border(
          top: BorderSide(color: AppColors.textMuted.withOpacity(0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: "Try: What's the weather in Tokyo?",
                  filled: true,
                  fillColor: AppColors.primaryMid,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                enabled: !_isGenerating,
                maxLines: 4,
                minLines: 1,
              ),
            ),
            const SizedBox(width: 12),
            _isGenerating
                ? Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accentViolet.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accentOrange, Color(0xFFEA580C)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentOrange.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded),
                      color: Colors.white,
                      onPressed: _sendMessage,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showToolCallDetail(ToolCallInfo info) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ToolCallDetailSheet(info: info),
    );
  }
}

// =============================================================================
// Token Parser (for math expressions)
// =============================================================================

class _TokenParser {
  final List<String> _tokens;
  int _index = 0;

  _TokenParser(this._tokens);

  bool get hasNext => _index < _tokens.length;
  String? get peek => hasNext ? _tokens[_index] : null;
  String next() => _tokens[_index++];
}

// =============================================================================
// Chat Bubble Widget
// =============================================================================

class _ToolChatBubble extends StatelessWidget {
  final ToolChatMessage message;
  final bool isStreaming;
  final ValueChanged<ToolCallInfo> onToolCallTap;

  const _ToolChatBubble({
    required this.message,
    this.isStreaming = false,
    required this.onToolCallTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tool call indicator chips
          if (message.toolCalls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: message.toolCalls
                    .map((tc) => _ToolCallChip(
                          info: tc,
                          onTap: () => onToolCallTap(tc),
                        ))
                    .toList(),
              ),
            ),

          // Message bubble
          Row(
            mainAxisAlignment: message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.isUser) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accentOrange, Color(0xFFEA580C)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: message.isUser
                        ? const LinearGradient(
                            colors: [AppColors.accentCyan, Color(0xFF0EA5E9)],
                          )
                        : null,
                    color: message.isUser ? null : AppColors.surfaceCard,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                      bottomRight: Radius.circular(message.isUser ? 4 : 18),
                    ),
                    border: message.isUser
                        ? null
                        : Border.all(
                            color: AppColors.textMuted.withOpacity(0.1)),
                    boxShadow: message.isUser
                        ? [
                            BoxShadow(
                              color: AppColors.accentCyan.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: SelectableText(
                          message.text,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: message.isUser
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    height: 1.4,
                                  ),
                        ),
                      ),
                      if (isStreaming)
                        Container(
                          width: 8,
                          height: 16,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                            .animate(onPlay: (c) => c.repeat())
                            .fadeIn(duration: 500.ms)
                            .then()
                            .fadeOut(duration: 500.ms),
                    ],
                  ),
                ),
              ),
              if (message.isUser) ...[
                const SizedBox(width: 10),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Tool Call Chip (inline indicator)
// =============================================================================

class _ToolCallChip extends StatelessWidget {
  final ToolCallInfo info;
  final VoidCallback onTap;

  const _ToolCallChip({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bgColor = info.success
        ? AppColors.accentGreen.withOpacity(0.1)
        : AppColors.error.withOpacity(0.1);
    final borderColor = info.success
        ? AppColors.accentGreen.withOpacity(0.3)
        : AppColors.error.withOpacity(0.3);
    final iconColor = info.success ? AppColors.accentGreen : AppColors.error;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              info.success
                  ? Icons.check_circle_rounded
                  : Icons.warning_rounded,
              size: 12,
              color: iconColor,
            ),
            const SizedBox(width: 6),
            Text(
              info.toolName,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Tool Call Detail Bottom Sheet
// =============================================================================

class _ToolCallDetailSheet extends StatelessWidget {
  final ToolCallInfo info;

  const _ToolCallDetailSheet({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Tool Call Details',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),

            // Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: info.success
                    ? AppColors.accentGreen.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    info.success
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 24,
                    color:
                        info.success ? AppColors.accentGreen : AppColors.error,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    info.success ? 'Success' : 'Failed',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tool name
            _buildDetailRow(context, 'Tool', info.toolName),
            const SizedBox(height: 16),

            // Arguments
            _buildCodeBlock(context, 'Arguments', info.arguments),

            // Result
            if (info.result != null) ...[
              const SizedBox(height: 16),
              _buildCodeBlock(context, 'Result', info.result!),
            ],

            // Error
            if (info.error != null) ...[
              const SizedBox(height: 16),
              _buildDetailRow(context, 'Error', info.error!, isError: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String title,
    String content, {
    bool isError = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isError ? AppColors.error : AppColors.textPrimary,
              ),
        ),
      ],
    );
  }

  Widget _buildCodeBlock(BuildContext context, String title, String code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryMid,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            code,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'Menlo',
                  color: AppColors.accentCyan,
                  height: 1.4,
                ),
          ),
        ),
      ],
    );
  }
}
