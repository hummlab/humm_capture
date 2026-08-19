import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'feedback_report.dart';

/// Data access for a single-tenant Feedback Console Firebase project.
final class FeedbackRepository {
  FeedbackRepository({FirebaseFirestore? firestore, FirebaseStorage? storage, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final Map<String, Future<String?>> _screenshotUrls = <String, Future<String?>>{};
  final Map<String, Future<String?>> _attachmentUrls = <String, Future<String?>>{};

  Stream<List<FeedbackReport>> watchReports() => _firestore
      .collection('feedbackReports')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(FeedbackReport.fromSnapshot).toList(growable: false));

  Stream<List<FeedbackMember>> watchMembers() => _firestore
      .collection('users')
      .orderBy('email')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(FeedbackMember.fromSnapshot).toList(growable: false));

  Stream<FeedbackMember?> watchCurrentMember() {
    final user = _auth.currentUser;
    if (user == null) return Stream<FeedbackMember?>.value(null);
    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) => snapshot.exists ? FeedbackMember.fromSnapshot(snapshot) : null);
  }

  Stream<List<FeedbackStatusEvent>> watchStatusEvents(String reportId) => _firestore
      .collection('feedbackReports')
      .doc(reportId)
      .collection('statusEvents')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(FeedbackStatusEvent.fromSnapshot).toList(growable: false));

  Future<void> updateStatus({required FeedbackReport report, required FeedbackStatus status}) async {
    if (report.status == status) return;
    final user = _auth.currentUser;
    if (user == null) throw StateError('A signed-in reviewer is required.');

    final reportReference = _firestore.collection('feedbackReports').doc(report.id);
    final eventReference = reportReference.collection('statusEvents').doc();
    final actorLabel = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email ?? 'Unknown user');
    final batch = _firestore.batch();
    batch.update(reportReference, <String, Object?>{'status': status.value, 'updatedAt': FieldValue.serverTimestamp()});
    batch.set(eventReference, <String, Object?>{
      'fromStatus': report.status.value,
      'toStatus': status.value,
      'actorUid': user.uid,
      'actorLabel': actorLabel,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> updateReviewerAccess({required FeedbackMember member, required bool enabled}) =>
      _firestore.collection('users').doc(member.id).update(<String, Object?>{
        'feedbackRole': enabled ? FeedbackConsoleRole.reviewer.value : FieldValue.delete(),
        if (!enabled) 'feedbackCanCreateJiraTasks': false,
      });

  Future<void> updateJiraTaskCreatorAccess({required FeedbackMember member, required bool enabled}) =>
      _firestore.collection('users').doc(member.id).update(<String, Object?>{'feedbackCanCreateJiraTasks': enabled});

  /// Removes both the private screenshot and its Firestore report.
  ///
  /// Only console administrators have these operations in the supplied rules.
  Future<void> deleteReport(FeedbackReport report) async {
    final path = report.screenshotPath;
    if (path != null && path.isNotEmpty) {
      _screenshotUrls.remove(path);
      await _storage.ref(path).delete();
    }
    for (final attachment in report.attachments) {
      _attachmentUrls.remove(attachment.path);
      await _storage.ref(attachment.path).delete();
    }
    await _firestore.collection('feedbackReports').doc(report.id).delete();
  }

  Future<String?> screenshotUrlFor(FeedbackReport report) async {
    final path = report.screenshotPath;
    if (path == null || path.isEmpty) return null;
    return _screenshotUrls.putIfAbsent(path, () => _storage.ref(path).getDownloadURL());
  }

  /// Resolves one private, user-selected feedback attachment.
  Future<String?> attachmentUrlFor(FeedbackReportAttachment attachment) =>
      _attachmentUrls.putIfAbsent(attachment.path, () => _storage.ref(attachment.path).getDownloadURL());

  /// Resolves the optional plain-text log snapshot stored with [report].
  Future<String?> logsUrlFor(FeedbackReport report) async {
    final path = report.logsPath;
    if (path == null || path.isEmpty) return null;
    return _storage.ref(path).getDownloadURL();
  }
}
