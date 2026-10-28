import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/restaurants/restaurant.dart';

/// Full-screen swipeable gallery, pinch to zoom.
class PhotoViewerPage extends StatefulWidget {
  final List<RestaurantPhoto> photos;
  final int initialIndex;

  const PhotoViewerPage({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  static Future<void> open(
    BuildContext context,
    List<RestaurantPhoto> photos,
    int index,
  ) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PhotoViewerPage(photos: photos, initialIndex: index),
    ));
  }

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: widget.photos.length > 1
            ? Text('${_index + 1} / ${widget.photos.length}',
                style: TextStyle(fontSize: 46.sp))
            : null,
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.photos[i].url,
              fit: BoxFit.contain,
              placeholder: (_, __) =>
                  const CircularProgressIndicator(color: Colors.white),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.broken_image, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}
