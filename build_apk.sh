#!/usr/bin/env bash
# ============================================================================
# build_apk.sh — Compilador de APK resistente al bug EINTR de Rosetta/Docker
#
# El Dart VM crashea esporádicamente con "Unexpected EINTR errno" al usar
# copy_file_range bajo emulación Rosetta 2 (x86_64 en Apple Silicon).
# Este script:
#   1. Compila en /tmp (filesystem nativo del contenedor, no bind-mount)
#   2. Preserva el caché de compilación entre ejecuciones (builds incrementales)
#   3. Reintenta automáticamente hasta MAX_RETRIES veces ante el crash EINTR
# ============================================================================

set -euo pipefail

MAX_RETRIES=5
BUILD_DIR="/tmp/finazaap_build"

echo "🚀 Iniciando proceso de compilación nativo en $BUILD_DIR..."

# --- 1. Sincronizar archivos del proyecto al directorio nativo ---
mkdir -p "$BUILD_DIR"

echo "📂 Sincronizando archivos de /app a $BUILD_DIR..."
# Usamos find + cp selectivo en lugar de rm -rf para preservar el caché de build
find /app -maxdepth 1 -mindepth 1 | while read -r item; do
  name=$(basename "$item")
  # Excluir directorios pesados/irrelevantes
  if [ "$name" = "build" ] || [ "$name" = ".dart_tool" ] || [ "$name" = ".git" ] || [ "$name" = "analyze_output.txt" ] || [ "$name" = "build_log.txt" ]; then
    continue
  fi
  # Para directorios, borrar y recopiar (garantiza sincronización limpia del código fuente)
  if [ -d "$item" ]; then
    rm -rf "$BUILD_DIR/$name"
  fi
  cp -R "$item" "$BUILD_DIR/"
done

# --- 2. Preparar dependencias ---
cd "$BUILD_DIR"

echo "📥 Obteniendo dependencias de Flutter..."
flutter pub get

# --- 3. Compilar con reintentos ---
echo "🏗️ Compilando APK (con hasta $MAX_RETRIES intentos por bug EINTR de Rosetta)..."

attempt=1
while [ $attempt -le $MAX_RETRIES ]; do
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🔨 Intento $attempt de $MAX_RETRIES"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  set +e
  flutter build apk --release \
    --no-tree-shake-icons \
    --android-skip-build-dependency-validation \
    2>&1
  exit_code=$?
  set -e

  if [ $exit_code -eq 0 ]; then
    echo ""
    echo "✅ Compilación exitosa en el intento $attempt."
    break
  fi

  # Exit code 134 = SIGABRT (el crash EINTR del Dart VM)
  # Exit code 1 también ocurre cuando el Gradle Daemon crashea por OOM o se desconecta
  if [ $exit_code -eq 134 ] || [ $exit_code -eq 1 ]; then
    echo ""
    echo "⚠️  Intento $attempt falló (exit code $exit_code) — posible crash de Rosetta o Daemon OOM."
    if [ $attempt -lt $MAX_RETRIES ]; then
      echo "   Reintentando en 3 segundos..."
      sleep 3
    else
      echo "❌ Se agotaron los $MAX_RETRIES intentos. La compilación no pudo completarse."
      echo "   Sugerencia: Intenta ejecutar 'make apk' de nuevo. El caché de compilación"
      echo "   se preserva entre ejecuciones, así que cada intento tiene más probabilidad de éxito."
      exit 1
    fi
  else
    echo "❌ Error inesperado (exit code $exit_code). Abortando."
    exit $exit_code
  fi

  attempt=$((attempt + 1))
done

# --- 4. Copiar el APK al directorio compartido ---
echo "📦 Copiando el APK compilado de vuelta a /app..."
mkdir -p /app/build/app/outputs/flutter-apk/
cp "$BUILD_DIR/build/app/outputs/flutter-apk/app-release.apk" \
   /app/build/app/outputs/flutter-apk/app-release.apk

echo ""
echo "✨ ¡Compilación completada con éxito!"
echo "   📦 APK: build/app/outputs/flutter-apk/app-release.apk"
echo "   📐 Tamaño: $(du -h /app/build/app/outputs/flutter-apk/app-release.apk | cut -f1)"
