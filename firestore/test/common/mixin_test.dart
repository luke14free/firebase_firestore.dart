import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:tekartik_firebase_firestore/src/common/reference_mixin.dart';
import 'package:tekartik_firebase_firestore/src/common/value_key_mixin.dart';
import 'package:tekartik_firebase_firestore/src/firestore_common.dart';
import 'package:tekartik_firebase_firestore/utils/firestore_mixin.dart';
import 'package:test/test.dart';

class FirestoreMock with FirestoreMixin {
  @override
  WriteBatch batch() {
    // TODO: implement batch
    return null;
  }

  @override
  CollectionReference collection(String path) {
    return CollectionReferenceMock(this, path);
  }

  @override
  DocumentReference doc(String path) {
    return DocumentReferenceMock(this, path);
  }

  @override
  Future<List<DocumentSnapshot>> getAll(List<DocumentReference> refs) {
    // TODO: implement getAll
    return null;
  }

  @override
  Future runTransaction(Function(Transaction transaction) updateFunction) {
    // TODO: implement runTransaction
    return null;
  }
}

class CollectionReferenceMock
    with
        CollectionReferenceMixin,
        PathReferenceImplMixin,
        PathReferenceMixin,
        FirestoreQueryMixin {
  CollectionReferenceMock(FirestoreMock firestoreMock, String path) {
    init(firestoreMock, path);
  }
  @override
  Future<DocumentReference> add(Map<String, dynamic> data) {
    // TODO: implement add
    return null;
  }

  @override
  FirestoreQueryMixin clone() {
    // TODO: implement clone
    return null;
  }

  @override
  Future<List<DocumentSnapshot>> getCollectionDocuments() {
    // TODO: implement getCollectionDocuments
    return null;
  }

  @override
  // TODO: implement parent
  DocumentReference get parent => null;

  @override
  // TODO: implement queryInfo
  QueryInfo get queryInfo => null;
}

class DocumentReferenceMock
    with DocumentReferenceMixin, PathReferenceImplMixin, PathReferenceMixin {
  DocumentReferenceMock(FirestoreMock firestoreMock, String path) {
    init(firestoreMock, path);
  }

  @override
  Future delete() {
    // TODO: implement delete
    return null;
  }

  @override
  Future<DocumentSnapshot> get() {
    // TODO: implement get
    return null;
  }

  @override
  Stream<DocumentSnapshot> onSnapshot() {
    // TODO: implement onSnapshot
    return null;
  }

  @override
  Future set(Map<String, dynamic> data, [SetOptions options]) {
    // TODO: implement set
    return null;
  }

  @override
  Future update(Map<String, dynamic> data) {
    // TODO: implement update
    return null;
  }
}

void main() {
  group('mixin_mock', () {
    var mock = FirestoreMock();
    test('path', () {
      var doc = mock.doc('my/path');
      expect('my/path', doc.path);
      expect('my', doc.parent.path);
    });
  });
  group('value_key_mixin', () {
    test('backtick', () {
      expect(backtickChrCode, 96);
      expect(isBacktickEnclosed('``'), isTrue);
      expect(isBacktickEnclosed('`é`'), isTrue);
      expect(isBacktickEnclosed('```'), isTrue);
      expect(isBacktickEnclosed(''), isFalse);
      expect(isBacktickEnclosed('`'), isFalse);
      expect(isBacktickEnclosed('`_'), isFalse);
      expect(isBacktickEnclosed('_`'), isFalse);
    });

    test('expandUpdateData', () {
      expect(
          expandUpdateData({
            //'a.added': 2,
            'a.b.added': 3,
            'a.b.c.replaced': 4,
          }),
          {
            'a': {
              'b': {
                'added': 3,
                'c': {'replaced': 4}
              }
            }
          });
      expect(expandUpdateData({'some.data': 1}), {
        'some': {'data': 1}
      });
      expect(expandUpdateData({'some.sub.data': 1}), {
        'some': {
          'sub': {'data': 1}
        }
      });
      expect(expandUpdateData({'sub.test': 1, 'sub.sub.test': 2}), {
        'sub': {
          'test': 1,
          'sub': {'test': 2}
        }
      });
    });

    test('cloneValue', () {
      var existing = {
        'test': 1,
        'nested': {
          'sub': 2,
          'list': [
            {'n': 1},
            2
          ]
        }
      };
      var cloned = cloneValue(existing);
      expect(cloned, existing);
      existing['test'] = 3;
      (existing['nested'] as Map)['sub'] = 4;
      (((existing['nested'] as Map)['list'] as List)[0] as Map)['n'] = 5;
      // Make sure chaging the existing does not change the clone
      expect(existing, {
        'test': 3,
        'nested': {
          'sub': 4,
          'list': [
            {'n': 5},
            2
          ]
        }
      });
      expect(cloned, {
        'test': 1,
        'nested': {
          'sub': 2,
          'list': [
            {'n': 1},
            2
          ]
        }
      });
    });
    test('mergeInnerMap', () {
      expect(
          mergeSanitizedMap({
            't1': {'s1': 1}
          }, {
            't1': {'s2': 2}
          }),
          {
            't1': {'s1': 1, 's2': 2}
          });
      expect(
          mergeSanitizedMap({
            't1': {'s1': 1}
          }, {
            't1.s2': 2
          }),
          {
            't1': {'s1': 1},
            't1.s2': 2
          });
    });
    test('mergeSubInnerMap', () {
      expect(
          mergeSanitizedMap({
            't1': {
              's1': {'u1': 1}
            }
          }, {
            't1': {'s2': 2}
          }),
          {
            't1': {
              's1': {'u1': 1},
              's2': 2
            }
          });
      expect(
          mergeSanitizedMap({
            't1': {
              's1': {'u1': 1}
            },
            's2': 2
          }, {
            't1.s1': {'u2': 3}
          }),
          {
            't1': {
              's1': {'u1': 1}
            },
            's2': 2,
            't1.s1': {'u2': 3}
          });
    });

    test('mergeValue', () {
      expect(mergeSanitizedMap(null, null), null);
      // expect(mergeValue(null, 1), 1);
      // expect(mergeValue(1, null), 1);
      expect(mergeSanitizedMap({'t': 1}, null), {'t': 1});
      // expect(mergeValue({'t': 1}, "2"), "2");
      // expect(mergeValue("2", {'t': 1}), {'t': 1});

      expect(mergeSanitizedMap({'t': 1}, {'t': 2}), {'t': 2});
      expect(mergeSanitizedMap({'t': 1}, {'u': 2}), {'t': 1, 'u': 2});
      expect(mergeSanitizedMap({'t': 1}, {'u': 2, 't': null}),
          {'t': null, 'u': 2});
      expect(mergeSanitizedMap({'t': 1}, {'u': 2, 't': FieldValue.delete}),
          {'u': 2, 't': FieldValue.delete});
      expect(
          mergeSanitizedMap({
            'sub': {'t': 1}
          }, {
            'sub': {'u': 2}
          }),
          {
            'sub': {'t': 1, 'u': 2}
          });

      expect(
          mergeSanitizedMap({
            'sub': {'t': 1, 'u': 2}
          }, {
            'sub.t': FieldValue.delete
          }),
          {
            'sub': {'t': 1, 'u': 2},
            'sub.t': FieldValue.delete
          });
      expect(
          mergeSanitizedMap({
            'sub': {'t': 1, 'u': 2}
          }, {
            'sub.dummy': FieldValue.delete
          }),
          {
            'sub': {'t': 1, 'u': 2},
            'sub.dummy': FieldValue.delete
          });
      expect(
          mergeSanitizedMap({
            'sub': {
              't': 1,
              'nested': {'t': 1, 'u': 2}
            }
          }, {
            'sub.nested.t': FieldValue.delete
          }),
          {
            'sub': {
              't': 1,
              'nested': {'t': 1, 'u': 2}
            },
            'sub.nested.t': FieldValue.delete
          });
      expect(
          mergeSanitizedMap({
            'sub': {'t': 1}
          }, {
            'sub.u': 2
          }),
          {
            'sub': {'t': 1},
            'sub.u': 2
          });
      expect(
          mergeSanitizedMap({
            'sub': {
              't': 1,
              'nested': {'t': 1, 'u': 2}
            }
          }, {
            'sub.nested.u': 3,
            'sub.nested.v.w': 4
          }),
          {
            'sub': {
              't': 1,
              'nested': {'t': 1, 'u': 2}
            },
            'sub.nested.u': 3,
            'sub.nested.v.w': 4
          });
    });
  });

  test('sanitizeInputEntry', () {
    expect(sanitizeInputEntry({'a.b': 1}), {
      'a': {'b': 1}
    });
  });
}
