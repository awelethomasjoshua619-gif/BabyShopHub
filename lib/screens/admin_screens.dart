import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/sequential.dart';
import '../core/app_colors.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../services/shop_api.dart';
import '../state/session.dart';
import '../widgets/common.dart';

/// Admin entry point (shown on Profile only for ROLE_ADMIN accounts).
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Key _key = UniqueKey();

  Future<void> _open(Widget page) async {
    await pushPage(context, page);
    if (mounted) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value, IconData icon, Color color) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: AppColors.slate, fontSize: 12),
                ),
              ],
            ),
          ),
        );

    Widget nav(IconData icon, String label, Widget page) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        onTap: () => _open(page),
        child: Row(
          children: [
            Icon(icon, color: AppColors.blue),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.hint),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (await confirmDialog(
                context,
                'Log out',
                'Do you want to log out?',
                confirm: 'Log out',
              )) {
                await Session.instance.logout();
              }
            },
          ),
        ],
      ),
      body: AsyncView<(List<AppUser>, List<OrderModel>, List<Product>)>(
        key: _key,
        load: () => loadInOrder3(
          () => ShopApi.adminUsers(),
          () => ShopApi.adminOrders(),
          () => ShopApi.adminProducts(),
        ),
        builder: (context, data, reload) {
          final (users, orders, products) = data;
          final pending = orders
              .where((o) => o.status == 'CONFIRMED' || o.status == 'PACKED')
              .length;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  stat(
                    'Total Users',
                    '${users.length}',
                    Icons.people_outline,
                    AppColors.blue,
                  ),
                  const SizedBox(width: 12),
                  stat(
                    'Total Orders',
                    '${orders.length}',
                    Icons.shopping_bag_outlined,
                    AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  stat(
                    'Total Products',
                    '${products.length}',
                    Icons.inventory_2_outlined,
                    AppColors.pink,
                  ),
                  const SizedBox(width: 12),
                  stat(
                    'Pending Orders',
                    '$pending',
                    Icons.pending_actions,
                    AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              nav(
                Icons.inventory_2_outlined,
                'Manage Products',
                const AdminProductsScreen(),
              ),
              nav(
                Icons.warehouse_outlined,
                'Manage Inventory',
                const AdminInventoryScreen(),
              ),
              nav(
                Icons.people_outline,
                'Manage Users',
                const AdminUsersScreen(),
              ),
              nav(
                Icons.receipt_long_outlined,
                'Manage Orders',
                const AdminOrdersScreen(),
              ),
              nav(
                Icons.support_agent,
                'Support Tickets',
                const AdminSupportScreen(),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- products

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  Key _key = UniqueKey();
  String _query = '';

  void _refresh() => setState(() => _key = UniqueKey());

  Future<void> _openForm([Product? p]) async {
    final saved = await pushPage<bool>(
      context,
      AdminProductFormScreen(product: p),
    );
    if (saved == true) _refresh();
  }

  Future<void> _addCategory() async {
    final name = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(hintText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: desc,
              decoration: const InputDecoration(hintText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      try {
        await ShopApi.createCategory(name.text.trim(), desc.text.trim());
        if (mounted) showMessage(context, 'Category created');
      } catch (e) {
        if (mounted) showMessage(context, e.toString(), error: true);
      }
    }
    name.dispose();
    desc.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Add category',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _addCategory,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search, color: AppColors.hint),
                filled: true,
                fillColor: AppColors.field,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: AsyncView<List<Product>>(
              key: _key,
              load: ShopApi.adminProducts,
              builder: (context, all, reload) {
                final list = all
                    .where(
                      (p) =>
                          p.name.toLowerCase().contains(_query) ||
                          p.brandName.toLowerCase().contains(_query),
                    )
                    .toList();
                if (list.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 80),
                      EmptyView('No products found.'),
                    ],
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return SoftCard(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          ProductImage(p.imageUrl, size: 56, iconSize: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${naira(p.price)} · ${p.brandName}',
                                  style: const TextStyle(
                                    color: AppColors.slate,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  !p.active
                                      ? 'Inactive'
                                      : (p.inStock
                                            ? 'In stock: ${p.stockQty}'
                                            : 'Out of stock'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: p.active && p.inStock
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _openForm(p),
                          ),
                          if (p.active)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.error,
                              ),
                              onPressed: () async {
                                if (!await confirmDialog(
                                  context,
                                  'Remove product',
                                  '"${p.name}" will be hidden from shoppers.',
                                  confirm: 'Remove',
                                )) {
                                  return;
                                }
                                try {
                                  await ShopApi.deactivateProduct(p.id);
                                  reload();
                                } catch (e) {
                                  if (context.mounted) {
                                    showMessage(
                                      context,
                                      e.toString(),
                                      error: true,
                                    );
                                  }
                                }
                              },
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
      ),
    );
  }
}

class AdminProductFormScreen extends StatefulWidget {
  const AdminProductFormScreen({super.key, this.product});
  final Product? product;

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _form = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _desc = TextEditingController(
    text: widget.product?.description ?? '',
  );
  late final _price = TextEditingController(
    text: widget.product == null
        ? ''
        : widget.product!.price.toStringAsFixed(0),
  );
  late final _stock = TextEditingController(
    text: widget.product?.stockQty.toString() ?? '',
  );
  late int? _categoryId = widget.product?.categoryId;
  late int? _brandId = widget.product?.brandId;
  Uint8List? _imageBytes;
  String? _imageName;
  late final Future<(List<Category>, List<Brand>)> _lookups = loadInOrder2(
    () => ShopApi.categories(),
    () => ShopApi.brands(),
  );
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _desc, _price, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = file.name;
      });
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_categoryId == null || _brandId == null) {
      showMessage(context, 'Choose a category and a brand.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final price = double.parse(_price.text.trim());
      final stock = int.parse(_stock.text.trim());
      if (widget.product == null) {
        await ShopApi.createProduct(
          name: _name.text.trim(),
          description: _desc.text.trim(),
          price: price,
          stock: stock,
          categoryId: _categoryId!,
          brandId: _brandId!,
          imageBytes: _imageBytes,
          imageName: _imageName,
        );
      } else {
        await ShopApi.updateProduct(
          widget.product!.id,
          name: _name.text.trim(),
          description: _desc.text.trim(),
          price: price,
          stock: stock,
          categoryId: _categoryId!,
          brandId: _brandId!,
        );
        if (_imageBytes != null) {
          await ShopApi.replaceProductImage(
            widget.product!.id,
            _imageBytes!,
            _imageName ?? 'product-image.jpg',
          );
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Product' : 'Add Product')),
      body: FutureBuilder<(List<Category>, List<Brand>)>(
        future: _lookups,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.blue),
            );
          }
          if (snap.hasError) {
            return ErrorView(
              snap.error.toString(),
              onRetry: () => Navigator.pop(context),
            );
          }
          final (categories, brands) = snap.data!;
          return Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _imageBytes == null
                            ? ProductImage(
                                widget.product?.imageUrl,
                                size: 144,
                                iconSize: 42,
                              )
                            : Image.memory(
                                _imageBytes!,
                                width: 144,
                                height: 144,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          _imageBytes != null ||
                                  (widget.product?.imageUrl?.isNotEmpty ??
                                      false)
                              ? 'Change product image'
                              : 'Add product image',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  decoration: fieldDecoration('Product name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a name.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _desc,
                  maxLines: 3,
                  decoration: fieldDecoration('Description'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: fieldDecoration('Price (₦)'),
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    return n == null || n < 0 ? 'Enter a valid price.' : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  decoration: fieldDecoration('Stock quantity'),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    return n == null || n < 0 ? 'Enter a whole number.' : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: categories.any((c) => c.id == _categoryId)
                      ? _categoryId
                      : null,
                  decoration: fieldDecoration('Category'),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: brands.any((b) => b.id == _brandId)
                      ? _brandId
                      : null,
                  decoration: fieldDecoration('Brand'),
                  items: [
                    for (final b in brands)
                      DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ],
                  onChanged: (v) => setState(() => _brandId = v),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: editing ? 'Save Changes' : 'Create Product',
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --------------------------------------------------------------- inventory

class AdminInventoryScreen extends StatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  State<AdminInventoryScreen> createState() => _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends State<AdminInventoryScreen> {
  int _filter = 0;

  static const _filters = ['All', 'Low Stock', 'Out of Stock'];

  bool _match(Product p) => switch (_filter) {
    1 => p.active && p.stockQty > 0 && p.stockQty <= 10,
    2 => p.active && p.stockQty == 0,
    _ => true,
  };

  Future<void> _adjust(Product p, VoidCallback reload) async {
    final controller = TextEditingController(text: '${p.stockQty}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p.name),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: fieldDecoration('Stock quantity'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final qty = int.tryParse(controller.text.trim());
    controller.dispose();
    if (ok != true || qty == null || qty < 0) return;
    try {
      await ShopApi.updateStock(p.id, qty);
      if (mounted) showMessage(context, '${p.name}: stock set to $qty');
      reload();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Column(
        children: [
          ChipRow(
            labels: _filters,
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AsyncView<List<Product>>(
              load: ShopApi.adminProducts,
              builder: (context, all, reload) {
                final list = all.where(_match).toList();
                if (list.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 80),
                      EmptyView('No products here.'),
                    ],
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return SoftCard(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          ProductImage(p.imageUrl, size: 56, iconSize: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${naira(p.price)} · ${p.brandName}',
                                  style: const TextStyle(
                                    color: AppColors.slate,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  !p.active
                                      ? 'Inactive'
                                      : (p.inStock
                                            ? 'In stock: ${p.stockQty}'
                                            : 'Out of stock'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: p.active && p.inStock
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _adjust(p, reload),
                            child: const Text('Adjust'),
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
      ),
    );
  }
}

// ------------------------------------------------------------------- users

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _query = '';

  /// Read-only detail sheet for one user, plus the suspend/restore action.
  Future<void> _details(AppUser u, VoidCallback reload) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.blueTint,
                  child: Text(
                    u.name.isEmpty ? '?' : u.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.blue,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.name,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        u.isAdmin ? 'Administrator' : 'Customer',
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  u.suspended ? 'CANCELLED' : 'DELIVERED',
                  label: u.suspended ? 'Suspended' : 'Active',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _detailRow(Icons.mail_outline, 'Email', u.email),
            _detailRow(
              Icons.phone_outlined,
              'Phone',
              (u.phoneNumber ?? '').isEmpty ? 'Not provided' : u.phoneNumber!,
            ),
            _detailRow(
              Icons.verified_user_outlined,
              'Account',
              u.enabled ? 'Email verified' : 'Not verified',
            ),
            _detailRow(
              Icons.admin_panel_settings_outlined,
              'Role',
              u.roles.isEmpty ? 'None' : u.roles.join(', '),
            ),
            const SizedBox(height: 8),
            if (!u.isAdmin) ...[
              const SizedBox(height: 6),
              if (u.suspended)
                PrimaryButton(
                  label: 'Restore Account',
                  onPressed: () async {
                    final navigator = Navigator.of(sheetContext);
                    try {
                      await ShopApi.setSuspended(u.id, false);
                      navigator.pop(true);
                    } catch (e) {
                      if (mounted) {
                        showMessage(context, e.toString(), error: true);
                      }
                    }
                  },
                )
              else
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: () async {
                    final navigator = Navigator.of(sheetContext);
                    try {
                      await ShopApi.setSuspended(u.id, true);
                      navigator.pop(true);
                    } catch (e) {
                      if (mounted) {
                        showMessage(context, e.toString(), error: true);
                      }
                    }
                  },
                  child: const Text('Suspend Account'),
                ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Administrators cannot be suspended.',
                  style: TextStyle(color: AppColors.hint, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
    if (changed == true) reload();
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.blue),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.slate, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search, color: AppColors.hint),
                filled: true,
                fillColor: AppColors.field,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: AsyncView<List<AppUser>>(
              load: ShopApi.adminUsers,
              builder: (context, all, reload) {
                final list = all
                    .where(
                      (u) =>
                          u.name.toLowerCase().contains(_query) ||
                          u.email.toLowerCase().contains(_query),
                    )
                    .toList();
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final u = list[i];
                    return SoftCard(
                      onTap: () => _details(u, reload),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.blueTint,
                            child: Text(
                              u.name.isEmpty ? '?' : u.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.blue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.name,
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  u.email,
                                  style: const TextStyle(
                                    color: AppColors.slate,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${u.isAdmin ? 'Admin' : 'Customer'}'
                                  '${u.enabled ? '' : ' · Not verified'}'
                                  '${u.suspended ? ' · Suspended' : ''}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: u.suspended
                                        ? AppColors.error
                                        : AppColors.hint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!u.isAdmin)
                            TextButton(
                              onPressed: () async {
                                try {
                                  await ShopApi.setSuspended(
                                    u.id,
                                    !u.suspended,
                                  );
                                  reload();
                                } catch (e) {
                                  if (context.mounted) {
                                    showMessage(
                                      context,
                                      e.toString(),
                                      error: true,
                                    );
                                  }
                                }
                              },
                              child: Text(
                                u.suspended ? 'Restore' : 'Suspend',
                                style: TextStyle(
                                  color: u.suspended
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
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
      ),
    );
  }
}

// ------------------------------------------------------------------ orders

const _orderFlow = ['CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED'];
const _orderFilters = [
  'All',
  'Processing',
  'Shipped',
  'Delivered',
  'Cancelled',
];

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  int _filter = 0;

  bool _match(String status) => switch (_orderFilters[_filter]) {
    'Processing' => status == 'CONFIRMED' || status == 'PACKED',
    'Shipped' => status == 'SHIPPED',
    'Delivered' => status == 'DELIVERED',
    'Cancelled' => status == 'CANCELLED',
    _ => true,
  };

  Future<void> _change(OrderModel o, String status, VoidCallback reload) async {
    try {
      await ShopApi.setOrderStatus(o.id, status);
      if (mounted) {
        Navigator.pop(context);
        showMessage(
          context,
          'Order ${orderNumber(o.id)} is now ${statusLabel(status)}',
        );
      }
      reload();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  void _details(OrderModel o, VoidCallback reload) {
    final index = _orderFlow.indexOf(o.status);
    final next = index >= 0 && index < _orderFlow.length - 1
        ? _orderFlow[index + 1]
        : null;
    final canCancel = o.status == 'CONFIRMED' || o.status == 'PACKED';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order ${orderNumber(o.id)}',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusChip(o.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${formatDateTime(o.createdAt)} · ${naira(o.total)}',
              style: const TextStyle(color: AppColors.slate),
            ),
            const SizedBox(height: 10),
            for (final l in o.items)
              Text(
                '${l.quantity} × ${l.name}',
                style: const TextStyle(color: AppColors.ink),
              ),
            const SizedBox(height: 10),
            Text(
              'Ship to: ${o.shippingAddress}',
              style: const TextStyle(color: AppColors.slate, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (next != null)
              PrimaryButton(
                label: 'Mark as ${statusLabel(next)}',
                onPressed: () => _change(o, next, reload),
              ),
            if (canCancel) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                onPressed: () => _change(o, 'CANCELLED', reload),
                child: const Text('Cancel order'),
              ),
            ],
            if (next == null && !canCancel)
              const Text(
                'No further actions for this order.',
                style: TextStyle(color: AppColors.hint),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        children: [
          ChipRow(
            labels: _orderFilters,
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AsyncView<List<OrderModel>>(
              load: ShopApi.adminOrders,
              builder: (context, all, reload) {
                final list = all.where((o) => _match(o.status)).toList();
                if (list.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 80),
                      EmptyView('No orders here.'),
                    ],
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final o = list[i];
                    return SoftCard(
                      onTap: () => _details(o, reload),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  orderNumber(o.id),
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${formatDate(o.createdAt)} · ${o.itemCount} items',
                                  style: const TextStyle(
                                    color: AppColors.slate,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                naira(o.total),
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
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
      ),
    );
  }
}

// ----------------------------------------------------------------- support

class AdminSupportScreen extends StatelessWidget {
  const AdminSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support Tickets')),
      body: AsyncView<List<Ticket>>(
        load: ShopApi.adminTickets,
        builder: (context, tickets, reload) {
          if (tickets.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                EmptyView('No support tickets.'),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: tickets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final t = tickets[i];
              return SoftCard(
                onTap: () async {
                  final changed = await showDialog<bool>(
                    context: context,
                    builder: (_) => _TicketDialog(ticket: t),
                  );
                  if (changed == true) reload();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.subject,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        StatusChip(t.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.email,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.ink),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TicketDialog extends StatefulWidget {
  const _TicketDialog({required this.ticket});
  final Ticket ticket;

  @override
  State<_TicketDialog> createState() => _TicketDialogState();
}

class _TicketDialogState extends State<_TicketDialog> {
  late final _reply = TextEditingController(
    text: widget.ticket.adminResponse ?? '',
  );
  late String _status = widget.ticket.status;
  bool _saving = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ShopApi.setTicketStatus(
        widget.ticket.id,
        _status,
        _reply.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.ticket.subject),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ticket.message),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: fieldDecoration('Status'),
              items: const [
                DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                DropdownMenuItem(
                  value: 'IN_PROGRESS',
                  child: Text('In progress'),
                ),
                DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reply,
              maxLines: 3,
              decoration: fieldDecoration('Reply to the customer'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
