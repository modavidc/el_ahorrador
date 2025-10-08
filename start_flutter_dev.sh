#!/bin/bash

# Script para iniciar Flutter con hot reload habilitado
echo "🚀 Iniciando Flutter con hot reload..."

# Limpiar cache si es necesario
if [ "$1" = "--clean" ]; then
    echo "🧹 Limpiando cache..."
    flutter clean
    flutter pub get
fi

# Verificar que no hay procesos de Flutter corriendo
echo "🔍 Verificando procesos de Flutter..."
pkill -f "flutter run" || true
sleep 2

# Iniciar Flutter con hot reload
echo "🔥 Iniciando Flutter con hot reload habilitado..."
flutter run --hot --verbose

echo "✅ Flutter iniciado. El hot reload debería funcionar automáticamente al guardar archivos."
