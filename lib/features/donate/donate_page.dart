import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/layout/breakpoints.dart';

/// Sản phẩm consumable khai báo trong Play Console (Monetize › In-app products).
const donateProducts = <String, (String, FaIconData)>{
  'donate_coffee': ('Một ly cà phê', FontAwesomeIcons.mugHot),
  'donate_meal': ('Một bữa ăn', FontAwesomeIcons.bowlFood),
  'donate_big': ('Ủng hộ lớn', FontAwesomeIcons.heart),
};

/// Ủng hộ nhà phát triển qua Google Play Billing. Không mở khóa tính năng nào.
class DonatePage extends StatefulWidget {
  const DonatePage({super.key});

  @override
  State<DonatePage> createState() => _DonatePageState();
}

enum _Status { loading, ready, unavailable }

class _DonatePageState extends State<DonatePage> {
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  _Status _status = _Status.loading;
  List<ProductDetails> _products = const [];
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (_) {
          if (mounted) setState(() => _buying = false);
        },
      );
      if (!await _iap.isAvailable()) {
        if (mounted) setState(() => _status = _Status.unavailable);
        return;
      }
      final res = await _iap.queryProductDetails(donateProducts.keys.toSet());
      final list = [...res.productDetails]
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      if (!mounted) return;
      setState(() {
        _products = list;
        _status = list.isEmpty ? _Status.unavailable : _Status.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _status = _Status.unavailable);
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
      if (!mounted) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
          setState(() => _buying = false);
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const FaIcon(
                FontAwesomeIcons.heart,
                color: Colors.redAccent,
              ),
              title: const Text('Cảm ơn bạn rất nhiều!'),
              content: const Text(
                'Sự ủng hộ của bạn giúp app tiếp tục được cập nhật và miễn phí cho mọi người.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          );
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          setState(() => _buying = false);
        case PurchaseStatus.pending:
        case PurchaseStatus.restored:
          break;
      }
    }
  }

  Future<void> _buy(ProductDetails p) async {
    setState(() => _buying = true);
    try {
      await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: p));
    } catch (_) {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ủng hộ nhà phát triển')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          MaxWidth(
            width: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FaIcon(
                  FontAwesomeIcons.mugHot,
                  size: 48,
                  color: t.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Thích app này?',
                  textAlign: TextAlign.center,
                  style: t.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'App miễn phí, không quảng cáo, không thu thập dữ liệu. '
                  'Nếu thấy hữu ích, bạn có thể mời nhà phát triển một ly cà phê ☕',
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                switch (_status) {
                  _Status.loading => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  _Status.unavailable => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.circleInfo,
                            size: 18,
                            color: t.colorScheme.outline,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Chưa kết nối được Google Play. Hãy kiểm tra mạng và thử lại sau.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _Status.ready => Column(
                    children: [
                      for (final p in _products)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: FaIcon(
                                donateProducts[p.id]?.$2 ??
                                    FontAwesomeIcons.heart,
                                color: t.colorScheme.primary,
                              ),
                              title: Text(donateProducts[p.id]?.$1 ?? p.title),
                              trailing: FilledButton(
                                onPressed: _buying ? null : () => _buy(p),
                                child: Text(p.price),
                              ),
                              onTap: _buying ? null : () => _buy(p),
                            ),
                          ),
                        ),
                    ],
                  ),
                },
                const SizedBox(height: 8),
                Text(
                  'Thanh toán qua Google Play. Ủng hộ không mở khóa thêm tính năng — '
                  'mọi tính năng đều miễn phí.',
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
