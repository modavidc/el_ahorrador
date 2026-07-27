import 'dart:convert';

import 'package:el_ahorrador/models/category_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2025, 1, 2, 3, 4, 5);
  final updatedAt = DateTime.utc(2026, 6, 7, 8, 9, 10);

  group('SubcategoryModel', () {
    test('copyWith changes selected fields and preserves the rest', () {
      final original = SubcategoryModel(
        id: 'sub-1',
        name: 'Mercado',
        order: 2,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      final copy = original.copyWith(
        id: 'sub-2',
        name: 'Supermercado',
        order: 0,
        updatedAt: updatedAt,
      );

      expect(copy.id, 'sub-2');
      expect(copy.name, 'Supermercado');
      expect(copy.order, 0);
      expect(copy.createdAt, createdAt);
      expect(copy.updatedAt, updatedAt);

      final unchanged = original.copyWith();
      expect(unchanged.id, original.id);
      expect(unchanged.name, original.name);
      expect(unchanged.order, original.order);
      expect(unchanged.createdAt, original.createdAt);
      expect(unchanged.updatedAt, original.updatedAt);
    });

    test('round-trips through both map and JSON string representations', () {
      final original = SubcategoryModel(
        id: 'sub-unicode',
        name: 'Educación y música 🎵',
        order: 4,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final map = original.toJson();
      expect(map, {
        'id': 'sub-unicode',
        'name': 'Educación y música 🎵',
        'order': 4,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      });
      _expectSameSubcategory(SubcategoryModel.fromJson(map), original);

      final encoded = original.toJsonString();
      expect(jsonDecode(encoded), map);
      _expectSameSubcategory(
        SubcategoryModel.fromJsonString(encoded),
        original,
      );
    });
  });

  group('CategoryModel', () {
    test('copyWith changes every selectable field', () {
      final original = _category(createdAt, updatedAt);
      final replacementChild = SubcategoryModel(
        id: 'replacement',
        name: 'Reemplazo',
        order: 0,
        createdAt: updatedAt,
        updatedAt: updatedAt,
      );

      final copy = original.copyWith(
        id: 'cat-2',
        name: 'Nuevo nombre',
        icon: 'new_icon',
        color: '#FFFFFF',
        subcategories: [replacementChild],
        order: 9,
        createdAt: updatedAt,
        updatedAt: createdAt,
      );

      expect(copy.id, 'cat-2');
      expect(copy.name, 'Nuevo nombre');
      expect(copy.icon, 'new_icon');
      expect(copy.color, '#FFFFFF');
      expect(copy.subcategories, [replacementChild]);
      expect(copy.order, 9);
      expect(copy.createdAt, updatedAt);
      expect(copy.updatedAt, createdAt);

      final unchanged = original.copyWith();
      _expectSameCategory(unchanged, original);
    });

    test('round-trips nested data through map and JSON string', () {
      final original = _category(createdAt, updatedAt);

      final map = original.toJson();
      expect(map['id'], 'cat-1');
      expect(map['createdAt'], createdAt.toIso8601String());
      expect(map['updatedAt'], updatedAt.toIso8601String());
      expect(map['subcategories'], hasLength(2));
      expect((map['subcategories'] as List).first['name'], 'Restaurantes');
      _expectSameCategory(CategoryModel.fromJson(map), original);

      final encoded = original.toJsonString();
      expect(jsonDecode(encoded), map);
      _expectSameCategory(CategoryModel.fromJsonString(encoded), original);
    });
  });
}

CategoryModel _category(DateTime createdAt, DateTime updatedAt) {
  return CategoryModel(
    id: 'cat-1',
    name: 'Comidas',
    icon: 'restaurant',
    color: '#FF8800',
    subcategories: [
      SubcategoryModel(
        id: 'sub-1',
        name: 'Restaurantes',
        order: 0,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      SubcategoryModel(
        id: 'sub-2',
        name: 'Delivery',
        order: 1,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    ],
    order: 3,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

void _expectSameCategory(CategoryModel actual, CategoryModel expected) {
  expect(actual.id, expected.id);
  expect(actual.name, expected.name);
  expect(actual.icon, expected.icon);
  expect(actual.color, expected.color);
  expect(actual.order, expected.order);
  expect(actual.createdAt, expected.createdAt);
  expect(actual.updatedAt, expected.updatedAt);
  expect(actual.subcategories, hasLength(expected.subcategories.length));
  for (var index = 0; index < expected.subcategories.length; index++) {
    _expectSameSubcategory(
      actual.subcategories[index],
      expected.subcategories[index],
    );
  }
}

void _expectSameSubcategory(
  SubcategoryModel actual,
  SubcategoryModel expected,
) {
  expect(actual.id, expected.id);
  expect(actual.name, expected.name);
  expect(actual.order, expected.order);
  expect(actual.createdAt, expected.createdAt);
  expect(actual.updatedAt, expected.updatedAt);
}
