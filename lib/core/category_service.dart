import '../models/category_model.dart';
import '../data/category_repository.dart';
import '../data/app_database.dart';

class CategoryService {
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  // Cache de categorías para mejor rendimiento
  List<CategoryModel>? _cachedCategories;
  DateTime? _lastCacheUpdate;
  CategoryRepository? _repository;

  // Inicializar con la base de datos
  void initialize(AppDatabase database) {
    _repository = CategoryRepository(database);
  }

  CategoryRepository get _repo {
    if (_repository == null) {
      throw Exception('CategoryService not initialized. Call initialize() first.');
    }
    return _repository!;
  }

  // Obtener todas las categorías (con cache)
  Future<List<CategoryModel>> getAllCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && 
        _cachedCategories != null && 
        _lastCacheUpdate != null &&
        DateTime.now().difference(_lastCacheUpdate!).inMinutes < 5) {
      return _cachedCategories!;
    }

    _cachedCategories = await _repo.getAllCategories();
    _lastCacheUpdate = DateTime.now();
    return _cachedCategories!;
  }

  // Agregar nueva categoría
  Future<CategoryModel?> addCategory({
    required String name,
    required String icon,
    required String color,
    List<SubcategoryModel>? subcategories,
  }) async {
    final categories = await getAllCategories();
    final maxOrder = categories.isEmpty ? 0 : categories.map((c) => c.order).reduce((a, b) => a > b ? a : b);
    
    final newCategory = CategoryModel(
      id: '', // Se asignará en el repositorio
      name: name,
      icon: icon,
      color: color,
      subcategories: subcategories ?? [],
      order: maxOrder + 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await _repo.addCategory(newCategory);
    if (result != null) {
      await _refreshCache();
    }
    return result;
  }

  // Actualizar categoría
  Future<bool> updateCategory(CategoryModel category) async {
    final success = await _repo.updateCategory(category);
    if (success) {
      await _refreshCache();
    }
    return success;
  }

  // Eliminar categoría
  Future<bool> deleteCategory(String categoryId) async {
    final success = await _repo.deleteCategory(categoryId);
    if (success) {
      await _refreshCache();
    }
    return success;
  }

  // Agregar subcategoría
  Future<bool> addSubcategory(String categoryId, String subcategoryName) async {
    final categories = await getAllCategories();
    final category = categories.firstWhere((c) => c.id == categoryId);
    final maxOrder = category.subcategories.isEmpty 
        ? 0 
        : category.subcategories.map((s) => s.order).reduce((a, b) => a > b ? a : b);

    final newSubcategory = SubcategoryModel(
      id: '', // Se asignará en el repositorio
      name: subcategoryName,
      order: maxOrder + 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await _repo.addSubcategory(categoryId, newSubcategory);
    if (success) {
      await _refreshCache();
    }
    return success;
  }

  // Actualizar subcategoría
  Future<bool> updateSubcategory(String categoryId, SubcategoryModel subcategory) async {
    final success = await _repo.updateSubcategory(categoryId, subcategory);
    if (success) {
      await _refreshCache();
    }
    return success;
  }

  // Eliminar subcategoría
  Future<bool> deleteSubcategory(String categoryId, String subcategoryId) async {
    final success = await _repo.deleteSubcategory(categoryId, subcategoryId);
    if (success) {
      await _refreshCache();
    }
    return success;
  }

  // Reordenar categorías
  Future<bool> reorderCategories(List<CategoryModel> reorderedCategories) async {
    final success = await _repo.reorderCategories(reorderedCategories);
    if (success) {
      await _refreshCache();
    }
    return success;
  }

  // Reordenar subcategorías
  Future<bool> reorderSubcategories(String categoryId, List<SubcategoryModel> reorderedSubcategories) async {
    final success = await _repo.reorderSubcategories(categoryId, reorderedSubcategories);
    if (success) {
      await _refreshCache();
    }
    return success;
  }

  // Buscar categoría por nombre
  Future<CategoryModel?> getCategoryByName(String name) async {
    return await _repo.getCategoryByName(name);
  }

  // Buscar subcategoría por nombre
  Future<SubcategoryModel?> getSubcategoryByName(String categoryName, String subcategoryName) async {
    return await _repo.getSubcategoryByName(categoryName, subcategoryName);
  }

  // Obtener subcategorías de una categoría
  Future<List<String>> getSubcategories(String categoryName) async {
    final category = await getCategoryByName(categoryName);
    if (category != null) {
      return category.subcategories.map((sub) => sub.name).toList();
    }
    return ['Otros'];
  }

  // Obtener icono de categoría
  Future<String> getCategoryIcon(String categoryName) async {
    final category = await getCategoryByName(categoryName);
    return category?.icon ?? '📦';
  }

  // Obtener color de categoría
  Future<String> getCategoryColor(String categoryName) async {
    final category = await getCategoryByName(categoryName);
    return category?.color ?? 'grey';
  }

  // Obtener categoría por ID
  Future<CategoryModel?> getCategoryById(String categoryId) async {
    return await _repo.getCategoryById(categoryId);
  }

  // Obtener subcategoría por ID
  Future<SubcategoryModel?> getSubcategoryById(String subcategoryId) async {
    return await _repo.getSubcategoryById(subcategoryId);
  }

  // Refrescar cache
  Future<void> _refreshCache() async {
    _cachedCategories = await _repo.getAllCategories();
    _lastCacheUpdate = DateTime.now();
  }

  // Limpiar cache
  void clearCache() {
    _cachedCategories = null;
    _lastCacheUpdate = null;
  }

  // Limpiar todas las categorías (para testing o reset)
  Future<bool> clearAllCategories() async {
    final success = await _repo.clearAllCategories();
    if (success) {
      clearCache();
    }
    return success;
  }
}