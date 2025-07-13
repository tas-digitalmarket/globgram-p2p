import 'dart:async';
import 'dart:math';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../signaling/firestore_signaling_service.dart';
import '../../models/chat_models.dart';

/// WebRTC P2P Manager for direct peer-to-peer communication
class P2PManager {
  final FirestoreSignalingService _signalingService = FirestoreSignalingService();
  
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  
  String? _roomId;
  bool _isCaller = false;
  
  // Streams for UI updates
  final StreamController<PeerConnectionState> _connectionStateController = 
      StreamController<PeerConnectionState>.broadcast();
  final StreamController<DataChannelState> _dataChannelStateController = 
      StreamController<DataChannelState>.broadcast();
  final StreamController<ChatMessage> _messageController = 
      StreamController<ChatMessage>.broadcast();
  final StreamController<String> _errorController = 
      StreamController<String>.broadcast();

  // Stream subscriptions
  StreamSubscription? _offerSubscription;
  StreamSubscription? _answerSubscription;
  StreamSubscription? _iceCandidatesSubscription;

  // ICE servers configuration
  static const List<Map<String, String>> _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  // Getters for streams
  Stream<PeerConnectionState> get connectionState => _connectionStateController.stream;
  Stream<DataChannelState> get dataChannelState => _dataChannelStateController.stream;
  Stream<ChatMessage> get messages => _messageController.stream;
  Stream<String> get errors => _errorController.stream;

  // Current states
  PeerConnectionState get currentConnectionState => _lastConnectionState;
  DataChannelState get currentDataChannelState => _lastDataChannelState;
  bool get isConnected => _lastDataChannelState == DataChannelState.open;
  String? get roomId => _roomId;
  bool get isCaller => _isCaller;

  PeerConnectionState _lastConnectionState = PeerConnectionState.new_;
  DataChannelState _lastDataChannelState = DataChannelState.closed;

  /// Initialize WebRTC peer connection
  Future<void> _initializePeerConnection() async {
    try {
      // Create peer connection with ICE servers
      _peerConnection = await createPeerConnection({
        'iceServers': _iceServers,
        'sdpSemantics': 'unified-plan',
      });

      // Set up event handlers
      _peerConnection!.onIceCandidate = _onIceCandidate;
      _peerConnection!.onConnectionState = _onConnectionStateChange;
      _peerConnection!.onDataChannel = _onDataChannel;

      print('✅ Peer connection initialized');
    } catch (e) {
      _errorController.add('Failed to initialize peer connection: $e');
      throw Exception('Failed to initialize peer connection: $e');
    }
  }

  /// Create a new room as caller
  Future<String> createRoom() async {
    try {
      _isCaller = true;
      await _initializePeerConnection();
      
      // Create data channel
      _dataChannel = await _peerConnection!.createDataChannel(
        'chat',
        RTCDataChannelInit()..ordered = true,
      );
      _setupDataChannelHandlers();

      // Create offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Create room in Firestore
      _roomId = await _signalingService.createRoom({
        'type': offer.type,
        'sdp': offer.sdp,
      });

      // Start listening for answer and ICE candidates
      _listenForSignaling();

      print('✅ Room created: $_roomId');
      return _roomId!;
    } catch (e) {
      _errorController.add('Failed to create room: $e');
      throw Exception('Failed to create room: $e');
    }
  }

  /// Join an existing room as callee
  Future<void> joinRoom(String roomId) async {
    try {
      _roomId = roomId;
      _isCaller = false;
      await _initializePeerConnection();

      // Start listening for offer and ICE candidates
      _listenForSignaling();

      print('✅ Joined room: $roomId, waiting for offer...');
    } catch (e) {
      _errorController.add('Failed to join room: $e');
      throw Exception('Failed to join room: $e');
    }
  }

  /// Set up signaling listeners
  void _listenForSignaling() {
    if (_roomId == null) return;

    if (_isCaller) {
      // Caller listens for answer
      _answerSubscription = _signalingService.onRemoteAnswer(_roomId!).listen(
        (answer) async {
          if (answer != null) {
            await _handleRemoteAnswer(answer);
          }
        },
        onError: (error) => _errorController.add('Answer stream error: $error'),
      );
    } else {
      // Callee listens for offer
      _offerSubscription = _signalingService.onRemoteOffer(_roomId!).listen(
        (offer) async {
          if (offer != null) {
            await _handleRemoteOffer(offer);
          }
        },
        onError: (error) => _errorController.add('Offer stream error: $error'),
      );
    }

    // Both listen for ICE candidates
    _iceCandidatesSubscription = _signalingService
        .onRemoteIceCandidates(_roomId!, _isCaller)
        .listen(
      (candidate) async {
        await _handleRemoteIceCandidate(candidate);
      },
      onError: (error) => _errorController.add('ICE candidate stream error: $error'),
    );
  }

  /// Handle remote offer (callee side)
  Future<void> _handleRemoteOffer(Map<String, dynamic> offerData) async {
    try {
      final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
      await _peerConnection!.setRemoteDescription(offer);

      // Create and set answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer to room
      await _signalingService.joinRoom(_roomId!, {
        'type': answer.type,
        'sdp': answer.sdp,
      });

      print('✅ Answer sent');
    } catch (e) {
      _errorController.add('Failed to handle remote offer: $e');
    }
  }

  /// Handle remote answer (caller side)
  Future<void> _handleRemoteAnswer(Map<String, dynamic> answerData) async {
    try {
      final answer = RTCSessionDescription(answerData['sdp'], answerData['type']);
      await _peerConnection!.setRemoteDescription(answer);
      print('✅ Remote answer set');
    } catch (e) {
      _errorController.add('Failed to handle remote answer: $e');
    }
  }

  /// Handle remote ICE candidate
  Future<void> _handleRemoteIceCandidate(Map<String, dynamic> candidateData) async {
    try {
      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
      print('🧊 Added remote ICE candidate');
    } catch (e) {
      _errorController.add('Failed to add ICE candidate: $e');
    }
  }

  /// Handle ICE candidate generation
  void _onIceCandidate(RTCIceCandidate candidate) {
    if (_roomId == null) return;

    _signalingService.sendIceCandidate(
      _roomId!,
      {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
      _isCaller,
    ).catchError((error) {
      _errorController.add('Failed to send ICE candidate: $error');
    });

    print('📤 Sent ICE candidate');
  }

  /// Handle connection state changes
  void _onConnectionStateChange(RTCPeerConnectionState state) {
    final newState = state.toString().split('.').last.toPeerConnectionState();
    _lastConnectionState = newState;
    _connectionStateController.add(newState);
    print('🔄 Connection state: $newState');
  }

  /// Handle incoming data channel (callee side)
  void _onDataChannel(RTCDataChannel dataChannel) {
    _dataChannel = dataChannel;
    _setupDataChannelHandlers();
    print('📨 Data channel received');
  }

  /// Set up data channel event handlers
  void _setupDataChannelHandlers() {
    if (_dataChannel == null) return;

    _dataChannel!.onDataChannelState = (state) {
      final newState = state.toString().split('.').last.toDataChannelState();
      _lastDataChannelState = newState;
      _dataChannelStateController.add(newState);
      print('📡 Data channel state: $newState');
    };

    _dataChannel!.onMessage = (RTCDataChannelMessage message) {
      try {
        final messageData = message.text;
        final chatMessage = ChatMessage.fromJsonString(messageData);
        _messageController.add(chatMessage);
        print('📥 Received message: ${chatMessage.text}');
      } catch (e) {
        _errorController.add('Failed to parse incoming message: $e');
      }
    };
  }

  /// Send a chat message
  Future<void> sendMessage(String text) async {
    if (_dataChannel == null || _lastDataChannelState != DataChannelState.open) {
      throw Exception('Data channel not ready');
    }

    if (text.trim().isEmpty) {
      throw Exception('Message cannot be empty');
    }

    try {
      final message = ChatMessage(
        id: _generateMessageId(),
        text: text.trim(),
        timestamp: DateTime.now(),
        isFromMe: true,
      );

      // Send to peer
      await _dataChannel!.send(RTCDataChannelMessage(message.toJsonString()));
      
      // Add to local stream
      _messageController.add(message);
      
      print('📤 Sent message: ${message.text}');
    } catch (e) {
      _errorController.add('Failed to send message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  /// Generate unique message ID
  String _generateMessageId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
  }

  /// Close the connection and clean up resources
  Future<void> close() async {
    try {
      // Cancel subscriptions
      await _offerSubscription?.cancel();
      await _answerSubscription?.cancel();
      await _iceCandidatesSubscription?.cancel();

      // Close data channel
      _dataChannel?.close();
      _dataChannel = null;

      // Close peer connection
      await _peerConnection?.close();
      _peerConnection = null;

      // Close streams
      await _connectionStateController.close();
      await _dataChannelStateController.close();
      await _messageController.close();
      await _errorController.close();

      // Clean up room if caller
      if (_roomId != null && _isCaller) {
        await _signalingService.deleteRoom(_roomId!);
      }

      _roomId = null;
      _isCaller = false;
      _lastConnectionState = PeerConnectionState.new_;
      _lastDataChannelState = DataChannelState.closed;

      print('✅ P2P connection closed');
    } catch (e) {
      print('❌ Error closing P2P connection: $e');
    }
  }

  /// Dispose all resources
  void dispose() {
    close();
  }
}
