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
  static Future<Category?> getCategoryByName(String name) async {
    final category = await CategoryService().getCategoryByName(name);
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

  static Future<List<String>> getSubcategories(String categoryName) async {
    return await CategoryService().getSubcategories(categoryName);
  }

  static Future<String> getCategoryIcon(String categoryName) async {
    return await CategoryService().getCategoryIcon(categoryName);
  }

  static Future<String> getCategoryColor(String categoryName) async {
    return await CategoryService().getCategoryColor(categoryName);
  }

  // Método para obtener todas las categorías como objetos Category (compatibilidad)
  static Future<List<Category>> getAllCategories() async {
    final categories = await CategoryService().getAllCategories();
    return categories.map((cat) => Category(
      name: cat.name,
      icon: cat.icon,
      color: cat.color,
      subcategories: cat.subcategories.map((s) => s.name).toList(),
    )).toList();
  }
}
