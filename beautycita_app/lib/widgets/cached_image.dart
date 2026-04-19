/// A drop-in replacement for [Image.network] that disk-caches the image
/// via `cached_network_image`. The API mirrors [Image.network]'s most-used
/// parameters so call sites can swap one for one (`Image.network(url, ...)`
/// → `CachedImage(url, ...)`) without tearing apart surrounding layout.
///
/// Why: before 2026-04-19 the app used [Image.network] in 29 places and
/// `CachedNetworkImage` in 1. Every avatar, salon photo, and portfolio
/// shot was re-fetched from the network on every rebuild and evicted from
/// memory when the app backgrounded, which is why Android reported 0B of
/// stored data for the app. Standardising on this wrapper moves the work
/// to disk, so repeat visits to a salon / staff list / feed item are
/// instant and offline-tolerant.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CachedImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Alignment alignment;
  final Color? color;
  final BlendMode? colorBlendMode;
  final FilterQuality filterQuality;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;
  final Map<String, String>? httpHeaders;

  const CachedImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.color,
    this.colorBlendMode,
    this.filterQuality = FilterQuality.low,
    this.errorBuilder,
    this.loadingBuilder,
    this.httpHeaders,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      color: color,
      colorBlendMode: colorBlendMode,
      filterQuality: filterQuality,
      httpHeaders: httpHeaders,
      errorWidget: errorBuilder == null
          ? null
          : (ctx, _, err) => errorBuilder!(ctx, err, null),
      progressIndicatorBuilder: loadingBuilder == null
          ? null
          : (ctx, _, progress) {
              ImageChunkEvent? event;
              if (progress.downloaded > 0) {
                event = ImageChunkEvent(
                  cumulativeBytesLoaded: progress.downloaded,
                  expectedTotalBytes: progress.totalSize,
                );
              }
              return loadingBuilder!(ctx, const SizedBox.shrink(), event);
            },
    );
  }
}
