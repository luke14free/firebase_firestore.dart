import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:tekartik_common_utils/date_time_utils.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:tekartik_firebase_firestore/src/firestore.dart';
import 'package:tekartik_firebase_firestore/utils/firestore_mixin.dart';
import 'package:tekartik_firebase_firestore/utils/timestamp_utils.dart';

import 'common/reference_mixin.dart';

const String jsonTypeField = r'$t';
const String jsonValueField = r'$v';
const String typeDateTime = 'DateTime';
const String typeTimestamp = 'Timestamp';
const String typeFieldValue = 'FieldValue';
const String typeDocumentReference = 'DocumentReference';
const String typeGeoPoint = 'GeoPoint';
const String typeBlob = 'Blob';
const String valueFieldValueDelete = '~delete';
const String valueFieldValueServerTimestamp = '~serverTimestamp';

Map<String, dynamic> typeValueToJson(String type, dynamic value) {
  return <String, dynamic>{jsonTypeField: type, jsonValueField: value};
}

Map<String, dynamic> dateTimeToJsonValue(DateTime dateTime) =>
    typeValueToJson(typeDateTime, dateTimeToString(dateTime));

Map<String, dynamic> timestampToJsonValue(Timestamp timestamp) =>
    typeValueToJson(typeTimestamp, timestamp?.toIso8601String());

Map<String, dynamic> documentReferenceToJsonValue(
        DocumentReference documentReference) =>
    typeValueToJson(typeDocumentReference, documentReference?.path);

Map<String, dynamic> blobToJsonValue(Blob blob) => typeValueToJson(
    typeBlob, blob.data != null ? base64.encode(blob.data) : null);

Map<String, dynamic> fieldValueToJsonValue(FieldValue fieldValue) {
  if (fieldValue == FieldValue.delete) {
    return typeValueToJson(typeFieldValue, valueFieldValueDelete);
  } else if (fieldValue == FieldValue.serverTimestamp) {
    return typeValueToJson(typeFieldValue, valueFieldValueServerTimestamp);
  }
  throw ArgumentError.value(fieldValue, '${fieldValue.runtimeType}',
      'Unsupported value for fieldValueToJsonValue');
}

FieldValue fieldValueFromJsonValue(dynamic value) {
  if (value == valueFieldValueDelete) {
    return FieldValue.delete;
  } else if (value == valueFieldValueServerTimestamp) {
    return FieldValue.serverTimestamp;
  }
  throw ArgumentError.value(value, '${value.runtimeType}',
      'Unsupported value for fieldValueFromJsonValue');
}

DateTime jsonValueToDateTime(Map map) {
  if (map == null) {
    return null;
  }
  assert(map[jsonTypeField] == typeDateTime);
  return anyToDateTime(map[jsonValueField]);
}

Timestamp jsonValueToTimestamp(Map map) {
  if (map == null) {
    return null;
  }
  assert(map[jsonTypeField] == typeDateTime ||
      map[jsonTypeField] == typeTimestamp);
  return parseTimestamp(map[jsonValueField]);
}

DocumentReference jsonValueToDocumentReference(Firestore firestore, Map map) {
  if (map == null) {
    return null;
  }
  assert(map[jsonTypeField] == typeDocumentReference);
  return firestore.doc(map[jsonValueField] as String);
}

Blob jsonValueToBlob(Map map) {
  if (map == null) {
    return null;
  }
  assert(map[jsonTypeField] == typeBlob);
  var base64value = map[jsonValueField] as String;
  if (base64value == null) {
    return Blob(null);
  } else {
    return Blob(base64.decode(base64value));
  }
}

Map<String, dynamic> geoPointToJsonValue(GeoPoint geoPoint) {
  if (geoPoint == null) {
    return null;
  }
  return typeValueToJson(typeGeoPoint,
      {'latitude': geoPoint.latitude, 'longitude': geoPoint.longitude});
}

GeoPoint jsonValueToGeoPoint(Map map) {
  if (map == null) {
    return null;
  }
  assert(map[jsonTypeField] == typeGeoPoint);
  var valueMap = map[jsonValueField] as Map;
  return GeoPoint(valueMap['latitude'] as num, valueMap['longitude'] as num);
}

// utilities

// common value in both format
bool _isCommonValue(dynamic value) {
  return (value == null) ||
      (value is String) ||
      (value is num) ||
      (value is bool);
}

dynamic documentDataValueToJson(dynamic value) {
  if (_isCommonValue(value)) {
    return value;
  } else if (value is List) {
    return value.map((value) => documentDataValueToJson(value)).toList();
  } else if (value is Map) {
    return value.map<String, dynamic>((key, value) =>
        MapEntry(key as String, documentDataValueToJson(value)));
  } else if (value is DocumentData) {
    // Handle this that could happen from a map
    return documentDataValueToJson((value as DocumentDataMap).map);
  } else if (value is DateTime) {
    return dateTimeToJsonValue(value);
  } else if (value is Timestamp) {
    return timestampToJsonValue(value);
  } else if (value is FieldValue) {
    return fieldValueToJsonValue(value);
  } else if (value is DocumentReference) {
    return documentReferenceToJsonValue(value);
  } else if (value is Blob) {
    return blobToJsonValue(value);
  } else if (value is GeoPoint) {
    return geoPointToJsonValue(value);
  } else {
    throw ArgumentError.value(value, '${value.runtimeType}',
        'Unsupported value for documentDataValueToJson');
  }
}

dynamic jsonToDocumentDataValue(Firestore firestore, dynamic value) {
  if (_isCommonValue(value)) {
    return value;
  } else if (value is List) {
    return value
        .map((value) => jsonToDocumentDataValue(firestore, value))
        .toList();
  } else if (value is Map) {
    // Check encoded value
    var type = value[jsonTypeField] as String;
    if (type != null) {
      switch (type) {
        case typeDateTime:
          {
            var dateTime = anyToDateTime(value[jsonValueField])?.toLocal();
            if (firestoreTimestampsInSnapshots(firestore)) {
              return Timestamp.fromDateTime(dateTime);
            }
            return dateTime;
          }
        case typeTimestamp:
          {
            var timestamp = parseTimestamp(value[jsonValueField]);
            if (firestoreTimestampsInSnapshots(firestore)) {
              return timestamp;
            }
            return timestamp.toDateTime();
          }
        case typeFieldValue:
          return fieldValueFromJsonValue(value[jsonValueField]);
        case typeDocumentReference:
          return jsonValueToDocumentReference(firestore, value);
        case typeBlob:
          return jsonValueToBlob(value);
        case typeGeoPoint:
          return jsonValueToGeoPoint(value);
        default:
          throw UnsupportedError('value $value');
      }
    } else {
      return value.map<String, dynamic>((key, value) =>
          MapEntry(key as String, jsonToDocumentDataValue(firestore, value)));
    }
  } else {
    throw ArgumentError.value(value, '${value.runtimeType}',
        'Unsupported value for jsonToDocumentDataValue');
  }
}

// remove createTime and updateTime
DocumentData documentDataFromSnapshotJsonMap(
    Firestore firestore, Map<String, dynamic> map) {
  if (map == null) {
    return null;
  }
  map.remove(createTimeKey);
  map.remove(updateTimeKey);
  return documentDataFromJsonMap(firestore, map);
}

DocumentData documentDataFromJsonMap(
    Firestore firestore, Map<String, dynamic> map) {
  if (map == null) {
    return null;
  }
  return DocumentDataMap(
      map: jsonToDocumentDataValue(firestore, map) as Map<String, dynamic>);
}

// will return null if map is null
DocumentData documentDataFromMap(Map<String, dynamic> map) {
  if (map != null) {
    return null;
  }
  return DocumentData(map);
}

DocumentData documentDataFromSnapshot(DocumentSnapshot snapshot) =>
    snapshot?.exists == true ? DocumentData(snapshot.data) : null;

Map<String, dynamic> snapshotToJsonMap(DocumentSnapshot snapshot) {
  if (snapshot?.exists == true) {
    var map = documentDataToJsonMap(documentDataFromSnapshot(snapshot));
    return map;
  } else {
    return null;
  }
}

Map<String, dynamic> documentDataToJsonMap(DocumentData documentData) {
  if (documentData == null) {
    return null;
  }
  return documentDataValueToJson((documentData as DocumentDataMap).map)
      as Map<String, dynamic>;
}

class OrderByInfo {
  String fieldPath;
  bool ascending;

  OrderByInfo({@required this.fieldPath, @required this.ascending});

  @override
  String toString() => '$fieldPath ${ascending ? 'ASC' : 'DESC'}';
}

class LimitInfo {
  String documentId;
  List values;
  bool inclusive; // true = At

  LimitInfo clone() {
    return LimitInfo()
      ..documentId = documentId
      ..values = values
      ..inclusive = inclusive;
  }
}

class WhereInfo {
  String fieldPath;

  WhereInfo(
    this.fieldPath, {
    this.isEqualTo,
    this.isLessThan,
    this.isLessThanOrEqualTo,
    this.isGreaterThan,
    this.isGreaterThanOrEqualTo,
    this.arrayContains,
    this.arrayContainsAny,
    this.whereIn,
    this.isNull,
  }) {
    assert(
        isEqualTo != null ||
            isLessThan != null ||
            isLessThanOrEqualTo != null ||
            isGreaterThan != null ||
            isGreaterThanOrEqualTo != null ||
            arrayContains != null ||
            arrayContainsAny != null ||
            whereIn != null ||
            isNull != null,
        'Empty where');
    assert(arrayContainsAny == null || arrayContainsAny.isNotEmpty,
        'Invalid Query. A non-empty array is required for \'array-contains-any\' filters.');
  }

  dynamic isEqualTo;
  dynamic isLessThan;
  dynamic isLessThanOrEqualTo;
  dynamic isGreaterThan;
  dynamic isGreaterThanOrEqualTo;
  dynamic arrayContains;
  List<dynamic> arrayContainsAny;
  List<dynamic> whereIn;
  bool isNull;

  @override
  String toString() {
    if (isNull != null) {
      return '$fieldPath is null';
    } else if (isEqualTo != null) {
      return '$fieldPath == $isEqualTo';
    } else if (isLessThan != null) {
      return '$fieldPath < $isLessThan';
    } else if (isLessThanOrEqualTo != null) {
      return '$fieldPath <= $isLessThanOrEqualTo';
    } else if (isGreaterThan != null) {
      return '$fieldPath > $isGreaterThan';
    } else if (isGreaterThanOrEqualTo != null) {
      return '$fieldPath >= $isGreaterThanOrEqualTo';
    } else if (arrayContains != null) {
      return '$fieldPath array-contains $arrayContains';
    } else if (arrayContainsAny != null) {
      return '$fieldPath array-contains-any $arrayContainsAny';
    } else if (whereIn != null) {
      return '$fieldPath in $whereIn';
    }
    return super.toString();
  }
}

// Mutable, must be clone before
class QueryInfo {
  List<String> selectKeyPaths;
  List<OrderByInfo> orderBys = [];

  LimitInfo startLimit;
  LimitInfo endLimit;

  int limit;
  int offset;
  List<WhereInfo> wheres = [];

  QueryInfo clone() {
    return QueryInfo()
      ..limit = limit
      ..offset = offset
      ..startLimit = startLimit?.clone()
      ..endLimit = endLimit?.clone()
      ..wheres = List.from(wheres)
      ..selectKeyPaths = selectKeyPaths
      ..orderBys = List.from(orderBys);
  }

  void startAt({DocumentSnapshot snapshot, List values}) =>
      startLimit = (LimitInfo()
        ..documentId = snapshot?.ref?.id
        ..values = values
        ..inclusive = true);

  void startAfter({DocumentSnapshot snapshot, List values}) =>
      startLimit = (LimitInfo()
        ..documentId = snapshot?.ref?.id
        ..values = values
        ..inclusive = false);

  void endAt({DocumentSnapshot snapshot, List values}) =>
      endLimit = (LimitInfo()
        ..documentId = snapshot?.ref?.id
        ..values = values
        ..inclusive = true);

  void endBefore({DocumentSnapshot snapshot, List values}) =>
      endLimit = (LimitInfo()
        ..documentId = snapshot?.ref?.id
        ..values = values
        ..inclusive = false);

  void addWhere(WhereInfo where) {
    wheres.add(where);
  }
}

WhereInfo whereInfoFromJsonMap(Firestore firestore, Map<String, dynamic> map) {
  bool isNull;
  var isEqualTo;
  var value = jsonToDocumentDataValue(firestore, map['value']);
  var operator = map['operator'];
  if (operator == operatorEqual) {
    if (value == null) {
      isNull = true;
    } else {
      isEqualTo = value;
    }
  } else if (operator == operatorLessThan) {}
  var whereInfo = WhereInfo(map['fieldPath'] as String,
      isEqualTo: isEqualTo,
      isNull: isNull,
      isLessThan: (operator == operatorLessThan) ? value : null,
      isLessThanOrEqualTo: (operator == operatorLessThanOrEqual) ? value : null,
      isGreaterThan: (operator == operatorGreaterThan) ? value : null,
      isGreaterThanOrEqualTo:
          (operator == operatorGreaterThanOrEqual) ? value : null,
      arrayContains: (operator == operatorArrayContains) ? value : null);

  return whereInfo;
}

OrderByInfo orderByInfoFromJsonMap(Map<String, dynamic> map) {
  var orderByInfo = OrderByInfo(
      fieldPath: map['fieldPath'] as String,
      ascending: map['direction'] as String != orderByDescending);
  return orderByInfo;
}

const _operatorKey = 'operator';
const _valueKey = 'value';

Map<String, dynamic> whereInfoToJsonMap(WhereInfo whereInfo) {
  var map = <String, dynamic>{'fieldPath': whereInfo.fieldPath};
  if (whereInfo.isEqualTo != null) {
    map[_operatorKey] = operatorEqual;
    map[_valueKey] = documentDataValueToJson(whereInfo.isEqualTo);
  } else if (whereInfo.isLessThanOrEqualTo != null) {
    map[_operatorKey] = operatorLessThanOrEqual;
    map[_valueKey] = documentDataValueToJson(whereInfo.isLessThanOrEqualTo);
  } else if (whereInfo.isLessThan != null) {
    map[_operatorKey] = operatorLessThan;
    map[_valueKey] = documentDataValueToJson(whereInfo.isLessThan);
  } else if (whereInfo.isGreaterThanOrEqualTo != null) {
    map[_operatorKey] = operatorGreaterThanOrEqual;
    map[_valueKey] = documentDataValueToJson(whereInfo.isGreaterThanOrEqualTo);
  } else if (whereInfo.isGreaterThan != null) {
    map[_operatorKey] = operatorGreaterThan;
    map[_valueKey] = documentDataValueToJson(whereInfo.isGreaterThan);
  } else if (whereInfo.arrayContains != null) {
    map[_operatorKey] = operatorArrayContains;
    map[_valueKey] = documentDataValueToJson(whereInfo.arrayContains);
  } else if (whereInfo.isNull != null) {
    map[_operatorKey] = operatorEqual;
    map[_valueKey] = null;
  }
  return map;
}

Map<String, dynamic> orderByInfoToJsonMap(OrderByInfo orderByInfo) {
  var map = <String, dynamic>{
    'fieldPath': orderByInfo.fieldPath,
    'direction':
        orderByInfo.ascending == true ? orderByAscending : orderByDescending
  };
  return map;
}

Map<String, dynamic> limitInfoToJsonMap(LimitInfo limitInfo) {
  var map = <String, dynamic>{};
  if (limitInfo.inclusive == true) {
    map['inclusive'] = true;
  }
  if (limitInfo.values != null) {
    map['values'] = limitInfo.values
        .map((value) => documentDataValueToJson(value))
        .toList();
  }
  if (limitInfo.documentId != null) {
    map['documentId'] = limitInfo.documentId;
  }
  return map;
}

LimitInfo limitInfoFromJsonMap(Firestore firestore, Map<String, dynamic> map) {
  var limitInfo = LimitInfo();
  if (map.containsKey('inclusive')) {
    limitInfo.inclusive = map['inclusive'] == true;
  }
  if (map.containsKey('values')) {
    limitInfo.values = (map['values'] as List)
        .map((value) => jsonToDocumentDataValue(firestore, value))
        .toList();
  } else if (map.containsKey('documentId')) {
    limitInfo.documentId = map['documentId'] as String;
  }
  return limitInfo;
}

Map<String, dynamic> queryInfoToJsonMap(QueryInfo queryInfo) {
  var map = <String, dynamic>{};
  if (queryInfo.limit != null) {
    map['limit'] = queryInfo.limit;
  }
  if (queryInfo.offset != null) {
    map['offset'] = queryInfo.offset;
  }
  if (queryInfo.wheres.isNotEmpty) {
    map['wheres'] = queryInfo.wheres
        .map((whereInfo) => whereInfoToJsonMap(whereInfo))
        .toList();
  }
  if (queryInfo.orderBys.isNotEmpty) {
    map['orderBys'] = queryInfo.orderBys
        .map((orderBy) => orderByInfoToJsonMap(orderBy))
        .toList();
  }
  if (queryInfo.selectKeyPaths != null) {
    map['selectKeyPaths'] = queryInfo.selectKeyPaths;
  }
  if (queryInfo.startLimit != null) {
    map['startLimit'] = limitInfoToJsonMap(queryInfo.startLimit);
  }
  if (queryInfo.endLimit != null) {
    map['endLimit'] = limitInfoToJsonMap(queryInfo.endLimit);
  }
  return map;
}

QueryInfo queryInfoFromJsonMap(Firestore firestore, Map<String, dynamic> map) {
  final queryInfo = QueryInfo();
  if (map.containsKey('limit')) {
    queryInfo.limit = map['limit'] as int;
  }
  if (map.containsKey('offset')) {
    queryInfo.offset = map['offset'] as int;
  }
  if (map.containsKey('wheres')) {
    queryInfo.wheres = (map['wheres'] as List)
        .map<WhereInfo>((map) =>
            whereInfoFromJsonMap(firestore, map as Map<String, dynamic>))
        .toList();
  }
  if (map.containsKey('orderBys')) {
    queryInfo.orderBys = (map['orderBys'] as List)
        .map<OrderByInfo>(
            (map) => orderByInfoFromJsonMap(map as Map<String, dynamic>))
        .toList();
  }
  if (map.containsKey('selectKeyPaths')) {
    queryInfo.selectKeyPaths = (map['selectKeyPaths'] as List).cast<String>();
  }
  if (map.containsKey('startLimit')) {
    queryInfo.startLimit = limitInfoFromJsonMap(
        firestore, map['startLimit'] as Map<String, dynamic>);
  }
  if (map.containsKey('endLimit')) {
    queryInfo.endLimit = limitInfoFromJsonMap(
        firestore, map['endLimit'] as Map<String, dynamic>);
  }
  return queryInfo;
}

const changeTypeAdded = 'added';
const changeTypeModified = 'modified';
const changeTypeRemoved = 'removed';

DocumentChangeType documentChangeTypeFromString(String type) {
  // [:added:], [:removed:] or [:modified:]
  if (type == changeTypeAdded) {
    return DocumentChangeType.added;
  } else if (type == changeTypeRemoved) {
    return DocumentChangeType.removed;
  } else if (type == changeTypeModified) {
    return DocumentChangeType.modified;
  }
  return null;
}

String documentChangeTypeToString(DocumentChangeType type) {
  switch (type) {
    case DocumentChangeType.added:
      return changeTypeAdded;
    case DocumentChangeType.removed:
      return changeTypeRemoved;
    case DocumentChangeType.modified:
      return changeTypeModified;
  }
  return null;
}

String sanitizeReferencePath(String path) {
  if (path != null) {
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
  }
  return path;
}

bool isDocumentReferencePath(String path) {
  if (path == null) {
    return true;
  }
  var count = localPathReferenceParts(path).length;
  return (count % 2) == 0;
}

abstract class WriteBatchBase implements WriteBatch {
  final List<WriteBatchOperation> operations = [];

  @override
  void delete(DocumentReference ref) =>
      operations.add(WriteBatchOperationDelete(ref));

  @override
  void set(DocumentReference ref, Map<String, dynamic> data,
      [SetOptions options]) {
    operations.add(WriteBatchOperationSet(ref, DocumentData(data), options));
  }

  @override
  void update(DocumentReference ref, Map<String, dynamic> data) {
    operations.add(WriteBatchOperationUpdate(ref, DocumentData(data)));
  }
}

abstract class WriteBatchOperation {}

class WriteBatchOperationBase implements WriteBatchOperation {
  final DocumentReference docRef;

  WriteBatchOperationBase(this.docRef);

  @override
  String toString() => '$runtimeType(${docRef.path})';
}

class WriteBatchOperationDelete extends WriteBatchOperationBase {
  WriteBatchOperationDelete(DocumentReference docRef) : super(docRef);
}

class WriteBatchOperationSet extends WriteBatchOperationBase {
  final DocumentData documentData;
  final SetOptions options;

  WriteBatchOperationSet(
      DocumentReference docRef, this.documentData, this.options)
      : super(docRef);
}

class WriteBatchOperationUpdate extends WriteBatchOperationBase {
  final DocumentData documentData;

  WriteBatchOperationUpdate(DocumentReference docRef, this.documentData)
      : super(docRef);
}

abstract class WriteResultBase {
  final String path;

  WriteResultBase(this.path);

  bool get added => newExists && !previousExists;

  bool get removed => previousExists && !newExists;

  bool get exists => newExists;

  bool get previousExists => previousSnapshot?.exists == true;

  bool get newExists => newSnapshot?.exists == true;

  DocumentSnapshot previousSnapshot;
  DocumentSnapshot newSnapshot;

  bool get shouldNotify => previousExists || newExists;

  @override
  String toString() {
    return '$path added $added removed $removed old ${previousSnapshot?.exists} new ${newSnapshot?.exists}';
  }
}

class DocumentChangeBase implements DocumentChange {
  DocumentChangeBase(this.type, this.document, this.newIndex, this.oldIndex);

  @override
  DocumentChangeType type;

  @override
  final DocumentSnapshot document;

  @override
  final int newIndex;

  @override
  final int oldIndex;

  DocumentSnapshotBase get documentBase => document as DocumentSnapshotBase;
}

abstract class DocumentSnapshotBase implements DocumentSnapshot {
  final RecordMetaData meta;
  @override
  final DocumentReference ref;

  int get rev => meta?.rev;

  @override
  Timestamp get updateTime => meta?.updateTime;

  @override
  Timestamp get createTime => meta?.createTime;
  final DocumentData documentData;

  bool _exists;

  @override
  bool get exists => _exists;

  DocumentSnapshotBase(this.ref, this.meta, this.documentData, {bool exists}) {
    _exists = exists ?? (documentData != null);
  }

  @override
  Map<String, dynamic> get data => documentData?.asMap();

  @override
  String toString() {
    return 'DocumentSnapshot(ref: $ref, exists: $exists, meta $meta)';
  }
}

class QuerySnapshotBase implements QuerySnapshot {
  QuerySnapshotBase(this.docs, this.documentChanges);

  @override
  final List<DocumentSnapshot> docs;

  @override
  final List<DocumentChange> documentChanges;

  bool contains(DocumentSnapshotBase document) {
    for (var doc in docs) {
      if (doc.ref.path == document.ref.path) {
        return true;
      }
    }
    return false;
  }
}

// TODO handle sub field name
Map<String, dynamic> toSelectedMap(Map map, List<String> fields) {
  var selectedMap = <String, dynamic>{};
  for (var key in fields) {
    if (map.containsKey(key)) {
      selectedMap[key] = map[key];
    }
  }
  return selectedMap;
}
