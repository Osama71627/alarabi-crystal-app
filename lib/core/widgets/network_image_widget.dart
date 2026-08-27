import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// ويدجت صورة شبكة مع Cache وحالة تحميل
class NetworkImageWidget extends StatelessWidget {
  const NetworkImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderIcon = Icons.image_outlined,
    this.width,
    this.height,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? borderRadius;
  final IconData placeholderIcon;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final Widget child = imageUrl.isEmpty
        ? _buildPlaceholder(context)
        : CachedNetworkImage(
            imageUrl: imageUrl,
            fit: fit,
            width: width,
            height: height,
            placeholder: (context, url) => _buildPlaceholder(context),
            errorWidget: (context, url, error) => _buildPlaceholder(context),
          );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius!),
        child: child,
      );
    }
    return child;
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        placeholderIcon,
        size: 40,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
