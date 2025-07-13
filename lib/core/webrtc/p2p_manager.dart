import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../signaling/firestore_signaling_service.dart';

enum MessageType { text, voice }

class Message {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isFromMe;
  final MessageType type;
  final Uint8List? voiceData;

  Message({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isFromMe,
    this.type = MessageType.text,
    this.voiceData,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'type': type.toString(),
    'voiceData': voiceData != null ? base64Encode(voiceData!) : null,
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'],
    text: json['text'],
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    isFromMe: false,
    type: MessageType.values.firstWhere(
      (e) => e.toString() == json['type'],
      orElse: () => MessageType.text,
    ),
    voiceData: json['voiceData'] != null 
        ? base64Decode(json['voiceData']) 
        : null,
  );
}

enum PeerConnectionState { new_, connecting, connected, disconnected, failed, closed }

class P2PManager {
  final FirestoreSignalingService _signalingService = FirestoreSignalingService();
  
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  String? _roomId;
  bool _isCaller = false;
  
  final StreamController<PeerConnectionState> _connectionStateController = 
      StreamController<PeerConnectionState>.broadcast();
  final StreamController<Message> _messageController = 
      StreamController<Message>.broadcast();

  StreamSubscription? _offerSubscription;
  StreamSubscription? _answerSubscription;
  StreamSubscription? _iceCandidatesSubscription;

  static const List<Map<String, String>> _iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  Stream<PeerConnectionState> get connectionState => _connectionStateController.stream;
  Stream<Message> get messages => _messageController.stream;
  bool get isConnected => _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;

  Future<void> _initializePeerConnection() async {
    _peerConnection = await createPeerConnection({
      'iceServers': _iceServers,
    });

    _peerConnection!.onIceCandidate = _onIceCandidate;
    _peerConnection!.onConnectionState = _onConnectionStateChange;
    _peerConnection!.onDataChannel = _onDataChannel;
  }

  Future<String> createRoom() async {
    _isCaller = true;
    await _initializePeerConnection();
    
    _dataChannel = await _peerConnection!.createDataChannel('chat', 
        RTCDataChannelInit()..ordered = true);
    _setupDataChannelHandlers();

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _roomId = await _signalingService.createRoom({
      'type': offer.type,
      'sdp': offer.sdp,
    });

    _listenForSignaling();
    return _roomId!;
  }

  Future<void> joinRoom(String roomId) async {
    _roomId = roomId;
    _isCaller = false;
    await _initializePeerConnection();
    _listenForSignaling();
  }

  void _listenForSignaling() {
    if (_roomId == null) return;

    if (_isCaller) {
      _answerSubscription = _signalingService.onRemoteAnswer(_roomId!).listen(
        (answer) async {
          if (answer != null) {
            await _handleRemoteAnswer(answer);
          }
        },
      );
    } else {
      _offerSubscription = _signalingService.onRemoteOffer(_roomId!).listen(
        (offer) async {
          if (offer != null) {
            await _handleRemoteOffer(offer);
          }
        },
      );
    }

    _iceCandidatesSubscription = _signalingService
        .onRemoteIceCandidates(_roomId!, _isCaller)
        .listen((candidate) async {
      await _handleRemoteIceCandidate(candidate);
    });
  }

  Future<void> _handleRemoteOffer(Map<String, dynamic> offerData) async {
    final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
    await _peerConnection!.setRemoteDescription(offer);

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await _signalingService.joinRoom(_roomId!, {
      'type': answer.type,
      'sdp': answer.sdp,
    });
    
    _isCaller = false;
  }

  Future<void> _handleRemoteAnswer(Map<String, dynamic> answerData) async {
    final answer = RTCSessionDescription(answerData['sdp'], answerData['type']);
    await _peerConnection!.setRemoteDescription(answer);
  }

  Future<void> _handleRemoteIceCandidate(Map<String, dynamic> candidateData) async {
    final candidate = RTCIceCandidate(
      candidateData['candidate'],
      candidateData['sdpMid'],
      candidateData['sdpMLineIndex'],
    );
    await _peerConnection!.addCandidate(candidate);
  }

  void _onIceCandidate(RTCIceCandidate candidate) {
    if (_roomId == null) return;
    _signalingService.sendIceCandidate(_roomId!, {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    }, _isCaller);
  }

  void _onConnectionStateChange(RTCPeerConnectionState state) {
    PeerConnectionState newState;
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        newState = PeerConnectionState.new_;
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        newState = PeerConnectionState.connecting;
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        newState = PeerConnectionState.connected;
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        newState = PeerConnectionState.disconnected;
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        newState = PeerConnectionState.failed;
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        newState = PeerConnectionState.closed;
        break;
    }
    _connectionStateController.add(newState);
  }

  void _onDataChannel(RTCDataChannel dataChannel) {
    _dataChannel = dataChannel;
    _setupDataChannelHandlers();
  }

  void _setupDataChannelHandlers() {
    if (_dataChannel == null) return;

    _dataChannel!.onMessage = (RTCDataChannelMessage message) {
      final messageData = jsonDecode(message.text);
      final msg = Message.fromJson(messageData);
      _messageController.add(msg);
    };
  }

  Future<void> sendMessage(String text) async {
    if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) return;

    final message = Message(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}',
      text: text,
      timestamp: DateTime.now(),
      isFromMe: true,
    );

    await _dataChannel!.send(RTCDataChannelMessage(jsonEncode(message.toJson())));
    _messageController.add(message);
  }

  Future<void> sendVoiceMessage(Uint8List voiceData) async {
    if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) return;

    final message = Message(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}',
      text: '[Voice Message]',
      timestamp: DateTime.now(),
      isFromMe: true,
      type: MessageType.voice,
      voiceData: voiceData,
    );

    await _dataChannel!.send(RTCDataChannelMessage(jsonEncode(message.toJson())));
    _messageController.add(message);
  }

  Future<void> close() async {
    await _offerSubscription?.cancel();
    await _answerSubscription?.cancel();
    await _iceCandidatesSubscription?.cancel();
    _dataChannel?.close();
    await _peerConnection?.close();
    await _connectionStateController.close();
    await _messageController.close();
  }

  void dispose() {
    close();
  }
}
