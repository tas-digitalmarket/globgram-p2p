import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/signaling/firestore_signaling_service.dart';
import 'signaling_test_page.dart';
import 'p2p_chat_page.dart';

class RoomSelectionPage extends StatefulWidget {
  const RoomSelectionPage({super.key});

  @override
  State<RoomSelectionPage> createState() => _RoomSelectionPageState();
}

class _RoomSelectionPageState extends State<RoomSelectionPage> {
  final FirestoreSignalingService _signalingService = FirestoreSignalingService();
  final TextEditingController _roomIdController = TextEditingController();
  
  String? _createdRoomId;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create a mock offer for testing
      final mockOffer = {
        'type': 'offer',
        'sdp': 'mock-sdp-data-for-testing',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final roomId = await _signalingService.createRoom(mockOffer);
      
      setState(() {
        _createdRoomId = roomId;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Room created successfully: $roomId'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create room: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _joinRoom() async {
    final roomId = _roomIdController.text.trim();
    
    if (roomId.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a room ID';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if room exists first
      final roomExists = await _signalingService.roomExists(roomId);
      
      if (!roomExists) {
        setState(() {
          _errorMessage = 'Room not found';
          _isLoading = false;
        });
        return;
      }

      // Create a mock answer for testing
      final mockAnswer = {
        'type': 'answer',
        'sdp': 'mock-answer-sdp-data-for-testing',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _signalingService.joinRoom(roomId, mockAnswer);
      
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        // Navigate to P2P chat as callee
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => P2PChatPage(
              roomId: roomId,
              isCaller: false,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to join room: $e';
        _isLoading = false;
      });
    }
  }

  void _copyRoomId() {
    if (_createdRoomId != null) {
      Clipboard.setData(ClipboardData(text: _createdRoomId!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room ID copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearError() {
    setState(() {
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Selection'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.video_call,
                      size: 48,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'GlobGram P2P Signaling',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create or join a room for peer connection',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      IconButton(
                        onPressed: _clearError,
                        icon: const Icon(Icons.close),
                        iconSize: 20,
                      ),
                    ],
                  ),
                ),
              ),

            if (_errorMessage != null) const SizedBox(height: 16),

            // Create Room Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Create New Room',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createRoom,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text(_isLoading ? 'Creating...' : 'Create Room'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    
                    if (_createdRoomId != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Room Created Successfully',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Room ID:',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Text(
                                      _createdRoomId!,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _copyRoomId,
                                  icon: const Icon(Icons.copy),
                                  tooltip: 'Copy Room ID',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => P2PChatPage(
                                            roomId: _createdRoomId!,
                                            isCaller: true,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.chat),
                                    label: const Text('Start P2P Chat'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SignalingTestPage(
                                            roomId: _createdRoomId!,
                                            isCaller: true,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.bug_report),
                                    label: const Text('Test Signaling'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Join Room Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.login,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Join Existing Room',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _roomIdController,
                      decoration: const InputDecoration(
                        labelText: 'Room ID',
                        hintText: 'Paste room ID here',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.vpn_key),
                      ),
                      onChanged: (value) => _clearError(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _joinRoom,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(_isLoading ? 'Joining...' : 'Join Room'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Info footer
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a signaling test. WebRTC implementation will be added in the next stage.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
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
}
