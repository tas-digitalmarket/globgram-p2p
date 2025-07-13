import 'dart:async';
import 'package:flutter/material.dart';
import '../core/signaling/firestore_signaling_service.dart';

/// Test page to demonstrate Firestore signaling functionality
class SignalingTestPage extends StatefulWidget {
  final String roomId;
  final bool isCaller;

  const SignalingTestPage({
    super.key,
    required this.roomId,
    required this.isCaller,
  });

  @override
  State<SignalingTestPage> createState() => _SignalingTestPageState();
}

class _SignalingTestPageState extends State<SignalingTestPage> {
  final FirestoreSignalingService _signalingService = FirestoreSignalingService();
  final List<String> _logs = [];
  late StreamSubscription _offerSubscription;
  late StreamSubscription _answerSubscription;
  late StreamSubscription _iceCandidatesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeSignaling();
  }

  @override
  void dispose() {
    _offerSubscription.cancel();
    _answerSubscription.cancel();
    _iceCandidatesSubscription.cancel();
    super.dispose();
  }

  void _initializeSignaling() {
    _addLog('Initializing signaling for room: ${widget.roomId}');
    _addLog('Role: ${widget.isCaller ? "Caller" : "Callee"}');

    // Listen for remote offers
    _offerSubscription = _signalingService.onRemoteOffer(widget.roomId).listen(
      (offer) {
        if (offer != null && !widget.isCaller) {
          _addLog('📥 Received offer: ${offer['type']}');
        }
      },
      onError: (error) => _addLog('❌ Offer stream error: $error'),
    );

    // Listen for remote answers
    _answerSubscription = _signalingService.onRemoteAnswer(widget.roomId).listen(
      (answer) {
        if (answer != null && widget.isCaller) {
          _addLog('📥 Received answer: ${answer['type']}');
        }
      },
      onError: (error) => _addLog('❌ Answer stream error: $error'),
    );

    // Listen for ICE candidates
    _iceCandidatesSubscription = _signalingService
        .onRemoteIceCandidates(widget.roomId, !widget.isCaller)
        .listen(
      (candidate) {
        _addLog('🧊 Received ICE candidate: ${candidate['candidate']?.substring(0, 30)}...');
      },
      onError: (error) => _addLog('❌ ICE candidate stream error: $error'),
    );
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  Future<void> _sendTestIceCandidate() async {
    try {
      final mockCandidate = {
        'candidate': 'candidate:1 1 UDP 2113667326 192.168.1.100 54400 typ host generation 0',
        'sdpMid': 'video',
        'sdpMLineIndex': 0,
      };

      await _signalingService.sendIceCandidate(
        widget.roomId,
        mockCandidate,
        widget.isCaller,
      );

      _addLog('📤 Sent test ICE candidate');
    } catch (e) {
      _addLog('❌ Failed to send ICE candidate: $e');
    }
  }

  Future<void> _getRoomInfo() async {
    try {
      final roomInfo = await _signalingService.getRoomInfo(widget.roomId);
      if (roomInfo != null) {
        _addLog('📄 Room info loaded:');
        _addLog('  - Has offer: ${roomInfo['offer'] != null}');
        _addLog('  - Has answer: ${roomInfo['answer'] != null}');
        _addLog('  - Created: ${roomInfo['createdAt']?.toDate().toString() ?? "Unknown"}');
      } else {
        _addLog('❌ Room not found');
      }
    } catch (e) {
      _addLog('❌ Failed to get room info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Signaling Test - ${widget.isCaller ? "Caller" : "Callee"}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _logs.clear();
              });
            },
            icon: const Icon(Icons.clear),
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Info card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.isCaller ? Icons.call : Icons.call_received,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Room: ${widget.roomId}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Role: ${widget.isCaller ? "Caller (Created room)" : "Callee (Joined room)"}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sendTestIceCandidate,
                    icon: const Icon(Icons.send),
                    label: const Text('Send ICE'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _getRoomInfo,
                    icon: const Icon(Icons.info),
                    label: const Text('Room Info'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Logs section
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.terminal),
                        const SizedBox(width: 8),
                        Text(
                          'Signaling Logs',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          '${_logs.length} entries',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _logs.isEmpty
                        ? const Center(
                            child: Text('No logs yet. Actions will appear here.'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              final log = _logs[index];
                              Color? textColor;
                              if (log.contains('❌')) {
                                textColor = Colors.red;
                              } else if (log.contains('📥')) {
                                textColor = Colors.blue;
                              } else if (log.contains('📤')) {
                                textColor = Colors.green;
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  log,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: textColor,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
