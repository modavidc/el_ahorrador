#!/bin/bash
# Script para preparar imágenes de prueba desde el celular

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "📱 Preparar Imágenes de Prueba"
echo "=============================="
echo ""

# Crear directorio
mkdir -p test_images

echo "Opciones:"
echo ""
echo "1️⃣  Copiar TODAS las capturas de pantalla del celular"
echo "2️⃣  Copiar imágenes de un directorio específico"
echo "3️⃣  Usar imágenes que ya tengas en tu computadora"
echo ""

read -p "Selecciona una opción (1-3): " option

case $option in
    1)
        echo ""
        echo "Copiando capturas de pantalla desde el celular..."
        # Intentar diferentes ubicaciones comunes de screenshots
        adb pull /sdcard/Pictures/Screenshots/ ./test_images/ 2>/dev/null
        adb pull /sdcard/DCIM/Screenshots/ ./test_images/ 2>/dev/null
        adb pull /sdcard/Screenshots/ ./test_images/ 2>/dev/null
        ;;
    2)
        echo ""
        read -p "Ruta en el celular (ej: /sdcard/Download/): " device_path
        adb pull "$device_path" ./test_images/
        ;;
    3)
        echo ""
        read -p "Ruta local de las imágenes: " local_path
        cp "$local_path"/*.{jpg,jpeg,png} ./test_images/ 2>/dev/null
        ;;
    *)
        echo "Opción inválida"
        exit 1
        ;;
esac

# Contar imágenes
IMAGE_COUNT=$(find ./test_images -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | wc -l)

echo ""
if [ "$IMAGE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ $IMAGE_COUNT imágenes preparadas en ./test_images/${NC}"
    echo ""
    echo "Próximo paso:"
    echo "  ./auto_test_performance.sh test_images"
else
    echo -e "${YELLOW}⚠️  No se encontraron imágenes${NC}"
    echo ""
    echo "Alternativa manual:"
    echo "  1. Copia tus capturas de Yape/Banco a ./test_images/"
    echo "  2. Ejecuta: ./auto_test_performance.sh test_images"
fi

