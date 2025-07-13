import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/webrtc/p2p_manager.dart';
import '../models/chat_models.dart';

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
  final List<ChatMessage> _messages = [];
  
  late StreamSubscription _connectionStateSubscription;
  late StreamSubscription _dataChannelStateSubscription;
  late StreamSubscription _messageSubscription;
  late StreamSubscription _errorSubscription;

  PeerConnectionState _connectionState = PeerConnectionState.new_;
  DataChannelState _dataChannelState = DataChannelState.closed;
  String? _currentRoomId;
  bool _isInitializing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupStreams();
    _initializeConnection();
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _dataChannelStateSubscription.cancel();
    _messageSubscription.cancel();
    _errorSubscription.cancel();
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

    _dataChannelStateSubscription = _p2pManager.dataChannelState.listen((state) {
      setState(() {
        _dataChannelState = state;
      });
    });

    _messageSubscription = _p2pManager.messages.listen((message) {
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    });

    _errorSubscription = _p2pManager.errors.listen((error) {
      setState(() {
        _errorMessage = error;
      });
      _showErrorSnackBar(error);
    });
  }

  Future<void> _initializeConnection() async {
    try {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });

      if (widget.isCaller) {
        // Create new room
        final roomId = await _p2pManager.createRoom();
        setState(() {
          _currentRoomId = roomId;
        });
      } else {
        // Join existing room
        if (widget.roomId == null) {
          throw Exception('Room ID is required for joining');
        }
        await _p2pManager.joinRoom(widget.roomId!);
        setState(() {
          _currentRoomId = widget.roomId;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize connection: $e';
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  void _showErrorSnackBar(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      await _p2pManager.sendMessage(text);
      _messageController.clear();
    } catch (e) {
      _showErrorSnackBar('Failed to send message: $e');
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

  void _copyRoomId() {
    if (_currentRoomId != null) {
      Clipboard.setData(ClipboardData(text: _currentRoomId!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room ID copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildConnectionStatus() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (_isInitializing) {
      statusText = 'Initializing...';
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
    } else if (_dataChannelState == DataChannelState.open) {
      statusText = 'Connected ✅';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (_connectionState == PeerConnectionState.connecting || 
               _dataChannelState == DataChannelState.connecting) {
      statusText = 'Connecting...';
      statusColor = Colors.blue;
      statusIcon = Icons.sync;
    } else if (_connectionState == PeerConnectionState.failed || 
               _errorMessage != null) {
      statusText = 'Connection Failed ❌';
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else {
      statusText = 'Waiting for peer...';
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: statusColor.withOpacity(0.1),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (_currentRoomId != null) ...[
            const Spacer(),
            GestureDetector(
              onTap: _copyRoomId,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ID: ${_currentRoomId!.substring(0, 8)}...',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.copy, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
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
                    ? Colors.white.withOpacity(0.7)
                    : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final isEnabled = _dataChannelState == DataChannelState.open;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: isEnabled,
              decoration: InputDecoration(
                hintText: isEnabled 
                    ? 'Type a message...' 
                    : 'Waiting for connection...',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: isEnabled ? (_) => _sendMessage() : null,
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isEnabled ? _sendMessage : null,
            icon: Icon(
              Icons.send,
              color: isEnabled 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey,
            ),
            tooltip: 'Send message',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCaller ? 'P2P Chat (Host)' : 'P2P Chat (Guest)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_currentRoomId != null)
            IconButton(
              onPressed: _copyRoomId,
              icon: const Icon(Icons.share),
              tooltip: 'Share Room ID',
            ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          _buildConnectionStatus(),

          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _dataChannelState == DataChannelState.open
                              ? 'Start the conversation!'
                              : 'Waiting for connection...',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }
}
