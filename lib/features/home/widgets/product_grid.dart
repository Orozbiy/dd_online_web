import 'package:flutter/material.dart';
import '../../../data/models/product_model.dart';
import 'product_card.dart';

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
    int crossAxisCount;
    if (width > 1200) {
      crossAxisCount = 5;
    } else if (width > 900) {
      crossAxisCount = 4;
    } else if (width > 600) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }

    return GridView.builder(
      // ── Айнек стили үчүн padding: карточкалар тегерек бурчтары
      //    кесилбесин деп четтерден бираз алыс болсун
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      cacheExtent: MediaQuery.of(context).size.height * 2,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        // ── Айнек карточкалар бираз узунураак — текст + баа үчүн орун
        childAspectRatio: 0.62,
        // ── Айнек shadow кесилбесин деп боштук кеңейтилди
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return RepaintBoundary(
          key: ValueKey(product.id),
          // ── Айнек карточканын shadow'су кесилбесин деп
          //    ар бир элементти Padding менен ороп коёбуз
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ProductCard(
              product: product,
              onTap: () => onProductTap(product),
            ),
          ),
        );
      },
    );
  }
}