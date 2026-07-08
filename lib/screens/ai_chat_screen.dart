import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/ai_chat_provider.dart';
import '../providers/readings_provider.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _showConfig = false;
  final _urlController = TextEditingController(text: 'http://localhost:11434');
  final _modelController = TextEditingController(text: 'qwen2.5:7b');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiChatProvider>().testConnection();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _urlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final snapshot = context.read<ReadingsProvider>().buildDataSnapshot();
    context.read<AiChatProvider>().sendMessage(text, dataSnapshot: snapshot);

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiChatProvider>(
      builder: (context, chat, _) {
        return Column(
          children: [
            _Header(
              connected: chat.connected,
              model: chat.service.currentModel,
              onConfig: () => setState(() => _showConfig = !_showConfig),
              onClear: chat.clearHistory,
            ),
            if (_showConfig) _ConfigPanel(
              urlController: _urlController,
              modelController: _modelController,
              onApply: () {
                chat.configure(
                  baseUrl: _urlController.text.trim(),
                  model: _modelController.text.trim(),
                );
                setState(() => _showConfig = false);
              },
            ),
            Expanded(
              child: chat.messages.isEmpty
                  ? _WelcomeView()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: chat.messages.length,
                      itemBuilder: (context, index) {
                        final msg = chat.messages[index];
                        return _MessageBubble(message: msg);
                      },
                    ),
            ),
            if (chat.loading)
              const LinearProgressIndicator(
                  color: EaColors.primary, minHeight: 2),
            _InputBar(
              controller: _controller,
              enabled: !chat.loading,
              onSend: _send,
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final bool connected;
  final String model;
  final VoidCallback onConfig;
  final VoidCallback onClear;

  const _Header({
    required this.connected,
    required this.model,
    required this.onConfig,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: EaColors.surface,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: connected ? EaColors.success : EaColors.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Jarvis - EA Innovation Agent',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  connected ? 'Modelo: $model' : 'Desconectado',
                  style: TextStyle(
                    fontSize: 11,
                    color: connected ? EaColors.textSecondary : EaColors.danger,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onConfig,
            icon: const Icon(Icons.settings_rounded, size: 20),
            tooltip: 'Configurar IA',
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            tooltip: 'Limpiar chat',
          ),
        ],
      ),
    );
  }
}

class _ConfigPanel extends StatelessWidget {
  final TextEditingController urlController;
  final TextEditingController modelController;
  final VoidCallback onApply;

  const _ConfigPanel({
    required this.urlController,
    required this.modelController,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: EaColors.card,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL del servidor Ollama',
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: modelController,
                  decoration: const InputDecoration(
                    labelText: 'Modelo',
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onApply,
                child: const Text('Aplicar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ejecuta "ollama serve" en tu computadora y asegurate de tener el modelo instalado con "ollama pull qwen2.5:7b"',
            style: TextStyle(fontSize: 11, color: EaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: EaColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  size: 48, color: EaColors.primary),
            ),
            const SizedBox(height: 24),
            const Text('EA Innovation Agent',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Analisis termodinamico, diagnosticos y visualizacion inteligente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: EaColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip('Estado del sistema'),
                _SuggestionChip('Diagnostico avanzado'),
                _SuggestionChip('Calcula Z para 25C y 200 PSI'),
                _SuggestionChip('Hay alertas de consumo?'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  const _SuggestionChip(this.text);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: EaColors.card,
      side: BorderSide(color: EaColors.primary.withOpacity(0.3)),
      onPressed: () {
        final snapshot = context.read<ReadingsProvider>().buildDataSnapshot();
        context.read<AiChatProvider>().sendMessage(text, dataSnapshot: snapshot);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser ? EaColors.primary : EaColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: SelectableText(
          message.content.isEmpty ? '...' : message.content,
          style: TextStyle(
            fontSize: 14,
            color: isUser ? Colors.white : EaColors.textPrimary,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: EaColors.surface,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Que analisis requiere, Ingeniero?',
                hintStyle: TextStyle(color: EaColors.textSecondary, fontSize: 14),
                border: InputBorder.none,
                filled: false,
              ),
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
              minLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: EaColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
