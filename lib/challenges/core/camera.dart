import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../photo_match/similarity.dart';
import 'types.dart';

/// The back camera, behind an interface so tests use canned photos.
abstract class PhotoCamera {
  Future<void> init();
  Widget preview();
  Future<Uint8List> capture();
  Future<void> dispose();
}

class PluginPhotoCamera implements PhotoCamera {
  CameraController? _controller;

  @override
  Future<void> init() async {
    final cameras = await availableCameras();
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      back,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller.initialize();
    _controller = controller;
  }

  @override
  Widget preview() {
    final c = _controller;
    return c == null ? const SizedBox.shrink() : CameraPreview(c);
  }

  @override
  Future<Uint8List> capture() async =>
      (await _controller!.takePicture()).readAsBytes();

  @override
  Future<void> dispose() async => _controller?.dispose();
}

/// Factory, so each screen gets its own camera session.
final photoCameraProvider = Provider<PhotoCamera Function()>(
  (_) => PluginPhotoCamera.new,
);

/// Reference photos, kept in the app's private documents folder.
abstract class PhotoStore {
  Future<String> save(Uint8List bytes);
  Future<Uint8List?> load(String path);
}

class FilePhotoStore implements PhotoStore {
  @override
  Future<String> save(Uint8List bytes) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/photos');
    await dir.create(recursive: true);
    final file = File(
      '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }

  @override
  Future<Uint8List?> load(String path) async {
    final f = File(path);
    return await f.exists() ? f.readAsBytes() : null;
  }
}

final photoStoreProvider = Provider<PhotoStore>((_) => FilePhotoStore());

typedef PhotoScorer = Future<double> Function(Uint8List a, Uint8List b);

/// Similarity off the UI thread (decoding a photo takes a while).
final photoScorerProvider = Provider<PhotoScorer>(
  (_) =>
      (a, b) => compute(_score, (a, b)),
);

double _score((Uint8List, Uint8List) pair) => photoSimilarity(pair.$1, pair.$2);

/// Capability probe: {camera} when the phone has one.
Future<Set<SensorKind>> cameraCapability() async =>
    (await availableCameras()).isNotEmpty ? {SensorKind.camera} : {};
