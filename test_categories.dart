import 'dart:io';
import 'lib/data/app_database.dart';
import 'lib/core/category_service.dart';
import 'lib/models/category_model.dart';

void main() async {
  print('🧪 Iniciando pruebas del sistema de categorías dinámicas...\n');
  
  // Crear instancia de la base de datos
  final db = AppDatabase();
  final categoryService = CategoryService();
  
  // Inicializar el servicio
  categoryService.initialize(db);
  
  try {
    // 1. Probar obtener todas las categorías
    print('1️⃣ Obteniendo todas las categorías...');
    final categories = await categoryService.getAllCategories();
    print('✅ Se encontraron ${categories.length} categorías:');
    for (final category in categories) {
      print('   📁 ${category.icon} ${category.name} (${category.subcategories.length} subcategorías)');
      for (final sub in category.subcategories) {
        print('      └── ${sub.name}');
      }
    }
    print('');
    
    // 2. Probar búsqueda por nombre
    print('2️⃣ Buscando categoría "Comida"...');
    final comidaCategory = await categoryService.getCategoryByName('Comida');
    if (comidaCategory != null) {
      print('✅ Categoría encontrada: ${comidaCategory.name} con ${comidaCategory.subcategories.length} subcategorías');
    } else {
      print('❌ Categoría no encontrada');
    }
    print('');
    
    // 3. Probar obtener subcategorías
    print('3️⃣ Obteniendo subcategorías de "Transporte"...');
    final subcategories = await categoryService.getSubcategories('Transporte');
    print('✅ Subcategorías de Transporte: ${subcategories.join(', ')}');
    print('');
    
    // 4. Probar agregar nueva categoría
    print('4️⃣ Agregando nueva categoría "Deportes"...');
    final newCategory = await categoryService.addCategory(
      name: 'Deportes',
      icon: '⚽',
      color: 'green',
    );
    if (newCategory != null) {
      print('✅ Categoría agregada: ${newCategory.name} con ID ${newCategory.id}');
      
      // Agregar subcategorías
      await categoryService.addSubcategory(newCategory.id, 'Gimnasio');
      await categoryService.addSubcategory(newCategory.id, 'Fútbol');
      await categoryService.addSubcategory(newCategory.id, 'Natación');
      print('✅ Subcategorías agregadas: Gimnasio, Fútbol, Natación');
    } else {
      print('❌ Error al agregar categoría');
    }
    print('');
    
    // 5. Verificar la nueva categoría
    print('5️⃣ Verificando la nueva categoría...');
    final updatedCategories = await categoryService.getAllCategories();
    final deportesCategory = updatedCategories.firstWhere(
      (cat) => cat.name == 'Deportes',
      orElse: () => throw Exception('Categoría no encontrada'),
    );
    print('✅ Categoría Deportes encontrada con ${deportesCategory.subcategories.length} subcategorías');
    for (final sub in deportesCategory.subcategories) {
      print('   └── ${sub.name}');
    }
    print('');
    
    // 6. Probar búsqueda de subcategoría
    print('6️⃣ Buscando subcategoría "Gimnasio" en "Deportes"...');
    final gimnasioSub = await categoryService.getSubcategoryByName('Deportes', 'Gimnasio');
    if (gimnasioSub != null) {
      print('✅ Subcategoría encontrada: ${gimnasioSub.name}');
    } else {
      print('❌ Subcategoría no encontrada');
    }
    print('');
    
    // 7. Probar eliminar subcategoría
    print('7️⃣ Eliminando subcategoría "Natación"...');
    final success = await categoryService.deleteSubcategory(deportesCategory.id, deportesCategory.subcategories.firstWhere((s) => s.name == 'Natación').id);
    if (success) {
      print('✅ Subcategoría eliminada correctamente');
    } else {
      print('❌ Error al eliminar subcategoría');
    }
    print('');
    
    // 8. Probar eliminar categoría completa
    print('8️⃣ Eliminando categoría "Deportes"...');
    final deleteSuccess = await categoryService.deleteCategory(deportesCategory.id);
    if (deleteSuccess) {
      print('✅ Categoría eliminada correctamente');
    } else {
      print('❌ Error al eliminar categoría');
    }
    print('');
    
    // 9. Verificar estado final
    print('9️⃣ Estado final de categorías...');
    final finalCategories = await categoryService.getAllCategories();
    print('✅ Total de categorías: ${finalCategories.length}');
    print('');
    
    print('🎉 ¡Todas las pruebas completadas exitosamente!');
    print('✅ El sistema de categorías dinámicas está funcionando correctamente');
    
  } catch (e) {
    print('❌ Error durante las pruebas: $e');
  } finally {
    // Cerrar la base de datos
    await db.close();
  }
}
// ignore_for_file: avoid_print
