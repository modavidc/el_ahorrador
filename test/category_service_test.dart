import 'package:drift/native.dart';
import 'package:el_ahorrador/core/categories.dart';
import 'package:el_ahorrador/core/category_service.dart';
import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/models/category_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CategoryService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = CategoryService()..initialize(db);
    service.clearCache();
    await service.clearAllCategories();
  });

  tearDown(() async {
    service.clearCache();
    await db.close();
  });

  test(
    'manages a complete category hierarchy and refreshes its cache',
    () async {
      expect(await service.getAllCategories(), isEmpty);
      final created = await service.addCategory(
        name: 'Comidas',
        icon: 'restaurant',
        color: '#ff8800',
      );
      expect(created, isNotNull);
      expect(created!.order, 1);

      expect(await service.addSubcategory(created.id, 'Delivery'), isTrue);
      var persisted = await service.getCategoryById(created.id);
      expect(persisted!.subcategories.single.name, 'Delivery');
      expect(await service.getSubcategories('Comidas'), ['Delivery']);
      expect(await service.getCategoryIcon('Comidas'), 'restaurant');
      expect(await service.getCategoryColor('Comidas'), '#ff8800');

      final child = persisted.subcategories.single;
      expect(
        await service.updateSubcategory(
          created.id,
          child.copyWith(name: 'Restaurante'),
        ),
        isTrue,
      );
      expect((await service.getSubcategoryById(child.id))!.name, 'Restaurante');

      expect(
        await service.updateCategory(created.copyWith(name: 'Alimentos')),
        isTrue,
      );
      expect(await service.getCategoryByName('Alimentos'), isNotNull);
      expect(await service.deleteSubcategory(created.id, child.id), isTrue);
      expect(await service.deleteCategory(created.id), isTrue);
      expect(await service.getAllCategories(forceRefresh: true), isEmpty);
    },
  );

  test(
    'reorders categories and children and exposes safe legacy defaults',
    () async {
      final first = (await service.addCategory(
        name: 'Primera',
        icon: 'one',
        color: 'red',
        subcategories: [_child('Uno'), _child('Dos')],
      ))!;
      final second = (await service.addCategory(
        name: 'Segunda',
        icon: 'two',
        color: 'blue',
      ))!;

      expect(await service.reorderCategories([second, first]), isTrue);
      final refreshed = await service.getAllCategories(forceRefresh: true);
      expect(refreshed.map((item) => item.name), ['Segunda', 'Primera']);
      final children = (await service.getCategoryById(first.id))!.subcategories;
      expect(
        await service.reorderSubcategories(
          first.id,
          children.reversed.toList(),
        ),
        isTrue,
      );
      expect(await service.getSubcategories('missing'), ['Otros']);
      expect(await service.getCategoryIcon('missing'), isNotEmpty);
      expect(await service.getCategoryColor('missing'), 'grey');

      final legacy = await CategoryManager.getCategoryByName('Primera');
      expect(legacy!.subcategories, ['Dos', 'Uno']);
      expect(await CategoryManager.getSubcategories('Primera'), ['Dos', 'Uno']);
      expect(await CategoryManager.getCategoryIcon('Primera'), 'one');
      expect(await CategoryManager.getCategoryColor('Primera'), 'red');
      expect(await CategoryManager.getAllCategories(), hasLength(2));
    },
  );
}

SubcategoryModel _child(String name) => SubcategoryModel(
  id: '',
  name: name,
  order: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
