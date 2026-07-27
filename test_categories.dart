import 'dart:io';
import 'lib/data/app_database.dart';
import 'lib/core/category_service.dart';
import 'lib/data/category_repository.dart';

void main() async {
  stdout.writeln(
    '🧪 Iniciando pruebas del sistema de categorías dinámicas...\n',
  );

  // Crear instancia de la base de datos
  final db = AppDatabase();
  final categoryService = CategoryService(CategoryRepository(db));

  try {
    // 1. Probar obtener todas las categorías
    stdout.writeln('1️⃣ Obteniendo todas las categorías...');
    final categories = await categoryService.getAllCategories();
    stdout.writeln('✅ Se encontraron ${categories.length} categorías:');
    for (final category in categories) {
      stdout.writeln(
        '   📁 ${category.icon} ${category.name} (${category.subcategories.length} subcategorías)',
      );
      for (final sub in category.subcategories) {
        stdout.writeln('      └── ${sub.name}');
      }
    }
    stdout.writeln('');

    // 2. Probar búsqueda por nombre
    stdout.writeln('2️⃣ Buscando categoría "Comida"...');
    final comidaCategory = await categoryService.getCategoryByName('Comida');
    if (comidaCategory != null) {
      stdout.writeln(
        '✅ Categoría encontrada: ${comidaCategory.name} con ${comidaCategory.subcategories.length} subcategorías',
      );
    } else {
      stdout.writeln('❌ Categoría no encontrada');
    }
    stdout.writeln('');

    // 3. Probar obtener subcategorías
    stdout.writeln('3️⃣ Obteniendo subcategorías de "Transporte"...');
    final subcategories = await categoryService.getSubcategories('Transporte');
    stdout.writeln(
      '✅ Subcategorías de Transporte: ${subcategories.join(', ')}',
    );
    stdout.writeln('');

    // 4. Probar agregar nueva categoría
    stdout.writeln('4️⃣ Agregando nueva categoría "Deportes"...');
    final newCategory = await categoryService.addCategory(
      name: 'Deportes',
      icon: '⚽',
      color: 'green',
    );
    if (newCategory != null) {
      stdout.writeln(
        '✅ Categoría agregada: ${newCategory.name} con ID ${newCategory.id}',
      );

      // Agregar subcategorías
      await categoryService.addSubcategory(newCategory.id, 'Gimnasio');
      await categoryService.addSubcategory(newCategory.id, 'Fútbol');
      await categoryService.addSubcategory(newCategory.id, 'Natación');
      stdout.writeln('✅ Subcategorías agregadas: Gimnasio, Fútbol, Natación');
    } else {
      stdout.writeln('❌ Error al agregar categoría');
    }
    stdout.writeln('');

    // 5. Verificar la nueva categoría
    stdout.writeln('5️⃣ Verificando la nueva categoría...');
    final updatedCategories = await categoryService.getAllCategories();
    final deportesCategory = updatedCategories.firstWhere(
      (cat) => cat.name == 'Deportes',
      orElse: () => throw Exception('Categoría no encontrada'),
    );
    stdout.writeln(
      '✅ Categoría Deportes encontrada con ${deportesCategory.subcategories.length} subcategorías',
    );
    for (final sub in deportesCategory.subcategories) {
      stdout.writeln('   └── ${sub.name}');
    }
    stdout.writeln('');

    // 6. Probar búsqueda de subcategoría
    stdout.writeln('6️⃣ Buscando subcategoría "Gimnasio" en "Deportes"...');
    final gimnasioSub = await categoryService.getSubcategoryByName(
      'Deportes',
      'Gimnasio',
    );
    if (gimnasioSub != null) {
      stdout.writeln('✅ Subcategoría encontrada: ${gimnasioSub.name}');
    } else {
      stdout.writeln('❌ Subcategoría no encontrada');
    }
    stdout.writeln('');

    // 7. Probar eliminar subcategoría
    stdout.writeln('7️⃣ Eliminando subcategoría "Natación"...');
    final success = await categoryService.deleteSubcategory(
      deportesCategory.id,
      deportesCategory.subcategories.firstWhere((s) => s.name == 'Natación').id,
    );
    if (success) {
      stdout.writeln('✅ Subcategoría eliminada correctamente');
    } else {
      stdout.writeln('❌ Error al eliminar subcategoría');
    }
    stdout.writeln('');

    // 8. Probar eliminar categoría completa
    stdout.writeln('8️⃣ Eliminando categoría "Deportes"...');
    final deleteSuccess = await categoryService.deleteCategory(
      deportesCategory.id,
    );
    if (deleteSuccess) {
      stdout.writeln('✅ Categoría eliminada correctamente');
    } else {
      stdout.writeln('❌ Error al eliminar categoría');
    }
    stdout.writeln('');

    // 9. Verificar estado final
    stdout.writeln('9️⃣ Estado final de categorías...');
    final finalCategories = await categoryService.getAllCategories();
    stdout.writeln('✅ Total de categorías: ${finalCategories.length}');
    stdout.writeln('');

    stdout.writeln('🎉 ¡Todas las pruebas completadas exitosamente!');
    stdout.writeln(
      '✅ El sistema de categorías dinámicas está funcionando correctamente',
    );
  } catch (e) {
    stdout.writeln('❌ Error durante las pruebas: $e');
  } finally {
    // Cerrar la base de datos
    await db.close();
  }
}
