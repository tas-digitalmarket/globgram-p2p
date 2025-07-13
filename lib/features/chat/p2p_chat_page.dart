import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/webrtc/p2p_manager.dart';
import '../../core/audio/voice_recorder.dart';
import '../../core/audio/voice_player.dart';

class P2PChatPage extends StatefulWidget {
  final String? roomId;
  final bool isCaller;

  const P2PChatPage({
    super.key,
    this.roomId,
    this.isCaller = false,
  });

  @override
  State<P2PChatPage> createState() => _P2PChatPageState();
}

class _P2PChatPageState extends State<P2PChatPage> {
  final P2PManager _p2pManager = P2PManager();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  
  // Audio services
  final VoiceRecorder _voiceRecorder = VoiceRecorder();
  final VoicePlayer _voicePlayer = VoicePlayer();
  
  late StreamSubscription _connectionStateSubscription;
  late StreamSubscription _messageSubscription;

  PeerConnectionState _connectionState = PeerConnectionState.new_;
  String? _currentRoomId;
  bool _isInitializing = true;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _setupStreams();
    _initializeConnection();
    _initializeAudioServices();
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _messageSubscription.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _p2pManager.dispose();
    _voiceRecorder.dispose();
    _voicePlayer.dispose();
    super.dispose();
  }

  Future<void> _initializeAudioServices() async {
    await _voiceRecorder.initialize();
    await _voicePlayer.initialize();
  }

  void _setupStreams() {
    _connectionStateSubscription = _p2pManager.connectionState.listen((state) {
      setState(() {
        _connectionState = state;
      });
    });

    _messageSubscription = _p2pManager.messages.listen((message) {
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    });
  }

  Future<void> _initializeConnection() async {
    try {
      setState(() {
        _isInitializing = true;
      });

      if (widget.isCaller) {
        final roomId = await _p2pManager.createRoom();
        setState(() {
          _currentRoomId = roomId;
        });
      } else {
        if (widget.roomId != null) {
          await _p2pManager.joinRoom(widget.roomId!);
          setState(() {
            _currentRoomId = widget.roomId;
          });
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      await _p2pManager.sendMessage(text);
      _messageController.clear();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecording) return;

    final success = await _voiceRecorder.startRecording();
    if (success) {
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _stopVoiceRecording() async {
    if (!_isRecording) return;

    final audioData = await _voiceRecorder.stopRecording();
    setState(() {
      _isRecording = false;
    });

    if (audioData != null && audioData.isNotEmpty) {
      try {
        await _p2pManager.sendVoiceMessage(audioData);
      } catch (e) {
        // Handle error
      }
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_isRecording) return;

    await _voiceRecorder.cancelRecording();
    setState(() {
      _isRecording = false;
    });
  }

  Future<void> _playVoiceMessage(Uint8List voiceData) async {
    try {
      await _voicePlayer.playAudio(voiceData);
    } catch (e) {
      // Handle error
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildConnectionStatus() {
    String statusText;
    Color statusColor;

    if (_isInitializing) {
      statusText = 'Initializing...';
      statusColor = Colors.orange;
    } else if (_p2pManager.isConnected) {
      statusText = 'Connected ✅';
      statusColor = Colors.green;
    } else if (_connectionState == PeerConnectionState.connecting) {
      statusText = 'Connecting...';
      statusColor = Colors.blue;
    } else if (_connectionState == PeerConnectionState.failed) {
      statusText = 'Connection Failed ❌';
      statusColor = Colors.red;
    } else {
      statusText = 'Waiting for peer...';
      statusColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: statusColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.circle, color: statusColor, size: 12),
          const SizedBox(width: 8),
          Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
          if (_currentRoomId != null) ...[
            const Spacer(),
            Text('Room: ${_currentRoomId!.substring(0, 8)}...', 
                 style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    return Align(
      alignment: message.isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isFromMe
              ? Theme.of(context).primaryColor
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.type == MessageType.voice)
              _buildVoiceMessageContent(message)
            else
              Text(
                message.text,
                style: TextStyle(
                  color: message.isFromMe 
                      ? Colors.white 
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: message.isFromMe 
                    ? Colors.white.withValues(alpha: 0.7)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceMessageContent(Message message) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: message.isFromMe 
                ? Colors.white.withValues(alpha: 0.2)
                : Theme.of(context).primaryColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: message.voiceData != null 
                ? () => _playVoiceMessage(message.voiceData!)
                : null,
            icon: Icon(
              Icons.play_arrow,
              color: message.isFromMe 
                  ? Colors.white 
                  : Theme.of(context).primaryColor,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: message.isFromMe 
                  ? Colors.white.withValues(alpha: 0.3)
                  : Theme.of(context).primaryColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: LinearProgressIndicator(
              value: 0.0, // Could be updated to show playback progress
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                message.isFromMe 
                    ? Colors.white 
                    : Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.graphic_eq,
          color: message.isFromMe 
              ? Colors.white.withValues(alpha: 0.7)
              : Theme.of(context).primaryColor.withValues(alpha: 0.7),
          size: 16,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCaller ? 'P2P Chat (Host)' : 'P2P Chat (Guest)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          _buildConnectionStatus(),
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('No messages yet'))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: _p2pManager.isConnected && !_isRecording,
                    decoration: InputDecoration(
                      hintText: _isRecording 
                          ? 'Recording voice message...'
                          : _p2pManager.isConnected 
                              ? 'Type a message...' 
                              : 'Waiting for connection...',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    onSubmitted: _p2pManager.isConnected && !_isRecording 
                        ? (_) => _sendMessage() 
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                // Voice recording button
                GestureDetector(
                  onTapDown: _p2pManager.isConnected ? (_) => _startVoiceRecording() : null,
                  onTapUp: (_) => _stopVoiceRecording(),
                  onTapCancel: () => _cancelVoiceRecording(),
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: _isRecording 
                          ? Colors.red 
                          : (_p2pManager.isConnected 
                              ? Theme.of(context).primaryColor 
                              : Colors.grey),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send text button
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: _p2pManager.isConnected && !_isRecording
                        ? Theme.of(context).primaryColor 
                        : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _p2pManager.isConnected && !_isRecording 
                        ? _sendMessage 
                        : null,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
