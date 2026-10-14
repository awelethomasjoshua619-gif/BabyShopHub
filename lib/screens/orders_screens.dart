import 'dart:async';

import 'package:flutter/material.dart';

import '../core/sequential.dart';
import '../core/app_colors.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../services/shop_api.dart';
import '../widgets/common.dart';
import 'product_detail_screen.dart';

const _filters = ['All', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];

bool _matches(String filter, String status) => switch (filter) {
      'Processing' => status == 'CONFIRMED' || status == 'PACKED',
      'Shipped' => status == 'SHIPPED',
      'Delivered' => status == 'DELIVERED',
      'Cancelled' => status == 'CANCELLED',
      _ => true,
    };

/// Orders tab: order history with status filter.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('My Orders',
              style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
        ),
        ChipRow(
            labels: _filters,
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i)),
        const SizedBox(height: 10),
        Expanded(
          child: AsyncView<List<OrderModel>>(
            load: ShopApi.myOrders,
            builder: (context, orders, reload) {
              final shown = orders
                  .where((o) => _matches(_filters[_filter], o.status))
                  .toList();
              if (shown.isEmpty) {
                return ListView(children: const [
                  SizedBox(height: 80),
                  EmptyView('No orders here yet.',
                      icon: Icons.receipt_long_outlined),
                ]);
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final o = shown[i];
                  return SoftCard(
                    onTap: () async {
                      await pushPage(context, OrderDetailScreen(orderId: o.id));
                      reload();
                    },
                    child: Row(
                      children: [
                        const ProductImage(null, size: 56, iconSize: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(orderNumber(o.id),
                                  style: const TextStyle(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                  '${formatDate(o.createdAt)} · ${o.itemCount} item${o.itemCount == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      color: AppColors.slate, fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(naira(o.total),
                                style: const TextStyle(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            StatusChip(o.status),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Order details + live tracking (refreshes itself every 15 seconds).
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderModel? _order;
  List<TrackingEvent> _events = [];
  String? _error;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final result = await loadInOrder2(
        () => ShopApi.order(widget.orderId),
        () => ShopApi.tracking(widget.orderId),
      );
      if (!mounted) return;
      setState(() {
        _order = result.$1;
        _events = result.$2;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Scaffold(
      appBar: AppBar(title: const Text('Track Order'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      body: _loading && o == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : o == null
              ? ErrorView(_error ?? 'Could not load this order.', onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Order ${orderNumber(o.id)}',
                                style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                          ),
                          StatusChip(o.status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Placed on ${formatDate(o.createdAt)}',
                          style: const TextStyle(color: AppColors.slate)),
                      const SizedBox(height: 18),
                      _progress(o.status),
                      const SectionTitle('Tracking History'),
                      if (_events.isEmpty)
                        const Text('No updates yet.',
                            style: TextStyle(color: AppColors.slate))
                      else
                        for (final e in _events.reversed) _event(e),
                      const SectionTitle('Items'),
                      SoftCard(
                        child: Column(
                          children: [
                            for (final l in o.items)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: InkWell(
                                  onTap: () => pushPage(context,
                                      ProductDetailScreen(productId: l.productId)),
                                  child: Row(
                                    children: [
                                      Expanded(
                                          child: Text('${l.quantity} × ${l.name}',
                                              style: const TextStyle(
                                                  color: AppColors.ink))),
                                      Text(naira(l.subtotal),
                                          style: const TextStyle(
                                              color: AppColors.navy,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            const Divider(),
                            Row(
                              children: [
                                const Text('Total',
                                    style: TextStyle(
                                        color: AppColors.navy,
                                        fontWeight: FontWeight.w800)),
                                const Spacer(),
                                Text(naira(o.total),
                                    style: const TextStyle(
                                        color: AppColors.navy,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SectionTitle('Delivery & Payment'),
                      SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.shippingAddress,
                                style: const TextStyle(color: AppColors.ink)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Payment: ',
                                    style: TextStyle(color: AppColors.slate)),
                                StatusChip(o.paymentStatus.isEmpty
                                    ? 'PAID'
                                    : o.paymentStatus),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _progress(String status) {
    if (status == 'CANCELLED') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14)),
        child: const Row(children: [
          Icon(Icons.cancel_outlined, color: AppColors.error),
          SizedBox(width: 10),
          Text('This order was cancelled.',
              style: TextStyle(color: AppColors.error)),
        ]),
      );
    }
    const steps = ['CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED'];
    const labels = ['Processing', 'Packed', 'Shipped', 'Delivered'];
    final current = steps.indexOf(status);
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current ? AppColors.blue : AppColors.field,
                ),
                child: Icon(i <= current ? Icons.check : Icons.circle,
                    size: i <= current ? 16 : 8,
                    color: i <= current ? Colors.white : AppColors.border),
              ),
              const SizedBox(height: 4),
              Text(labels[i],
                  style: TextStyle(
                      fontSize: 10,
                      color: i <= current ? AppColors.navy : AppColors.hint,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          if (i < steps.length - 1)
            Expanded(
                child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    color: i < current ? AppColors.blue : AppColors.border)),
        ],
      ],
    );
  }

  Widget _event(TrackingEvent e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 20, color: statusColor(e.status)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(statusLabel(e.status),
                      style: const TextStyle(
                          color: AppColors.navy, fontWeight: FontWeight.w700)),
                  if ((e.note ?? '').isNotEmpty)
                    Text(e.note!,
                        style: const TextStyle(
                            color: AppColors.slate, fontSize: 12)),
                  Text(formatDateTime(e.createdAt),
                      style:
                          const TextStyle(color: AppColors.hint, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
}