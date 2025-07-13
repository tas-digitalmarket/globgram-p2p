import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/webrtc/p2p_manager.dart';

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
  
  late StreamSubscription _connectionStateSubscription;
  late StreamSubscription _messageSubscription;

  PeerConnectionState _connectionState = PeerConnectionState.new_;
  String? _currentRoomId;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _setupStreams();
    _initializeConnection();
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _messageSubscription.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _p2pManager.dispose();
    super.dispose();
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
              : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isFromMe ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: message.isFromMe 
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
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
                    enabled: _p2pManager.isConnected,
                    decoration: InputDecoration(
                      hintText: _p2pManager.isConnected 
                          ? 'Type a message...' 
                          : 'Waiting for connection...',
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: _p2pManager.isConnected ? (_) => _sendMessage() : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _p2pManager.isConnected ? _sendMessage : null,
                  icon: Icon(
                    Icons.send,
                    color: _p2pManager.isConnected 
                        ? Theme.of(context).primaryColor 
                        : Colors.grey,
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
