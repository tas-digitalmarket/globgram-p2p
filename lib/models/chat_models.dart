import 'dart:convert';

/// Model class for chat messages
class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isFromMe;
  final String? senderName;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isFromMe,
    this.senderName,
  });

  /// Convert message to JSON for transmission
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'senderName': senderName,
      'type': 'message',
    };
  }

  /// Create message from JSON received from peer
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      isFromMe: false, // Always false for received messages
      senderName: json['senderName'] as String?,
    );
  }

  /// Convert message to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create message from JSON string
  static ChatMessage fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return ChatMessage.fromJson(json);
  }

  @override
  String toString() {
    return 'ChatMessage{id: $id, text: $text, timestamp: $timestamp, isFromMe: $isFromMe}';
  }
}

/// Enum for peer connection states
enum PeerConnectionState {
  new_,
  connecting,
  connected,
  disconnected,
  failed,
  closed,
}

/// Extension to convert WebRTC states to our enum
extension RTCPeerConnectionStateExtension on String {
  PeerConnectionState toPeerConnectionState() {
    switch (toLowerCase()) {
      case 'new':
        return PeerConnectionState.new_;
      case 'connecting':
        return PeerConnectionState.connecting;
      case 'connected':
        return PeerConnectionState.connected;
      case 'disconnected':
        return PeerConnectionState.disconnected;
      case 'failed':
        return PeerConnectionState.failed;
      case 'closed':
        return PeerConnectionState.closed;
      default:
        return PeerConnectionState.new_;
    }
  }
}

/// Data channel states
enum DataChannelState {
  connecting,
  open,
  closing,
  closed,
}

/// Extension for data channel states
extension RTCDataChannelStateExtension on String {
  DataChannelState toDataChannelState() {
    switch (toLowerCase()) {
      case 'connecting':
        return DataChannelState.connecting;
      case 'open':
        return DataChannelState.open;
      case 'closing':
        return DataChannelState.closing;
      case 'closed':
        return DataChannelState.closed;
      default:
        return DataChannelState.closed;
    }
  }
}
