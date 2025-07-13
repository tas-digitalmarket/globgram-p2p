import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore-based signaling service for WebRTC peer connections
/// Handles room creation, joining, and ICE candidate exchange
class FirestoreSignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const String _roomsCollection = 'rooms';
  static const String _candidatesCollection = 'candidates';
  static const String _callerCandidates = 'caller';
  static const String _calleeCandidates = 'callee';
  static const String _candidatesList = 'list';

  /// Creates a new room with the provided offer
  /// Returns the generated room ID
  Future<String> createRoom(Map<String, dynamic> offer) async {
    try {
      final roomRef = _firestore.collection(_roomsCollection).doc();
      
      await roomRef.set({
        'offer': offer,
        'answer': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return roomRef.id;
    } catch (e) {
      throw Exception('Failed to create room: $e');
    }
  }

  /// Joins an existing room with the provided answer
  Future<void> joinRoom(String roomId, Map<String, dynamic> answer) async {
    try {
      final roomRef = _firestore.collection(_roomsCollection).doc(roomId);
      
      // Check if room exists
      final roomSnapshot = await roomRef.get();
      if (!roomSnapshot.exists) {
        throw Exception('Room not found');
      }
      
      // Update room with answer
      await roomRef.update({
        'answer': answer,
      });
    } catch (e) {
      throw Exception('Failed to join room: $e');
    }
  }

  /// Sends an ICE candidate to the specified room
  /// [isCaller] determines if this is from caller or callee
  Future<void> sendIceCandidate(
    String roomId,
    Map<String, dynamic> candidate,
    bool isCaller,
  ) async {
    try {
      final candidateType = isCaller ? _callerCandidates : _calleeCandidates;
      final candidatesRef = _firestore
          .collection(_roomsCollection)
          .doc(roomId)
          .collection(_candidatesCollection)
          .doc(candidateType)
          .collection(_candidatesList);

      await candidatesRef.add({
        ...candidate,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to send ICE candidate: $e');
    }
  }

  /// Stream of remote offers for a specific room
  Stream<Map<String, dynamic>?> onRemoteOffer(String roomId) {
    return _firestore
        .collection(_roomsCollection)
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      return data?['offer'] as Map<String, dynamic>?;
    });
  }

  /// Stream of remote answers for a specific room
  Stream<Map<String, dynamic>?> onRemoteAnswer(String roomId) {
    return _firestore
        .collection(_roomsCollection)
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      return data?['answer'] as Map<String, dynamic>?;
    });
  }

  /// Stream of remote ICE candidates
  /// [isForCaller] determines if listening for caller or callee candidates
  Stream<Map<String, dynamic>> onRemoteIceCandidates(
    String roomId,
    bool isForCaller,
  ) {
    final candidateType = isForCaller ? _calleeCandidates : _callerCandidates;
    
    return _firestore
        .collection(_roomsCollection)
        .doc(roomId)
        .collection(_candidatesCollection)
        .doc(candidateType)
        .collection(_candidatesList)
        .orderBy('timestamp')
        .snapshots()
        .expand((snapshot) => snapshot.docChanges)
        .where((change) => change.type == DocumentChangeType.added)
        .map((change) => change.doc.data() as Map<String, dynamic>);
  }

  /// Deletes a room and all its data
  Future<void> deleteRoom(String roomId) async {
    try {
      final batch = _firestore.batch();
      final roomRef = _firestore.collection(_roomsCollection).doc(roomId);
      
      // Delete caller candidates
      final callerCandidatesRef = roomRef
          .collection(_candidatesCollection)
          .doc(_callerCandidates)
          .collection(_candidatesList);
      
      final callerSnapshot = await callerCandidatesRef.get();
      for (final doc in callerSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete callee candidates
      final calleeCandidatesRef = roomRef
          .collection(_candidatesCollection)
          .doc(_calleeCandidates)
          .collection(_candidatesList);
      
      final calleeSnapshot = await calleeCandidatesRef.get();
      for (final doc in calleeSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete candidate containers
      batch.delete(roomRef.collection(_candidatesCollection).doc(_callerCandidates));
      batch.delete(roomRef.collection(_candidatesCollection).doc(_calleeCandidates));
      
      // Delete room document
      batch.delete(roomRef);
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete room: $e');
    }
  }

  /// Checks if a room exists
  Future<bool> roomExists(String roomId) async {
    try {
      final roomSnapshot = await _firestore
          .collection(_roomsCollection)
          .doc(roomId)
          .get();
      return roomSnapshot.exists;
    } catch (e) {
      return false;
    }
  }

  /// Gets room information
  Future<Map<String, dynamic>?> getRoomInfo(String roomId) async {
    try {
      final roomSnapshot = await _firestore
          .collection(_roomsCollection)
          .doc(roomId)
          .get();
      
      if (!roomSnapshot.exists) return null;
      return roomSnapshot.data();
    } catch (e) {
      return null;
    }
  }
}
