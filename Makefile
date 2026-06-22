# --- CONFIGURACIÓN ---
CONTAINER_NAME=finazaap-flutter

.PHONY: help setup-adb build up down shell devices run web apk clean logs

help:
	@echo "💸 Moneo FinazaApp - Comandos útiles:"
	@echo "  make setup-adb  - Detiene y reinicia el ADB en macOS para permitir conexiones desde Docker"
	@echo "  make build      - Construye la imagen Docker"
	@echo "  make up         - Levanta el contenedor Docker en segundo plano"
	@echo "  make down       - Detiene y remueve los contenedores Docker"
	@echo "  make shell      - Abre una terminal interactiva (bash) dentro del contenedor"
	@echo "  make devices    - Muestra los dispositivos conectados (dentro de Docker)"
	@echo "  make run        - Compila y ejecuta la app en tu celular (dentro de Docker)"
	@echo "  make web        - Ejecuta la app en el navegador web de tu Mac (http://localhost:8080)"
	@echo "  make apk        - Genera el archivo APK de producción (Release APK) en build/app/outputs/apk/release/"
	@echo "  make logs       - Ver logs del contenedor"
	@echo "  make clean      - Limpia los archivos temporales y compilaciones de Flutter"

setup-adb:
	@echo "🔄 Reiniciando servidor ADB en macOS en modo público (0.0.0.0)..."
	-adb kill-server
	# Se ejecuta en segundo plano en macOS. Se requiere tener 'adb' instalado vía brew.
	adb -a nodaemon server start > /dev/null 2>&1 &
	@echo "✅ ADB iniciado en segundo plano. Ya puedes encender tu contenedor."

build:
	docker-compose build

up:
	docker-compose up -d

down:
	docker-compose down

shell:
	docker-compose exec flutter-env bash

devices:
	docker-compose exec flutter-env adb devices

run:
	docker-compose exec flutter-env flutter run

web:
	@echo "Iniciando servidor estático para modelos de IA pesados en el puerto 8081..."
	docker-compose exec -d flutter-env python3 /app/web/serve_models.py
	docker-compose exec flutter-env flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --no-dds

web-release:
	docker-compose exec flutter-env flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --release

apk:
	@echo "🏗️ Generando APK de producción (Release)..."
	docker-compose exec flutter-env bash /app/build_apk.sh
	@echo "✅ APK generado con éxito. Puedes encontrarlo en: build/app/outputs/flutter-apk/app-release.apk"

logs:
	docker-compose logs -f

clean:
	docker-compose exec flutter-env flutter clean
