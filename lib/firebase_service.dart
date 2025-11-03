import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirebaseService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  String? get userEmail => _auth.currentUser?.email;
  String? get userName => _auth.currentUser?.displayName;
  String? get userAvatar => _auth.currentUser?.displayName?[0] ?? _auth.currentUser?.email?[0];

  // ========== QUIZ POST METHODS ==========

  Future<bool> createQuizPost({
    required String question,
    required List<String> options,
    required String subject,
    List<String> tags = const [],
  }) async {
    try {
      if (_auth.currentUser == null) return false;

      Map<String, dynamic>? userData = await getUserData();
      
      String postId = _firestore.collection('posts').doc().id;
      
      // Initialize vote counts for each option
      Map<String, int> optionVotes = {};
      for (String option in options) {
        optionVotes[option] = 0;
      }

      await _firestore.collection('posts').doc(postId).set({
        'id': postId,
        'userId': _auth.currentUser!.uid,
        'userName': userData?['displayName'] ?? _auth.currentUser!.email!.split('@').first,
        'userAvatar': userData?['avatar'] ?? _auth.currentUser!.email![0],
        'content': question,
        'type': 'quiz',
        'subject': subject,
        'tags': tags,
        
        // Quiz-specific fields
        'quizOptions': options,
        'quizVotes': optionVotes,
        'votedUsers': [], // Track who voted to prevent multiple votes
        'totalVotes': 0,
        'correctAnswer': null, // Can be set later for educational quizzes
        
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'postsCount': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Create quiz post error: $e');
      }
      return false;
    }
  }

  Future<bool> voteOnQuiz(String postId, String selectedOption) async {
    try {
      if (_auth.currentUser == null) return false;

      final currentUserId = _auth.currentUser!.uid;

      // Check if user already voted
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final postData = postDoc.data() as Map<String, dynamic>;
      
      final List<dynamic> votedUsers = postData['votedUsers'] ?? [];
      if (votedUsers.contains(currentUserId)) {
        return false; // User already voted
      }

      // Update the vote
      await _firestore.collection('posts').doc(postId).update({
        'quizVotes.$selectedOption': FieldValue.increment(1),
        'totalVotes': FieldValue.increment(1),
        'votedUsers': FieldValue.arrayUnion([currentUserId]),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Vote on quiz error: $e');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> getQuizResults(String postId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return null;
      
      final postData = postDoc.data() as Map<String, dynamic>;
      return {
        'votes': postData['quizVotes'] ?? {},
        'totalVotes': postData['totalVotes'] ?? 0,
        'hasVoted': (postData['votedUsers'] ?? []).contains(_auth.currentUser?.uid),
      };
    } catch (e) {
      if (kDebugMode) {
        print('Get quiz results error: $e');
      }
      return null;
    }
  }

  // ========== AUTHENTICATION METHODS ==========

  Future<bool> signUp(String email, String password, String displayName) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user!.updateDisplayName(displayName);

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'displayName': displayName,
        'bio': 'Teen learner passionate about science and tech!',
        'avatar': displayName[0],
        'level': 1,
        'points': 0,
        'friendsCount': 0,
        'postsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('🔥 Firebase Sign Up Error: $e');
      }
      if (e is FirebaseAuthException) {
        print('🔥 Firebase Auth Error Code: ${e.code}');
        print('🔥 Firebase Auth Error Message: ${e.message}');
      }
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Sign in error: $e');
      }
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      if (_auth.currentUser == null) return null;
      
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
      return userDoc.data() as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  // ========== POST METHODS ==========

  Future<bool> createPost({
    required String content,
    required String type,
    String? imageUrl,
    String? subject,
    List<String> tags = const [],
  }) async {
    try {
      if (_auth.currentUser == null) return false;

      Map<String, dynamic>? userData = await getUserData();
      
      String postId = _firestore.collection('posts').doc().id;
      
      await _firestore.collection('posts').doc(postId).set({
        'id': postId,
        'userId': _auth.currentUser!.uid,
        'userName': userData?['displayName'] ?? _auth.currentUser!.email!.split('@').first,
        'userAvatar': userData?['avatar'] ?? _auth.currentUser!.email![0],
        'content': content,
        'type': type,
        'imageUrl': imageUrl,
        'subject': subject,
        'tags': tags,
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'postsCount': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Create post error: $e');
      }
      return false;
    }
  }

  Stream<QuerySnapshot> getPosts() {
    return _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ========== FIXED LIKE METHODS ==========

  Future<void> likePost(String postId) async {
    try {
      if (_auth.currentUser == null) return;

      final currentUserId = _auth.currentUser!.uid;
      final postRef = _firestore.collection('posts').doc(postId);
      
      // Check if user already liked this post
      final userLikeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(currentUserId);

      final userLikeDoc = await userLikeRef.get();
      
      if (userLikeDoc.exists) {
        // User already liked - unlike it
        await userLikeRef.delete();
        await postRef.update({
          'likes': FieldValue.increment(-1),
        });
      } else {
        // User hasn't liked - like it
        await userLikeRef.set({
          'userId': currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        await postRef.update({
          'likes': FieldValue.increment(1),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Like post error: $e');
      }
    }
  }

  Future<bool> hasUserLikedPost(String postId) async {
    try {
      if (_auth.currentUser == null) return false;

      final userLikeDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(_auth.currentUser!.uid)
          .get();

      return userLikeDoc.exists;
    } catch (e) {
      if (kDebugMode) {
        print('Check like error: $e');
      }
      return false;
    }
  }

  Future<void> addFriend() async {
    try {
      if (_auth.currentUser == null) return;

      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'friendsCount': FieldValue.increment(1),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Add friend error: $e');
      }
    }
  }

  Future<bool> updateProfile(String displayName, String bio) async {
    try {
      if (_auth.currentUser == null) return false;

      await _auth.currentUser!.updateDisplayName(displayName);

      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'displayName': displayName,
        'bio': bio,
        'avatar': displayName[0],
      });

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Update profile error: $e');
      }
      return false;
    }
  }

  // ========== FRIENDS SYSTEM METHODS ==========

  Future<void> sendFriendRequest(String targetUserId, String targetUserName, String targetUserAvatar) async {
    try {
      if (_auth.currentUser == null) return;

      final currentUserId = _auth.currentUser!.uid;
      
      // Check if request already exists
      final existingRequest = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: currentUserId)
          .where('toUserId', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) return;

      // Get current user data
      final currentUserData = await getUserData();
      
      // Create friend request
      await _firestore.collection('friend_requests').add({
        'fromUserId': currentUserId,
        'toUserId': targetUserId,
        'fromUserName': currentUserData?['displayName'] ?? userName ?? 'User',
        'fromUserAvatar': currentUserData?['avatar'] ?? userAvatar ?? 'U',
        'toUserName': targetUserName,
        'toUserAvatar': targetUserAvatar,
        'status': 'pending', // pending, accepted, rejected
        'createdAt': FieldValue.serverTimestamp(),
      });

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Send friend request error: $e');
      }
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    try {
      if (_auth.currentUser == null) return;

      final requestDoc = await _firestore.collection('friend_requests').doc(requestId).get();
      if (!requestDoc.exists) return;
      
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final fromUserId = requestData['fromUserId'];
      final currentUserId = _auth.currentUser!.uid;

      // Update request status
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Add to friends list for both users
      final batch = _firestore.batch();
      
      // Get current user data
      final currentUserData = await getUserData();
      
      // Add to current user's friends
      batch.set(
        _firestore.collection('users').doc(currentUserId).collection('friends').doc(fromUserId),
        {
          'userId': fromUserId,
          'userName': requestData['fromUserName'],
          'userAvatar': requestData['fromUserAvatar'],
          'friendsSince': FieldValue.serverTimestamp(),
        }
      );
      
      // Add to other user's friends
      batch.set(
        _firestore.collection('users').doc(fromUserId).collection('friends').doc(currentUserId),
        {
          'userId': currentUserId,
          'userName': currentUserData?['displayName'] ?? userName ?? 'User',
          'userAvatar': currentUserData?['avatar'] ?? userAvatar ?? 'U',
          'friendsSince': FieldValue.serverTimestamp(),
        }
      );

      // Update friends count for both users
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'friendsCount': FieldValue.increment(1),
      });
      
      batch.update(_firestore.collection('users').doc(fromUserId), {
        'friendsCount': FieldValue.increment(1),
      });

      await batch.commit();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Accept friend request error: $e');
      }
    }
  }

  Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': 'rejected',
      });
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Reject friend request error: $e');
      }
    }
  }

  Stream<QuerySnapshot> getFriendRequests() {
    try {
      if (_auth.currentUser == null) {
        return const Stream.empty();
      }
      
      final currentUserId = _auth.currentUser!.uid;
      
      return _firestore
          .collection('friend_requests')
          .where('toUserId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .snapshots();
    } catch (e) {
      if (kDebugMode) {
        print('Get friend requests error: $e');
      }
      return const Stream.empty();
    }
  }

  Stream<QuerySnapshot> getFriends() {
    try {
      if (_auth.currentUser == null) {
        return const Stream.empty();
      }
      
      return _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('friends')
          .snapshots();
    } catch (e) {
      if (kDebugMode) {
        print('Get friends error: $e');
      }
      return const Stream.empty();
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];

      final snapshot = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThan: query + 'z')
          .limit(10)
          .get();

      // Filter out current user
      final currentUserId = _auth.currentUser?.uid;
      return snapshot.docs
          .where((doc) => doc.id != currentUserId)
          .map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Search users error: $e');
      }
      return [];
    }
  }

  Future<Map<String, dynamic>?> getFriendStatus(String targetUserId) async {
    try {
      if (_auth.currentUser == null) return null;

      final currentUserId = _auth.currentUser!.uid;

      // Check if already friends
      final friendDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(targetUserId)
          .get();

      if (friendDoc.exists) {
        return {'status': 'friends'};
      }

      // Check for pending requests (sent by current user)
      final sentRequest = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: currentUserId)
          .where('toUserId', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (sentRequest.docs.isNotEmpty) {
        return {'status': 'request_sent', 'requestId': sentRequest.docs.first.id};
      }

      // Check for received requests (sent to current user)
      final receivedRequest = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: targetUserId)
          .where('toUserId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (receivedRequest.docs.isNotEmpty) {
        return {'status': 'request_received', 'requestId': receivedRequest.docs.first.id};
      }

      return {'status': 'not_friends'};
    } catch (e) {
      if (kDebugMode) {
        print('Get friend status error: $e');
      }
      return null;
    }
  }

  Future<void> removeFriend(String friendUserId) async {
    try {
      if (_auth.currentUser == null) return;

      final currentUserId = _auth.currentUser!.uid;

      final batch = _firestore.batch();

      // Remove from current user's friends
      batch.delete(
        _firestore.collection('users').doc(currentUserId).collection('friends').doc(friendUserId)
      );

      // Remove from friend's friends list
      batch.delete(
        _firestore.collection('users').doc(friendUserId).collection('friends').doc(currentUserId)
      );

      // Update friends count for both users
      batch.update(_firestore.collection('users').doc(currentUserId), {
        'friendsCount': FieldValue.increment(-1),
      });
      
      batch.update(_firestore.collection('users').doc(friendUserId), {
        'friendsCount': FieldValue.increment(-1),
      });

      await batch.commit();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Remove friend error: $e');
      }
    }
  }

  // ========== COMMENT METHODS ==========

  Future<bool> addComment(String postId, String content) async {
    try {
      if (_auth.currentUser == null) return false;

      Map<String, dynamic>? userData = await getUserData();
      
      String commentId = _firestore.collection('comments').doc().id;
      
      await _firestore.collection('comments').doc(commentId).set({
        'id': commentId,
        'postId': postId,
        'userId': _auth.currentUser!.uid,
        'userName': userData?['displayName'] ?? _auth.currentUser!.email!.split('@').first,
        'userAvatar': userData?['avatar'] ?? _auth.currentUser!.email![0],
        'content': content,
        'likes': 0,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update comment count in post
      await _firestore.collection('posts').doc(postId).update({
        'comments': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Add comment error: $e');
      }
      return false;
    }
  }

  Stream<QuerySnapshot> getComments(String postId) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> likeComment(String commentId) async {
    try {
      if (_auth.currentUser == null) return;

      final currentUserId = _auth.currentUser!.uid;
      final commentRef = _firestore.collection('comments').doc(commentId);
      
      // Check if user already liked this comment
      final userLikeRef = _firestore
          .collection('comments')
          .doc(commentId)
          .collection('likes')
          .doc(currentUserId);

      final userLikeDoc = await userLikeRef.get();
      
      if (userLikeDoc.exists) {
        // User already liked - unlike it
        await userLikeRef.delete();
        await commentRef.update({
          'likes': FieldValue.increment(-1),
        });
      } else {
        // User hasn't liked - like it
        await userLikeRef.set({
          'userId': currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        await commentRef.update({
          'likes': FieldValue.increment(1),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Like comment error: $e');
      }
    }
  }

  Future<bool> hasUserLikedComment(String commentId) async {
    try {
      if (_auth.currentUser == null) return false;

      final userLikeDoc = await _firestore
          .collection('comments')
          .doc(commentId)
          .collection('likes')
          .doc(_auth.currentUser!.uid)
          .get();

      return userLikeDoc.exists;
    } catch (e) {
      if (kDebugMode) {
        print('Check comment like error: $e');
      }
      return false;
    }
  }

  Future<void> deleteComment(String commentId, String postId) async {
    try {
      // Delete the comment
      await _firestore.collection('comments').doc(commentId).delete();
      
      // Decrement comment count in post
      await _firestore.collection('posts').doc(postId).update({
        'comments': FieldValue.increment(-1),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Delete comment error: $e');
      }
    }
  }
}