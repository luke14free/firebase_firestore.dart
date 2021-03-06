import 'package:tekartik_common_utils/env_utils.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:path/path.dart';
import 'package:tekartik_firebase_firestore/src/firestore_common.dart';

abstract class PathReference {
  // Firestore get firestore;
  String get path;

  /// Parent path.
  String get parentPath;

  String get id;

  /// Child path
  String getChildPath(String child);
}

abstract class FirestorePathReference extends PathReference {
  Firestore get firestore;
}

/// Only for implementation that needs it
mixin PathReferenceImplMixin implements FirestorePathReference {
  Firestore _firestore;
  String _path;

  @override
  Firestore get firestore => _firestore;

  @override
  String get path => _path;

  void init(Firestore firestore, String path) {
    _firestore = firestore;
    _path = path;
  }
}
mixin PathReferenceMixin implements PathReference {
  /// Parent path.
  @override
  String get parentPath => getParentPath(path);

  @override
  String get id => path == null ? null : url.basename(path);

  /// Child path
  @override
  String getChildPath(String child) => url.join(path, child);

  @override
  String toString() => 'path: $path';
}

String getParentPath(String path) {
  return url.dirname(path);
}

String getPathId(String path) => path == null ? null : url.basename(path);

mixin CollectionReferenceMixin
    implements CollectionReference, PathReferenceMixin, PathReferenceImplMixin {
  @override
  DocumentReference get parent => firestore.doc(parentPath);

  @override
  DocumentReference doc([String path]) => firestore.doc(getChildPath(path));
}
mixin DocumentReferenceMixin
    implements DocumentReference, FirestorePathReference {
  @override
  CollectionReference get parent => firestore.collection(parentPath);

  @override
  CollectionReference collection(String path) =>
      firestore.collection(getChildPath(path));

  @override
  int get hashCode => path.hashCode;

  @override
  bool operator ==(other) {
    if (other is DocumentReferenceMixin) {
      if (firestore != (other).firestore) {
        return false;
      }
      if (path != (other).path) {
        return false;
      }
      return true;
    }
    return false;
  }
}

/// Remove 'projects/<project>/databases/(default)/documents if any
List<String> localPathReferenceParts(String path) {
  var parts = url.split(sanitizeReferencePath(path));
  if (parts.length > 6 &&
      parts[0] == 'projects' &&
      parts[2] == 'databases' &&
      parts[4] == 'documents') {
    parts = parts.sublist(5);
  }
  return parts;
}

/// Throw if not valid - debug only
void checkCollectionReferencePath(String path) {
  if (isDebug) {
    var parts = localPathReferenceParts(path);
    assert(parts.length % 2 == 1,
        'Collection references must have an odd number of segments, but $path ($parts) has length ${parts.length}');
  }
}

void checkDocumentReferencePath(String path) {
  if (isDebug) {
    var parts = localPathReferenceParts(path);
    assert(parts.length % 2 == 0,
        'Document references must have an even number of segments, but $path ($parts) has length ${parts.length}');
  }
}
