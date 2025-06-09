import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:iron/src/core/iron_events_effects.dart';
import 'package:iron/src/core/iron_interceptor.dart';
import 'package:iron/src/di/iron_locator.dart';
import 'package:iron/src/persistence/adapters/adapter.dart';

/// A persistence adapter that saves and loads data to/from a local file.
/// This adapter uses the file system to store data in JSON format.
/// It implements the PersistenceAdapter interface and provides methods to load, save, and clear data.
/// It also notifies the InterceptorRegistry about load, save, and clear attempts and successes.
/// Errors during these operations are logged and notified to the InterceptorRegistry.
/// The file is specified by the `fileName` parameter, which should be a valid file path.
/// This adapter is useful for applications that need to persist data locally on the device.
/// It can be used for caching, settings storage, or any other local data persistence needs.
/// The adapter is designed to be used with the Iron architecture, allowing for easy integration with other components.
class LocalFileAdapter<T> extends PersistenceAdapter<T> {
  final String fileName;
  LocalFileAdapter({required this.fileName});

  Future<File> _getFile() async => File(fileName);

  InterceptorRegistry get _registry => IronLocator.instance.find<InterceptorRegistry>();

  @override
  Future<Map<String, dynamic>?> load() async {
    _registry.notifyEffect(
      runtimeType,
      PersistenceLoadAttemptEffect(adapterName: runtimeType.toString(), operationKey: fileName),
    );
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isNotEmpty) {
          final data = jsonDecode(contents) as Map<String, dynamic>;
          _registry.notifyEffect(
            runtimeType,
            PersistenceLoadSuccessEffect(adapterName: runtimeType.toString(), operationKey: fileName, data: data),
          );
          return data;
        }
      }
      _registry.notifyEffect(
        runtimeType,
        PersistenceLoadSuccessEffect(adapterName: runtimeType.toString(), operationKey: fileName, data: null),
      );
    } catch (e, s) {
      debugPrint('LocalFileAdapter: Load error for $fileName: $e');
      _registry.notifyError(this, e, s);
    }
    return null;
  }

  @override
  Future<void> save(Map<String, dynamic> json) async {
    _registry.notifyEffect(
      runtimeType,
      PersistenceSaveAttemptEffect(adapterName: runtimeType.toString(), operationKey: fileName, data: json),
    );
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode(json));
      _registry.notifyEffect(
        runtimeType,
        PersistenceSaveSuccessEffect(adapterName: runtimeType.toString(), operationKey: fileName),
      );
    } catch (e, s) {
      debugPrint('LocalFileAdapter: Save error for $fileName: $e');
      _registry.notifyError(this, e, s);
    }
  }

  @override
  Future<void> clear() async {
    _registry.notifyEffect(
      runtimeType,
      PersistenceClearAttemptEffect(adapterName: runtimeType.toString(), operationKey: fileName),
    );
    try {
      final file = await _getFile();
      if (await file.exists()) await file.delete();
      _registry.notifyEffect(
        runtimeType,
        PersistenceClearSuccessEffect(adapterName: runtimeType.toString(), operationKey: fileName),
      );
    } catch (e, s) {
      debugPrint('LocalFileAdapter: Clear error for $fileName: $e');
      _registry.notifyError(this, e, s);
    }
  }
}
