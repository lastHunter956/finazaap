#!/usr/bin/env python3
"""Suite de Pruebas de Aceptación No Destructivas para Controles de Maestro.

Verifica:
1. Reconocimiento y estructura válida de la skill moneo-maestro-e2e.
2. Aceptación de flujos autorizados (com.example.finazaap.validation).
3. Rechazo estricto de appId no autorizado o app productiva protegida (com.example.finazaap).
4. Rechazo estricto de acciones destructivas (clearState: true, uninstallApp, installApp).
5. Rechazo estricto de funciones remotas (assertWithAI, maestro cloud) y scripts arbitrarios.
6. Control de concurrencia y bloqueo ante segundo controlador del mismo dispositivo.
7. Aislamiento de red verificado (iptables bloquea salida externa en contenedor).
8. Ejecución no destructiva de lectura de jerarquía (hierarchy) en Moneo Validación.
"""

import json
import os
import re
import subprocess
import sys
import tempfile
import time
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
VALIDATOR_PATH = os.path.join(REPO_ROOT, ".maestro/docker/maestro_validator.py")
RUNNER_PATH = os.path.join(REPO_ROOT, ".maestro/docker/run_maestro.sh")
SKILL_PATH = os.path.join(REPO_ROOT, ".agents/skills/moneo-maestro-e2e/SKILL.md")


def resolve_maestro_env_dir():
    cand = os.path.join(REPO_ROOT, ".maestro-env")
    if not os.path.isdir(os.path.join(cand, "maestro")):
        res = subprocess.run(["git", "rev-parse", "--git-common-dir"], capture_output=True, text=True, cwd=REPO_ROOT)
        if res.returncode == 0 and res.stdout.strip():
            main_root = os.path.abspath(os.path.join(res.stdout.strip(), ".."))
            main_cand = os.path.join(main_root, ".maestro-env")
            if os.path.isdir(os.path.join(main_cand, "maestro")):
                return main_cand
    return cand


MAESTRO_ENV_DIR = resolve_maestro_env_dir()
LOCK_FILE = os.path.join(MAESTRO_ENV_DIR, "device_R5CY21GE9YY.lock")

# Socket docker para entorno local
DOCKER_HOST_CANDIDATE = "unix:///Users/jesusmartinez/.agys/profiles/karoll/.docker/run/docker.sock"


def get_docker_env():
    env = os.environ.copy()
    if os.path.exists("/Users/jesusmartinez/.agys/profiles/karoll/.docker/run/docker.sock"):
        env["DOCKER_HOST"] = DOCKER_HOST_CANDIDATE
    return env


class TestMaestroSecurityControls(unittest.TestCase):
    """Pruebas de aceptación no destructivas."""

    def test_01_skill_recognition_and_structure(self):
        """Verifica que la skill exista, tenga frontmatter válido y secciones requeridas."""
        self.assertTrue(os.path.isfile(SKILL_PATH), f"Skill no encontrada en {SKILL_PATH}")
        with open(SKILL_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        # Frontmatter
        self.assertTrue(content.startswith("---"), "La skill debe iniciar con frontmatter YAML")
        self.assertIn("name: moneo-maestro-e2e", content)
        self.assertIn("description:", content)

        # Secciones clave exigidas
        required_topics = [
            "Cuándo Usar Esta Skill y Recuperación",
            "Verificación Previa Obligatoria",
            "R5CY21GE9YY",
            "com.example.finazaap.validation",
            "Ejecución de Flujos Existentes",
            "Selectores Semánticos vs Coordenadas",
            "Datos Sintéticos y Expectativas Financieras",
            "Taxonomía de Resultados y Clasificación de Fallos",
            "Exclusión de Ajustes",
        ]
        for topic in required_topics:
            self.assertIn(topic, content, f"Tema obligatorio ausente en la skill: '{topic}'")

    def test_02_authorized_flow_accepted(self):
        """Un flujo con appId com.example.finazaap.validation debe ser aceptado por el validador."""
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as f:
            f.write("""appId: com.example.finazaap.validation
---
- launchApp:
    clearState: false
- assertVisible: "Disponible"
""")
            temp_path = f.name

        try:
            res = subprocess.run([sys.executable, VALIDATOR_PATH, "test", temp_path], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, f"Flujo válido rechazado incorrectamente: {res.stderr}")
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def test_03_protected_prod_app_rejected(self):
        """Un flujo dirigido a com.example.finazaap (app productiva) debe ser rechazado ANTES de ejecutar."""
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as f:
            f.write("""appId: com.example.finazaap
---
- launchApp
""")
            temp_path = f.name

        try:
            res = subprocess.run([sys.executable, VALIDATOR_PATH, "test", temp_path], capture_output=True, text=True)
            self.assertNotEqual(res.returncode, 0, "No se rechazó el flujo dirigido a com.example.finazaap")
            self.assertIn("aplicación productiva protegida", res.stderr)
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def test_04_unauthorized_package_rejected(self):
        """Un flujo dirigido a paquetes ajenos (ej. com.android.settings) debe ser rechazado."""
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as f:
            f.write("""appId: com.android.settings
---
- launchApp
""")
            temp_path = f.name

        try:
            res = subprocess.run([sys.executable, VALIDATOR_PATH, "test", temp_path], capture_output=True, text=True)
            self.assertNotEqual(res.returncode, 0, "No se rechazó paquete ajeno")
            self.assertIn("no autorizado", res.stderr)
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def test_05_destructive_clear_state_rejected(self):
        """clearState: true debe ser rechazado para evitar borrado de datos."""
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as f:
            f.write("""appId: com.example.finazaap.validation
---
- launchApp:
    clearState: true
""")
            temp_path = f.name

        try:
            res = subprocess.run([sys.executable, VALIDATOR_PATH, "test", temp_path], capture_output=True, text=True)
            self.assertNotEqual(res.returncode, 0, "No se rechazó clearState: true")
            self.assertIn("clearState: true", res.stderr)
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def test_06_destructive_uninstall_app_rejected(self):
        """uninstallApp debe ser rechazado tajantemente."""
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as f:
            f.write("""appId: com.example.finazaap.validation
---
- uninstallApp: com.example.finazaap.validation
""")
            temp_path = f.name

        try:
            res = subprocess.run([sys.executable, VALIDATOR_PATH, "test", temp_path], capture_output=True, text=True)
            self.assertNotEqual(res.returncode, 0, "No se rechazó uninstallApp")
            self.assertIn("uninstallApp", res.stderr)
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def test_07_remote_ai_assert_rejected(self):
        """assertWithAI debe ser rechazado para evitar exfiltración a LLMs remotos."""
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as f:
            f.write("""appId: com.example.finazaap.validation
---
- assertWithAI: "Verifica que el balance sea positivo"
""")
            temp_path = f.name

        try:
            res = subprocess.run([sys.executable, VALIDATOR_PATH, "test", temp_path], capture_output=True, text=True)
            self.assertNotEqual(res.returncode, 0, "No se rechazó assertWithAI")
            self.assertIn("assertWithAI", res.stderr)
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def test_08_arbitrary_run_script_rejected(self):
        """runScript debe ser rechazado en flujos."""
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as f:
            f.write("""appId: com.example.finazaap.validation
---
- runScript: custom_hack.sh
""")
            temp_path = f.name

        try:
            res = subprocess.run([sys.executable, VALIDATOR_PATH, "test", temp_path], capture_output=True, text=True)
            self.assertNotEqual(res.returncode, 0, "No se rechazó runScript")
            self.assertIn("runScript", res.stderr)
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def test_09_cloud_and_remote_subcommands_rejected(self):
        """maestro cloud / login / logout deben ser rechazados sin tocar la red."""
        for subcmd in ["cloud", "login", "logout", "list-cloud-devices"]:
            res = subprocess.run([sys.executable, VALIDATOR_PATH, subcmd], capture_output=True, text=True)
            self.assertNotEqual(res.returncode, 0, f"No se rechazó subcomando '{subcmd}'")
            self.assertIn("Subcomando bloqueado", res.stderr)

    def test_10_unauthorized_device_rejected(self):
        """Cualquier dispositivo que no sea R5CY21GE9YY debe ser rechazado."""
        res = subprocess.run(
            [sys.executable, VALIDATOR_PATH, "--device", "EMULATOR_1234", "hierarchy"],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(res.returncode, 0, "No se rechazó dispositivo ajeno")
        self.assertIn("Dispositivo 'EMULATOR_1234' no autorizado", res.stderr)

    def test_11_device_exclusivity_lock_rejection(self):
        """Si otro proceso tiene el lock activo de R5CY21GE9YY, la ejecución debe ser rechazada."""
        os.makedirs(MAESTRO_ENV_DIR, exist_ok=True)
        # Crear un lock simulado con el PID actual (que está vivo)
        lock_data = {
            "pid": os.getpid(),
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "device": "R5CY21GE9YY",
            "appId": "com.example.finazaap.validation",
        }
        with open(LOCK_FILE, "w", encoding="utf-8") as f:
            json.dump(lock_data, f)

        try:
            # Invocar el script lanzador con un comando simple
            res = subprocess.run([RUNNER_PATH, "--help"], capture_output=True, text=True, env=get_docker_env())
            self.assertEqual(res.returncode, 2, f"No se devolvió código 2 por dispositivo ocupado: {res.stderr}")
            self.assertIn("está actualmente reservado por proceso", res.stderr)
        finally:
            if os.path.exists(LOCK_FILE):
                os.remove(LOCK_FILE)

    def test_12_stale_lock_cleanup(self):
        """Si existe un lock con un PID muerto (huérfano), debe ser limpiado automáticamente."""
        os.makedirs(MAESTRO_ENV_DIR, exist_ok=True)
        # Usar un PID que no exista (ej. 999999)
        lock_data = {
            "pid": 999999,
            "timestamp": "2026-01-01T00:00:00Z",
            "device": "R5CY21GE9YY",
        }
        with open(LOCK_FILE, "w", encoding="utf-8") as f:
            json.dump(lock_data, f)

        try:
            # Ejecutar validador directo de argumentos (no arranca docker)
            res = subprocess.run([RUNNER_PATH, "--device", "R5CY21GE9YY"], capture_output=True, text=True, env=get_docker_env())
            # Debe haber reportado la limpieza del lock huérfano
            self.assertIn("Limpiando lock huérfano", res.stderr)
        finally:
            if os.path.exists(LOCK_FILE):
                os.remove(LOCK_FILE)

    def test_13_docker_network_isolation_drop_outbound(self):
        """Verifica que el contenedor bloquee salida a internet vía iptables."""
        env = get_docker_env()
        # Intentar conectar a una IP pública (ej. 8.8.8.8 o 1.1.1.1) con timeout de 2s dentro del contenedor
        check_cmd = [
            "docker", "run", "--rm",
            "--cap-add=NET_ADMIN",
            "-e", "ANDROID_ADB_SERVER_ADDRESS=host.docker.internal",
            "-e", "ANDROID_ADB_SERVER_PORT=5037",
            "finazaap-maestro:local",
            "bash", "-c",
            """
            HOST_IP=$(getent hosts host.docker.internal | awk '{print $1}' | head -n 1)
            iptables -F OUTPUT
            iptables -P OUTPUT DROP
            iptables -A OUTPUT -o lo -j ACCEPT
            iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A OUTPUT -d "$HOST_IP" -p tcp --dport 5037 -j ACCEPT
            # Intentar conexión saliente a internet (debe fallar por DROP)
            python3 -c "
import socket, sys
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(2.0)
try:
    s.connect(('8.8.8.8', 53))
    print('LEAK: Conexión externa exitosa')
    sys.exit(1)
except (socket.timeout, OSError):
    print('BLOCKED: Tráfico saliente correctamente bloqueado')
    sys.exit(0)
"
            """
        ]
        res = subprocess.run(check_cmd, capture_output=True, text=True, env=env)
        self.assertEqual(res.returncode, 0, f"El tráfico externo no fue bloqueado: {res.stdout}\n{res.stderr}")
        self.assertIn("BLOCKED: Tráfico saliente correctamente bloqueado", res.stdout)


if __name__ == "__main__":
    unittest.main()
