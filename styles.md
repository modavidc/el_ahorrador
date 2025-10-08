# Guía de Estilos - El Ahorrador

> **Nota:** Esta aplicación usa **únicamente tema claro (Light Theme)**. No hay modo oscuro.

---

## 🎨 Paleta de Colores

### Colores Principales
```dart
- Background Principal: Colors.grey[50] (#FAFAFA)
- Background Cards: Colors.white (#FFFFFF)
- Color Primario (Accent): Colors.red (#F44336)
- Color Texto Principal: Colors.black / Colors.black87
- Color Texto Secundario: Colors.grey[600] (#757575)
- Color Texto Terciario: Colors.grey[400] (#BDBDBD)
- Color Texto Placeholder: Colors.grey[500] (#9E9E9E)
```

### Colores Semánticos
```dart
- Gasto (Expense): Colors.red (#F44336)
- Ingreso (Income): Colors.blue (#2196F3)
- Balance Positivo: Colors.green (#4CAF50)
- Balance Negativo: Colors.red (#F44336)
- Advertencia: Colors.orange (#FF9800)
```

### Colores de Estado
```dart
- Seleccionado: Colors.red
- No Seleccionado: Colors.grey[400]
- Borde: Colors.grey[200] (#EEEEEE)
- Borde Activo: Colors.red
- Divider: Colors.grey[200]
```

---

## 📝 Tipografía (Compacta)

### Títulos
```dart
- AppBar Title: fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black
- Section Header: fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black
- Card Title: fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[800]
```

### Cuerpo
```dart
- Body Regular: fontSize: 15, fontWeight: FontWeight.normal, color: Colors.black87
- Body Medium: fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87
- Body Bold: fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87
```

### Labels y Secundario
```dart
- Label: fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[600]
- Caption: fontSize: 12, color: Colors.grey[600]
- Small Text: fontSize: 12, color: Colors.grey[600]
- Hint Text: fontSize: 13, color: Colors.grey[500]
```

### Montos
```dart
- Monto Detalle Pantalla: fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: -1
- Monto Input Grande: fontSize: 28, fontWeight: FontWeight.w600
- Monto Card Grande: fontSize: 18, fontWeight: FontWeight.bold
- Monto Card Normal: fontSize: 16, fontWeight: FontWeight.w600
- Monto Pequeño: fontSize: 15, fontWeight: FontWeight.w500
```

### Teclado Numérico
```dart
- Números: fontSize: 20, fontWeight: FontWeight.w400, color: Colors.black87
- Símbolos: fontSize: 20, fontWeight: FontWeight.w400, color: Colors.black87
- Labels Moneda: fontSize: 14, fontWeight: FontWeight.w600
```

---

## 🎯 AppBar

### Estilo Estándar
```dart
backgroundColor: Colors.white
elevation: 0
iconTheme: IconThemeData(color: Colors.black)
titleTextStyle: TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: Colors.black,
)
```

---

## 📦 Cards y Contenedores

### Card Estándar
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withValues(alpha: 0.1),
        spreadRadius: 1,
        blurRadius: 10,
        offset: Offset(0, 2),
      ),
    ],
  ),
  padding: EdgeInsets.all(20),
)
```

### Card Compacto
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withValues(alpha: 0.08),
        spreadRadius: 1,
        blurRadius: 6,
        offset: Offset(0, 1),
      ),
    ],
  ),
  padding: EdgeInsets.all(16),
)
```

---

## 🔘 Botones

### Botón Primario (Acción Principal)
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.red,
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 0,
  ),
  child: Text(
    'Texto',
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  ),
)
```

### Botón Secundario
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.grey[100],
    foregroundColor: Colors.black87,
    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 0,
  ),
  child: Text(
    'Texto',
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  ),
)
```

### Floating Action Button
```dart
FloatingActionButton(
  onPressed: () {},
  backgroundColor: Colors.red,
  elevation: 4,
  child: Icon(Icons.add, color: Colors.white),
)
```

---

## 🎚️ Tabs y Segmented Controls

### Tab Bar
```dart
TabBar(
  indicatorColor: Colors.red,
  labelColor: Colors.red,
  unselectedLabelColor: Colors.grey,
  labelStyle: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  ),
)
```

### Botones de Tipo (Ingreso/Gasto)
```dart
// Seleccionado
Container(
  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
  decoration: BoxDecoration(
    color: Colors.red,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    'Gasto',
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 15,
    ),
  ),
)

// No Seleccionado
Container(
  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.grey[300]!, width: 1),
  ),
  child: Text(
    'Ingreso',
    style: TextStyle(
      color: Colors.grey[700],
      fontWeight: FontWeight.normal,
      fontSize: 15,
    ),
  ),
)
```

---

## 📝 Campos de Texto

### TextField Estándar
```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Label',
    labelStyle: TextStyle(color: Colors.grey[600]),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.grey[300]!),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.red, width: 2),
    ),
    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 0),
  ),
  style: TextStyle(fontSize: 16, color: Colors.black87),
)
```

### Campo de Monto (Destacado)
```dart
Container(
  padding: EdgeInsets.symmetric(vertical: 16),
  decoration: BoxDecoration(
    border: Border(
      bottom: BorderSide(color: Colors.red, width: 2),
    ),
  ),
  child: Text(
    'S/. 0.00',
    style: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.bold,
      color: Colors.red,
    ),
  ),
)
```

---

## 📏 Espaciados (Compactos)

> **Filosofía:** UI compacta para aprovechar mejor el espacio en pantalla

### Márgenes
```dart
- Margen Pantalla Horizontal: 16px
- Margen Card: 16px (horizontal)
- Padding Card: 16-20px
- Padding Interno Campos: 6px vertical
```

### Espaciados Verticales (Compactos)
```dart
- Extra Small: 4px   (dentro de componentes)
- Small: 6-8px       (entre label y valor)
- Medium: 12px       (inicio de sección)
- Standard: 16px     (entre campos)
- Large: 20px        (entre grupos de campos)
- Extra Large: 24px  (antes de botones de acción)
```

### Guía de Espaciados por Contexto
```dart
- Entre tabs y contenido: 12-16px
- Entre campos de formulario: 16px
- Entre grupos de campos: 20px
- Antes de botones de acción: 24px
- Dentro de un campo (label → input): 4-6px
- Padding de botones: 12-14px vertical
```

---

## 🔲 Bordes y Radios

### Border Radius
```dart
- Cards Grandes: 16px
- Cards Medianas: 12px
- Botones: 12px
- Badges/Pills: 20px (circular)
- Inputs: 8px
```

### Borders
```dart
- Divider: 1px, Colors.grey[200]
- Border Normal: 1px, Colors.grey[300]
- Border Activo: 2px, Colors.red
- Border Focus: 2px, Colors.red
```

---

## ✨ Efectos y Sombras

### Box Shadow (Cards)
```dart
boxShadow: [
  BoxShadow(
    color: Colors.grey.withValues(alpha: 0.1),
    spreadRadius: 1,
    blurRadius: 10,
    offset: Offset(0, 2),
  ),
]
```

### Box Shadow (Ligera)
```dart
boxShadow: [
  BoxShadow(
    color: Colors.grey.withValues(alpha: 0.08),
    spreadRadius: 1,
    blurRadius: 6,
    offset: Offset(0, 1),
  ),
]
```

---

## 🎨 Badges e Indicadores

### Badge de Tipo (Gasto/Ingreso)
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  decoration: BoxDecoration(
    color: Colors.red.shade50,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.red.shade200, width: 1),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.arrow_downward, color: Colors.red.shade700, size: 16),
      SizedBox(width: 6),
      Text(
        'GASTO',
        style: TextStyle(
          color: Colors.red.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    ],
  ),
)
```

---

## 📱 Bottom Navigation

```dart
BottomNavigationBar(
  type: BottomNavigationBarType.fixed,
  selectedItemColor: Colors.red,
  unselectedItemColor: Colors.grey,
  selectedFontSize: 12,
  unselectedFontSize: 12,
  backgroundColor: Colors.white,
  elevation: 8,
)
```

---

## 🎯 Principios de Diseño

1. **Tema Único**: Solo tema claro, sin modo oscuro
2. **Consistencia**: Usar siempre los mismos estilos para elementos similares
3. **Jerarquía Visual**: Los elementos importantes deben destacar visualmente
4. **Espaciado Compacto**: Mantener la UI compacta pero respirable (espacios 12-20px)
5. **Colores**: Rojo para acciones y gastos, Azul para ingresos, Gris para neutral
6. **Tipografía**: Usar weights para establecer jerarquía (bold > w600 > w500 > normal)
7. **Feedback Visual**: Indicar estados activos/seleccionados claramente
8. **Fondo Claro**: Siempre usar `Colors.grey[50]` para fondos de pantalla y `Colors.white` para cards

---

## 🎨 Configuración del Tema

### ThemeData Principal
```dart
ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  
  // Colores
  primaryColor: Colors.red,
  scaffoldBackgroundColor: Colors.grey[50],
  cardColor: Colors.white,
  
  // AppBar
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 0,
    foregroundColor: Colors.black,
    iconTheme: IconThemeData(color: Colors.black),
    titleTextStyle: TextStyle(
      color: Colors.black,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  
  // Colores de texto por defecto
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.black87, fontSize: 16),
    bodyMedium: TextStyle(color: Colors.black87, fontSize: 15),
    bodySmall: TextStyle(color: Colors.grey[600], fontSize: 13),
    labelMedium: TextStyle(color: Colors.grey[600], fontSize: 14),
  ),
  
  // Bottom Navigation
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: Colors.red,
    unselectedItemColor: Colors.grey,
    elevation: 8,
  ),
  
  // Cards
  cardTheme: CardTheme(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
)
```

