import 'package:flutter/material.dart';
import '../../../data/models/product_model.dart';
import 'product_card.dart';
import 'equal_height_row.dart';

class ProductGrid extends StatelessWidget {
  final List<ProductModel> products;
  final Function(ProductModel) onProductTap;

  const ProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Товарлар табылган жок',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    int columns;
    if (width > 1200) {
      columns = 5;
    } else if (width > 900) {
      columns = 4;
    } else if (width > 600) {
      columns = 3;
    } else {
      columns = 2;
    }

    const spacing = 12.0;
    const hPad = 12.0;

    // ── Катардын бийиктиги = ошол катардагы эң узун карта ──
    // IntrinsicHeight колдонбойбуз (ал бийиктикти ашыкча эсептеп, карта
    // астында боштук калтырат). Ордуна _EqualHeightRow: карталарды өлчөп,
    // эң узунун табып, баарын так ошол бийиктикке келтирет.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(hPad, 8, hPad, 120),
      cacheExtent: MediaQuery.of(context).size.height * 2,
      itemCount: (products.length / columns).ceil(),
      itemBuilder: (context, rowIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: spacing),
          child: EqualHeightRow(
            spacing: spacing,
            children: [
              for (var col = 0; col < columns; col++)
                rowIndex * columns + col < products.length
                    ? RepaintBoundary(
                        key: ValueKey(products[rowIndex * columns + col].id),
                        child: ProductCard(
                          product: products[rowIndex * columns + col],
                          onTap: () => onProductTap(
                              products[rowIndex * columns + col]),
                        ),
                      )
                    : const SizedBox.shrink(),
            ],
          ),
        );
      },
    );
  }
}