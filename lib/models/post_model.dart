class SocialPost {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final String? imageUrl;
  final PostType type;
  final DateTime timestamp;
  int likes;
  int comments;
  int shares;
  bool isLiked;
  bool isSaved;
  List<String> tags;
  String? subject;
  String? quizQuestion;
  List<String>? quizOptions;

  SocialPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    this.imageUrl,
    required this.type,
    required this.timestamp,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.tags = const [],
    this.subject,
    this.quizQuestion,
    this.quizOptions,
  });

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${difference.inDays ~/ 7}w ago';
  }
}

enum PostType {
  social,
  educational,
  quiz,
  achievement,
  studyGroup,
  resource,
}