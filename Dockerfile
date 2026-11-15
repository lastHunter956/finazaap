# Imagen base de Ubuntu con herramientas esenciales para amd64 (x86_64)
FROM --platform=linux/amd64 ubuntu:22.04

# Evitar prompts interactivos durante la instalación
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependencias requeridas para Flutter y Android SDK
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    zip \
    openjdk-17-jdk-headless \
    libglu1-mesa \
    wget \
    xz-utils \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    && rm -rf /var/lib/apt/lists/*

# Definir variables de entorno para Android SDK
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH=${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools

# Descargar e instalar Android Command Line Tools
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

# Aceptar licencias e instalar plataformas de compilación y build-tools
RUN yes | sdkmanager --licenses && \
    sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Instalar Flutter SDK (versión fijada para compilación reproducible)
ARG FLUTTER_VERSION=3.44.2
ENV FLUTTER_HOME=/opt/flutter
ENV PATH=${PATH}:${FLUTTER_HOME}/bin
RUN git clone --branch ${FLUTTER_VERSION} --depth 1 https://github.com/flutter/flutter.git ${FLUTTER_HOME} && \
    git config --global --add safe.directory ${FLUTTER_HOME}

# Ejecutar flutter doctor para verificar y descargar dependencias iniciales
RUN flutter doctor --android-licenses || true
RUN flutter doctor

# Configurar directorio de trabajo
WORKDIR /app

# Exponer el puerto de depuración por si se requiere
EXPOSE 8080 5037

# Comando predeterminado: mantener contenedor vivo o ejecutar análisis
CMD ["bash"]
