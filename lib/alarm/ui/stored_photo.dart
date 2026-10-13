import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../challenges/core/camera.dart';

/// A photo from the photo store; a placeholder icon when it cannot be shown.
class StoredPhoto extends ConsumerStatefulWidget {
  const StoredPhoto(this.path, {super.key, this.fit = BoxFit.contain});

  final String path;
  final BoxFit fit;

  @override
  ConsumerState<StoredPhoto> createState() => _StoredPhotoState();
}

class _StoredPhotoState extends ConsumerState<StoredPhoto> {
  late Future<Uint8List?> _bytes = ref
      .read(photoStoreProvider)
      .load(widget.path);

  @override
  void didUpdateWidget(StoredPhoto old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _bytes = ref.read(photoStoreProvider).load(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    const placeholder = Center(child: Icon(Icons.image_outlined, size: 48));
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) return placeholder;
        return Image.memory(
          bytes,
          fit: widget.fit,
          errorBuilder: (_, _, _) => placeholder,
        );
      },
    );
  }
}
