import 'package:flutter/foundation.dart';
import 'package:iron/src/persistence/adapters/adapter.dart';

/// Base class for IronEffect, which represents side effects in the Iron architecture.
/// This class is used to encapsulate effects that can be triggered by events or state changes.
/// It is designed to be extended by specific effect implementations.
/// It includes an optional `origin` field to indicate the source of the effect.
/// The `toJson` method provides a way to serialize the effect for logging or debugging purposes.
@immutable
abstract class IronEffect {
  final Type? origin;
  const IronEffect({this.origin});

  Map<String, dynamic> toJson() {
    return {'type': runtimeType.toString(), 'origin': origin?.toString()};
  }
}

/// Base class for persistence effects, which are specific types of IronEffect
/// related to data persistence operations such as loading, saving, and clearing data.
/// It includes an `adapterName` to identify the persistence adapter being used,
/// and an optional `operationKey` to specify the operation being performed.
/// The `toString` method provides a string representation of the effect, including the adapter name and operation key.
abstract class PersistenceEffect extends IronEffect {
  final String adapterName;
  final String? operationKey;
  const PersistenceEffect({required this.adapterName, this.operationKey, super.origin});

  @override
  String toString() {
    return '$runtimeType(adapterName: $adapterName, operationKey: $operationKey${_additionalToString()})';
  }

  String _additionalToString() => '';
}

class PersistenceLoadAttemptEffect extends PersistenceEffect {
  const PersistenceLoadAttemptEffect({required super.adapterName, super.operationKey})
    : super(origin: PersistenceAdapter);
}

class PersistenceLoadSuccessEffect extends PersistenceEffect {
  final dynamic data;
  const PersistenceLoadSuccessEffect({required super.adapterName, super.operationKey, this.data})
    : super(origin: PersistenceAdapter);

  @override
  String _additionalToString() => ', data: $data';
}

class PersistenceSaveAttemptEffect extends PersistenceEffect {
  final dynamic data;
  const PersistenceSaveAttemptEffect({required super.adapterName, super.operationKey, this.data})
    : super(origin: PersistenceAdapter);

  @override
  String _additionalToString() => ', data: $data';
}

class PersistenceSaveSuccessEffect extends PersistenceEffect {
  const PersistenceSaveSuccessEffect({required super.adapterName, super.operationKey})
    : super(origin: PersistenceAdapter);
}

class PersistenceClearAttemptEffect extends PersistenceEffect {
  const PersistenceClearAttemptEffect({required super.adapterName, super.operationKey})
    : super(origin: PersistenceAdapter);
}

class PersistenceClearSuccessEffect extends PersistenceEffect {
  const PersistenceClearSuccessEffect({required super.adapterName, super.operationKey})
    : super(origin: PersistenceAdapter);
}
