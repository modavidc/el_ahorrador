import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../data/app_database.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  CategoryRepository(this._db);

  // Obtener todas las categorías
  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final categories = await (_db.select(
        _db.categories,
      )..orderBy([(t) => OrderingTerm.asc(t.order)])).get();

      final result = <CategoryModel>[];
      for (final category in categories) {
        final subcategories =
            await (_db.select(_db.subcategories)
                  ..where((s) => s.categoryId.equals(category.id))
                  ..orderBy([(t) => OrderingTerm.asc(t.order)]))
                .get();

        final subcategoryModels = subcategories
            .map(
              (sub) => SubcategoryModel(
                id: sub.id,
                name: sub.name,
                order: sub.order,
                createdAt: DateTime.fromMillisecondsSinceEpoch(sub.createdAt),
                updatedAt: DateTime.fromMillisecondsSinceEpoch(sub.updatedAt),
              ),
            )
            .toList();

        result.add(
          CategoryModel(
            id: category.id,
            name: category.name,
            icon: category.icon,
            color: category.color,
            subcategories: subcategoryModels,
            order: category.order,
            createdAt: DateTime.fromMillisecondsSinceEpoch(category.createdAt),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(category.updatedAt),
          ),
        );
      }

      return result;
    } catch (e) {
      return [];
    }
  }

  // Agregar nueva categoría
  Future<CategoryModel?> addCategory(CategoryModel category) async {
    try {
      final newId = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        await _db
            .into(_db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: newId,
                name: category.name,
                icon: category.icon,
                color: category.color,
                order: category.order,
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Insertar subcategorías
        for (int i = 0; i < category.subcategories.length; i++) {
          final sub = category.subcategories[i];
          await _db
              .into(_db.subcategories)
              .insert(
                SubcategoriesCompanion.insert(
                  id: _uuid.v4(),
                  categoryId: newId,
                  name: sub.name,
                  order: i,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
      });

      return category.copyWith(
        id: newId,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    } catch (e) {
      return null;
    }
  }

  // Actualizar categoría
  Future<bool> updateCategory(CategoryModel category) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db
          .update(_db.categories)
          .replace(
            CategoriesCompanion(
              id: Value(category.id),
              name: Value(category.name),
              icon: Value(category.icon),
              color: Value(category.color),
              order: Value(category.order),
              createdAt: Value(category.createdAt.millisecondsSinceEpoch),
              updatedAt: Value(now),
            ),
          );

      return true;
    } catch (e) {
      return false;
    }
  }

  // Eliminar categoría
  Future<bool> deleteCategory(String categoryId) async {
    try {
      return await _db.transaction(() async {
        final existing = await (_db.select(
          _db.categories,
        )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
        if (existing == null) return false;
        final childIds =
            (await (_db.select(
                  _db.subcategories,
                )..where((s) => s.categoryId.equals(categoryId))).get())
                .map((row) => row.id)
                .toList();
        if (childIds.isNotEmpty) {
          await (_db.update(_db.expenses)
                ..where((e) => e.subcategoryId.isIn(childIds)))
              .write(const ExpensesCompanion(subcategoryId: Value(null)));
        }
        await (_db.update(
          _db.expenses,
        )..where((e) => e.categoryId.equals(categoryId))).write(
          const ExpensesCompanion(
            categoryId: Value(null),
            subcategoryId: Value(null),
          ),
        );
        // Eliminar subcategorías primero
        await (_db.delete(
          _db.subcategories,
        )..where((s) => s.categoryId.equals(categoryId))).go();

        // Eliminar categoría
        await (_db.delete(
          _db.categories,
        )..where((c) => c.id.equals(categoryId))).go();

        return true;
      });
    } catch (e) {
      return false;
    }
  }

  // Agregar subcategoría
  Future<bool> addSubcategory(
    String categoryId,
    SubcategoryModel subcategory,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      final parent = await (_db.select(
        _db.categories,
      )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
      if (parent == null) return false;
      await _db
          .into(_db.subcategories)
          .insert(
            SubcategoriesCompanion.insert(
              id: _uuid.v4(),
              categoryId: categoryId,
              name: subcategory.name,
              order: subcategory.order,
              createdAt: now,
              updatedAt: now,
            ),
          );

      return true;
    } catch (e) {
      return false;
    }
  }

  // Actualizar subcategoría
  Future<bool> updateSubcategory(
    String categoryId,
    SubcategoryModel subcategory,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      final existing =
          await (_db.select(_db.subcategories)..where(
                (s) =>
                    s.id.equals(subcategory.id) &
                    s.categoryId.equals(categoryId),
              ))
              .getSingleOrNull();
      if (existing == null) return false;
      await _db
          .update(_db.subcategories)
          .replace(
            SubcategoriesCompanion(
              id: Value(subcategory.id),
              categoryId: Value(categoryId),
              name: Value(subcategory.name),
              order: Value(subcategory.order),
              createdAt: Value(subcategory.createdAt.millisecondsSinceEpoch),
              updatedAt: Value(now),
            ),
          );

      return true;
    } catch (e) {
      return false;
    }
  }

  // Eliminar subcategoría
  Future<bool> deleteSubcategory(
    String categoryId,
    String subcategoryId,
  ) async {
    try {
      return await _db.transaction(() async {
        final existing =
            await (_db.select(_db.subcategories)..where(
                  (s) =>
                      s.id.equals(subcategoryId) &
                      s.categoryId.equals(categoryId),
                ))
                .getSingleOrNull();
        if (existing == null) return false;
        await (_db.update(_db.expenses)
              ..where((e) => e.subcategoryId.equals(subcategoryId)))
            .write(const ExpensesCompanion(subcategoryId: Value(null)));
        await (_db.delete(_db.subcategories)..where(
              (s) =>
                  s.id.equals(subcategoryId) & s.categoryId.equals(categoryId),
            ))
            .go();

        return true;
      });
    } catch (e) {
      return false;
    }
  }

  // Reordenar categorías
  Future<bool> reorderCategories(
    List<CategoryModel> reorderedCategories,
  ) async {
    try {
      return await _db.transaction(() async {
        final persistedIds = (await _db.select(_db.categories).get())
            .map((row) => row.id)
            .toSet();
        final requestedIds = reorderedCategories.map((row) => row.id).toList();
        if (requestedIds.toSet().length != requestedIds.length ||
            requestedIds.toSet().difference(persistedIds).isNotEmpty) {
          return false;
        }
        for (int i = 0; i < reorderedCategories.length; i++) {
          final category = reorderedCategories[i];
          await _db
              .update(_db.categories)
              .replace(
                CategoriesCompanion(
                  id: Value(category.id),
                  name: Value(category.name),
                  icon: Value(category.icon),
                  color: Value(category.color),
                  order: Value(i),
                  createdAt: Value(category.createdAt.millisecondsSinceEpoch),
                  updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
                ),
              );
        }
        return true;
      });
    } catch (e) {
      return false;
    }
  }

  // Reordenar subcategorías
  Future<bool> reorderSubcategories(
    String categoryId,
    List<SubcategoryModel> reorderedSubcategories,
  ) async {
    try {
      return await _db.transaction(() async {
        final parent = await (_db.select(
          _db.categories,
        )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
        if (parent == null) return false;
        final persistedIds =
            (await (_db.select(
                  _db.subcategories,
                )..where((s) => s.categoryId.equals(categoryId))).get())
                .map((row) => row.id)
                .toSet();
        final requestedIds = reorderedSubcategories
            .map((row) => row.id)
            .toList();
        if (requestedIds.toSet().length != requestedIds.length ||
            requestedIds.toSet().difference(persistedIds).isNotEmpty) {
          return false;
        }
        for (int i = 0; i < reorderedSubcategories.length; i++) {
          final subcategory = reorderedSubcategories[i];
          await _db
              .update(_db.subcategories)
              .replace(
                SubcategoriesCompanion(
                  id: Value(subcategory.id),
                  categoryId: Value(categoryId),
                  name: Value(subcategory.name),
                  order: Value(i),
                  createdAt: Value(
                    subcategory.createdAt.millisecondsSinceEpoch,
                  ),
                  updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
                ),
              );
        }
        return true;
      });
    } catch (e) {
      return false;
    }
  }

  // Buscar categoría por nombre
  Future<CategoryModel?> getCategoryByName(String name) async {
    try {
      final category = await (_db.select(
        _db.categories,
      )..where((c) => c.name.equals(name))).getSingleOrNull();

      if (category == null) return null;

      final subcategories =
          await (_db.select(_db.subcategories)
                ..where((s) => s.categoryId.equals(category.id))
                ..orderBy([(t) => OrderingTerm.asc(t.order)]))
              .get();

      final subcategoryModels = subcategories
          .map(
            (sub) => SubcategoryModel(
              id: sub.id,
              name: sub.name,
              order: sub.order,
              createdAt: DateTime.fromMillisecondsSinceEpoch(sub.createdAt),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(sub.updatedAt),
            ),
          )
          .toList();

      return CategoryModel(
        id: category.id,
        name: category.name,
        icon: category.icon,
        color: category.color,
        subcategories: subcategoryModels,
        order: category.order,
        createdAt: DateTime.fromMillisecondsSinceEpoch(category.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(category.updatedAt),
      );
    } catch (e) {
      return null;
    }
  }

  // Buscar subcategoría por nombre
  Future<SubcategoryModel?> getSubcategoryByName(
    String categoryName,
    String subcategoryName,
  ) async {
    try {
      final category = await getCategoryByName(categoryName);
      if (category == null) return null;

      final subcategory =
          await (_db.select(_db.subcategories)..where(
                (s) =>
                    s.categoryId.equals(category.id) &
                    s.name.equals(subcategoryName),
              ))
              .getSingleOrNull();

      if (subcategory == null) return null;

      return SubcategoryModel(
        id: subcategory.id,
        name: subcategory.name,
        order: subcategory.order,
        createdAt: DateTime.fromMillisecondsSinceEpoch(subcategory.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(subcategory.updatedAt),
      );
    } catch (e) {
      return null;
    }
  }

  // Obtener categoría por ID
  Future<CategoryModel?> getCategoryById(String categoryId) async {
    try {
      final category = await (_db.select(
        _db.categories,
      )..where((c) => c.id.equals(categoryId))).getSingleOrNull();

      if (category == null) return null;

      final subcategories =
          await (_db.select(_db.subcategories)
                ..where((s) => s.categoryId.equals(category.id))
                ..orderBy([(t) => OrderingTerm.asc(t.order)]))
              .get();

      final subcategoryModels = subcategories
          .map(
            (sub) => SubcategoryModel(
              id: sub.id,
              name: sub.name,
              order: sub.order,
              createdAt: DateTime.fromMillisecondsSinceEpoch(sub.createdAt),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(sub.updatedAt),
            ),
          )
          .toList();

      return CategoryModel(
        id: category.id,
        name: category.name,
        icon: category.icon,
        color: category.color,
        subcategories: subcategoryModels,
        order: category.order,
        createdAt: DateTime.fromMillisecondsSinceEpoch(category.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(category.updatedAt),
      );
    } catch (e) {
      return null;
    }
  }

  // Obtener subcategoría por ID
  Future<SubcategoryModel?> getSubcategoryById(String subcategoryId) async {
    try {
      final subcategory = await (_db.select(
        _db.subcategories,
      )..where((s) => s.id.equals(subcategoryId))).getSingleOrNull();

      if (subcategory == null) return null;

      return SubcategoryModel(
        id: subcategory.id,
        name: subcategory.name,
        order: subcategory.order,
        createdAt: DateTime.fromMillisecondsSinceEpoch(subcategory.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(subcategory.updatedAt),
      );
    } catch (e) {
      return null;
    }
  }

  // Limpiar todas las categorías (para testing o reset)
  Future<bool> clearAllCategories() async {
    try {
      return await _db.transaction(() async {
        await _db
            .update(_db.expenses)
            .write(
              const ExpensesCompanion(
                categoryId: Value(null),
                subcategoryId: Value(null),
              ),
            );
        await _db.delete(_db.subcategories).go();
        await _db.delete(_db.categories).go();
        return true;
      });
    } catch (e) {
      return false;
    }
  }
}
