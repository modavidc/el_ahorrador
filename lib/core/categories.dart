// Este archivo mantiene compatibilidad con el sistema anterior
// pero ahora delega al CategoryService dinámico

import '../core/category_service.dart';

class Category {
  final String name;
  final String icon;
  final List<String> subcategories;
  final String color;

  Category({
    required this.name,
    required this.icon,
    required this.subcategories,
    required this.color,
  });
}

class CategoryManager {
  // Métodos estáticos que delegan al CategoryService dinámico
  static Future<Category?> getCategoryByName(
    CategoryService service,
    String name,
  ) async {
    final category = await service.getCategoryByName(name);
    if (category != null) {
      return Category(
        name: category.name,
        icon: category.icon,
        color: category.color,
        subcategories: category.subcategories.map((s) => s.name).toList(),
      );
    }
    return null;
  }

  static Future<List<String>> getSubcategories(
    CategoryService service,
    String categoryName,
  ) {
    return service.getSubcategories(categoryName);
  }

  static Future<String> getCategoryIcon(
    CategoryService service,
    String categoryName,
  ) {
    return service.getCategoryIcon(categoryName);
  }

  static Future<String> getCategoryColor(
    CategoryService service,
    String categoryName,
  ) {
    return service.getCategoryColor(categoryName);
  }

  // Método para obtener todas las categorías como objetos Category (compatibilidad)
  static Future<List<Category>> getAllCategories(
    CategoryService service,
  ) async {
    final categories = await service.getAllCategories();
    return categories
        .map(
          (cat) => Category(
            name: cat.name,
            icon: cat.icon,
            color: cat.color,
            subcategories: cat.subcategories.map((s) => s.name).toList(),
          ),
        )
        .toList();
  }
}
