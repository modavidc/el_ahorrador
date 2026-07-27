import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/data/category_repository.dart';
import 'package:el_ahorrador/models/category_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CategoryRepository(db);
    await repository.clearAllCategories();
  });

  tearDown(() => db.close());

  group('CategoryRepository', () {
    test('creates and reads a category with ordered subcategories', () async {
      final created = await repository.addCategory(
        _category(
          name: 'Mascotas',
          order: 4,
          subcategories: [
            _subcategory(name: 'Veterinario', order: 90),
            _subcategory(name: 'Alimento', order: 10),
          ],
        ),
      );

      expect(created, isNotNull);
      expect(created!.id, isNot('input-category-id'));
      expect(created.createdAt.millisecondsSinceEpoch, greaterThan(0));

      final persisted = await repository.getCategoryById(created.id);
      expect(persisted, isNotNull);
      expect(persisted!.name, 'Mascotas');
      expect(persisted.icon, 'pets');
      expect(persisted.color, '#123456');
      expect(persisted.order, 4);
      expect(persisted.subcategories.map((item) => item.name), [
        'Veterinario',
        'Alimento',
      ]);
      // addCategory defines the persisted order from the supplied list.
      expect(persisted.subcategories.map((item) => item.order), [0, 1]);
      expect(
        persisted.subcategories.map((item) => item.id).toSet(),
        hasLength(2),
      );
    });

    test('updates category fields without losing its children', () async {
      final created = (await repository.addCategory(
        _category(
          name: 'Casa',
          subcategories: [_subcategory(name: 'Mantenimiento')],
        ),
      ))!;
      final beforeUpdate = (await repository.getCategoryById(created.id))!;

      final updated = await repository.updateCategory(
        beforeUpdate.copyWith(
          name: 'Hogar',
          icon: 'home',
          color: '#ABCDEF',
          order: 7,
        ),
      );

      expect(updated, isTrue);
      final persisted = await repository.getCategoryByName('Hogar');
      expect(persisted, isNotNull);
      expect(persisted!.id, created.id);
      expect(persisted.icon, 'home');
      expect(persisted.color, '#ABCDEF');
      expect(persisted.order, 7);
      expect(persisted.subcategories.single.name, 'Mantenimiento');
      expect(await repository.getCategoryByName('Casa'), isNull);
    });

    test('adds, updates, looks up and deletes a subcategory safely', () async {
      final category = (await repository.addCategory(
        _category(name: 'Viajes'),
      ))!;
      final added = await repository.addSubcategory(
        category.id,
        _subcategory(name: 'Hospedaje', order: 3),
      );
      expect(added, isTrue);

      final found = await repository.getSubcategoryByName(
        'Viajes',
        'Hospedaje',
      );
      expect(found, isNotNull);
      expect(found!.order, 3);
      expect(await repository.getSubcategoryById(found.id), isNotNull);

      expect(
        await repository.updateSubcategory(
          category.id,
          found.copyWith(name: 'Hotel', order: 1),
        ),
        isTrue,
      );
      expect((await repository.getSubcategoryById(found.id))!.name, 'Hotel');

      // A category mismatch must not delete another category's child.
      expect(
        await repository.deleteSubcategory('wrong-category', found.id),
        isFalse,
      );
      expect(await repository.getSubcategoryById(found.id), isNotNull);
      expect(await repository.deleteSubcategory(category.id, found.id), isTrue);
      expect(await repository.getSubcategoryById(found.id), isNull);
    });

    test('persists category and subcategory reorder operations', () async {
      final first = (await repository.addCategory(
        _category(
          name: 'Primera',
          order: 0,
          subcategories: [
            _subcategory(name: 'Uno'),
            _subcategory(name: 'Dos'),
          ],
        ),
      ))!;
      final second = (await repository.addCategory(
        _category(name: 'Segunda', order: 1),
      ))!;

      final categories = await repository.getAllCategories();
      expect(
        await repository.reorderCategories([categories[1], categories[0]]),
        isTrue,
      );
      expect((await repository.getAllCategories()).map((item) => item.name), [
        'Segunda',
        'Primera',
      ]);

      final firstPersisted = (await repository.getCategoryById(first.id))!;
      expect(
        await repository.reorderSubcategories(
          first.id,
          firstPersisted.subcategories.reversed.toList(),
        ),
        isTrue,
      );
      expect(
        (await repository.getCategoryById(
          first.id,
        ))!.subcategories.map((item) => item.name),
        ['Dos', 'Uno'],
      );
      expect(
        (await repository.getCategoryById(second.id))!.subcategories,
        isEmpty,
      );
    });

    test('deleting a category also removes all of its subcategories', () async {
      final created = (await repository.addCategory(
        _category(
          name: 'Temporal',
          subcategories: [_subcategory(name: 'Hija')],
        ),
      ))!;
      final childId = (await repository.getCategoryById(
        created.id,
      ))!.subcategories.single.id;

      expect(await repository.deleteCategory(created.id), isTrue);
      expect(await repository.getCategoryById(created.id), isNull);
      expect(await repository.getSubcategoryById(childId), isNull);
    });

    test('rejects cross-category updates and reorder entries', () async {
      final first = (await repository.addCategory(
        _category(
          name: 'Primera',
          subcategories: [_subcategory(name: 'Hija')],
        ),
      ))!;
      final second = (await repository.addCategory(
        _category(
          name: 'Segunda',
          subcategories: [_subcategory(name: 'Otra')],
        ),
      ))!;
      final firstChild = (await repository.getCategoryById(
        first.id,
      ))!.subcategories.single;
      final secondChild = (await repository.getCategoryById(
        second.id,
      ))!.subcategories.single;

      expect(
        await repository.updateSubcategory(second.id, firstChild),
        isFalse,
      );
      expect(
        await repository.reorderSubcategories(first.id, [secondChild]),
        isFalse,
      );
      expect(
        await repository.reorderCategories([
          (await repository.getCategoryById(first.id))!,
          (await repository.getCategoryById(first.id))!,
        ]),
        isFalse,
      );
      expect(
        (await repository.getCategoryById(first.id))!.subcategories.single.id,
        firstChild.id,
      );
      expect(
        (await repository.getCategoryById(second.id))!.subcategories.single.id,
        secondChild.id,
      );
    });

    test(
      'deletion preserves expenses and clears dangling references',
      () async {
        final category = (await repository.addCategory(
          _category(
            name: 'Usada',
            subcategories: [_subcategory(name: 'Hija')],
          ),
        ))!;
        final child = (await repository.getCategoryById(
          category.id,
        ))!.subcategories.single;
        final now = DateTime.now().millisecondsSinceEpoch;
        await db
            .into(db.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'expense-linked',
                date: now,
                amountCents: 100,
                categoryId: Value(category.id),
                subcategoryId: Value(child.id),
                createdAt: now,
                updatedAt: now,
              ),
            );

        expect(
          await repository.deleteSubcategory(category.id, child.id),
          isTrue,
        );
        var expense = await (db.select(
          db.expenses,
        )..where((row) => row.id.equals('expense-linked'))).getSingle();
        expect(expense.categoryId, category.id);
        expect(expense.subcategoryId, isNull);

        expect(await repository.deleteCategory(category.id), isTrue);
        expense = await (db.select(
          db.expenses,
        )..where((row) => row.id.equals('expense-linked'))).getSingle();
        expect(expense.categoryId, isNull);
        expect(expense.subcategoryId, isNull);
      },
    );

    test(
      'clear removes the complete hierarchy and missing lookups are null',
      () async {
        await repository.addCategory(
          _category(
            name: 'Uno',
            subcategories: [_subcategory(name: 'Hija')],
          ),
        );
        await repository.addCategory(_category(name: 'Dos'));

        expect(await repository.clearAllCategories(), isTrue);
        expect(await repository.getAllCategories(), isEmpty);
        expect(await repository.getCategoryById('missing'), isNull);
        expect(await repository.getCategoryByName('missing'), isNull);
        expect(await repository.getSubcategoryById('missing'), isNull);
        expect(
          await repository.getSubcategoryByName('missing', 'missing'),
          isNull,
        );
      },
    );
  });
}

CategoryModel _category({
  required String name,
  int order = 0,
  List<SubcategoryModel> subcategories = const [],
}) {
  final timestamp = DateTime.fromMillisecondsSinceEpoch(1000);
  return CategoryModel(
    id: 'input-category-id',
    name: name,
    icon: 'pets',
    color: '#123456',
    subcategories: subcategories,
    order: order,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

SubcategoryModel _subcategory({required String name, int order = 0}) {
  final timestamp = DateTime.fromMillisecondsSinceEpoch(1000);
  return SubcategoryModel(
    id: 'input-subcategory-id-$name',
    name: name,
    order: order,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
