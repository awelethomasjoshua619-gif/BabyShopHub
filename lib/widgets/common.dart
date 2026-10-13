import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/api_config.dart';
import '../core/app_colors.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../state/session.dart';

// ---------- helpers ----------

void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : AppColors.navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

Future<T?> pushPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

Future<bool> confirmDialog(
  BuildContext context,
  String title,
  String body, {
  String confirm = 'Yes',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Adds to cart and shows a message. Returns true on success.
Future<bool> addToCartWithFeedback(
  BuildContext context,
  Product p, [
  int qty = 1,
]) async {
  try {
    await CartStore.instance.add(p.id, qty);
    if (context.mounted) showMessage(context, '${p.name} added to cart');
    return true;
  } catch (e) {
    if (context.mounted) showMessage(context, e.toString(), error: true);
    return false;
  }
}

IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('carrier') || n.contains('gear') || n.contains('stroll')) return Icons.airline_seat_recline_normal_rounded;
  if (n.contains('plate') || n.contains('tableware') || n.contains('dish')) return Icons.dinner_dining_outlined;
  if (n.contains('cloth')) return Icons.checkroom_outlined;
  if (n.contains('bottle') || n.contains('feed')) return Icons.baby_changing_station;
  if (n.contains('food')) return Icons.rice_bowl_outlined;
  if (n.contains('diaper')) return Icons.child_care_outlined;
  if (n.contains('toy')) return Icons.toys_outlined;
  if (n.contains('skin')) return Icons.spa_outlined;
  if (n.contains('access')) return Icons.watch_outlined;
  return Icons.category_outlined;
}

Color statusColor(String status) => switch (status.toUpperCase()) {
  'DELIVERED' || 'CLOSED' || 'PAID' => AppColors.success,
  'SHIPPED' || 'IN_PROGRESS' => AppColors.blue,
  'PACKED' => AppColors.warning,
  'CANCELLED' => AppColors.error,
  _ => AppColors.pink, // CONFIRMED, OPEN
};

String statusLabel(String status) => switch (status.toUpperCase()) {
  'CONFIRMED' => 'Processing',
  'IN_PROGRESS' => 'In progress',
  final s => s[0] + s.substring(1).toLowerCase(),
};

// ---------- small widgets ----------

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label ?? statusLabel(status),
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.pink = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool pink;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = pink
        ? const [AppColors.pinkLight, AppColors.pink]
        : const [AppColors.blueLight, AppColors.blue];
    final disabled = onPressed == null || loading;
    return Opacity(
      opacity: disabled && !loading ? 0.5 : 1,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: BorderRadius.circular(28),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.onTap, this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: padding ?? const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.blueTint, width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                color: AppColors.blue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    ),
  );
}

class ProductImage extends StatelessWidget {
  const ProductImage(this.url, {super.key, this.size, this.iconSize = 40});
  final String? url;
  final double? size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Icon(Icons.child_care, size: iconSize, color: AppColors.blue),
    );
    Widget child = fallback;
    if (url != null && url!.isNotEmpty) {
      if (url!.startsWith('data:image/')) {
        final separator = url!.indexOf(',');
        if (separator > 0) {
          try {
            child = Image.memory(
              base64Decode(url!.substring(separator + 1)),
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, _, _) => fallback,
            );
          } catch (_) {}
        }
      } else {
        child = Image.network(
          resolveImageUrl(url!),
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, _, _) => fallback,
        );
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.blueTint,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAdd,
  });
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: ProductImage(product.imageUrl),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  product.inStock ? naira(product.price) : 'Out of stock',
                  style: TextStyle(
                    color: product.inStock ? AppColors.navy : AppColors.hint,
                    fontSize: product.inStock ? 15 : 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Material(
                color: product.inStock ? AppColors.blue : AppColors.field,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: product.inStock ? onAdd : null,
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.max = 99,
  });
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, VoidCallback? f) => InkWell(
      onTap: f,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          i,
          size: 18,
          color: f == null ? AppColors.border : AppColors.navy,
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove, value > 1 ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 28,
            child: Center(
              child: Text(
                '$value',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          btn(Icons.add, value < max ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }
}

class StarRating extends StatelessWidget {
  const StarRating(this.rating, {super.key, this.size = 16});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      5,
      (i) => Icon(
        rating >= i + 1
            ? Icons.star_rounded
            : (rating > i
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded),
        size: size,
        color: AppColors.warning,
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView(this.text, {super.key, this.icon = Icons.inbox_outlined});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: AppColors.border),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate),
          ),
        ],
      ),
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.message, {super.key, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppColors.hint),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: PrimaryButton(label: 'Try again', onPressed: onRetry),
          ),
        ],
      ),
    ),
  );
}

/// Loads data, shows spinner / error+retry / content. Pull down to refresh.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload)
  builder;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() {
    _future = widget.load();
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.blue),
          );
        }
        if (snap.hasError) {
          return ErrorView(snap.error.toString(), onRetry: _reload);
        }
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            try {
              await _future;
            } catch (_) {}
          },
          child: widget.builder(context, snap.data as T, _reload),
        );
      },
    );
  }
}

/// Filter chip row used on product, order and admin lists.
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: labels.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final on = i == selected;
        return GestureDetector(
          onTap: () => onSelected(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.blue : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: on ? AppColors.blue : AppColors.border),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                color: on ? Colors.white : AppColors.navy,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        );
      },
    ),
  );
}

InputDecoration fieldDecoration(
  String hint, {
  IconData? icon,
  Widget? suffix,
}) => InputDecoration(
  hintText: hint,
  prefixIcon: icon == null ? null : Icon(icon, size: 20, color: AppColors.hint),
  suffixIcon: suffix,
);
