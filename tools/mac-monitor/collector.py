#!/usr/bin/env python3
"""
collector.py - Coleta métricas de CPU e Memória do Mac via Glances e grava em CSVs diários.

Formato do log:
now.iso,now.custom,cpu.total,mem.used,mem.percent
onde $3 é cpu.total (%) e $5 é mem.percent (%).
"""

import argparse
import os
import signal
import subprocess
import sys
import time

EXPECTED_HEADER = "now.iso,now.custom,cpu.total,mem.used,mem.percent"

running = True
glances_proc = None
current_file_handle = None
current_file_date = None


def signal_handler(signum, frame):
    global running, glances_proc
    sys.stderr.write(f"\n[collector] Sinal {signum} recebido, finalizando com segurança...\n")
    running = False
    if glances_proc and glances_proc.poll() is None:
        try:
            glances_proc.terminate()
            glances_proc.wait(timeout=3)
        except Exception:
            glances_proc.kill()


def get_glances_binary(project_root):
    venv_glances = os.path.join(project_root, ".venv", "bin", "glances")
    if os.path.isfile(venv_glances) and os.access(venv_glances, os.X_OK):
        return venv_glances
    import shutil
    sys_glances = shutil.which("glances")
    if sys_glances:
        return sys_glances
    raise FileNotFoundError(
        f"Binário do Glances não encontrado em '{venv_glances}' ou no PATH do sistema."
    )


def ensure_target_file(logs_dir, date_str):
    global current_file_handle, current_file_date

    if current_file_date == date_str and current_file_handle and not current_file_handle.closed:
        return current_file_handle

    if current_file_handle and not current_file_handle.closed:
        try:
            current_file_handle.flush()
            current_file_handle.close()
        except Exception as e:
            sys.stderr.write(f"[collector] Erro ao fechar arquivo de log anterior: {e}\n")

    os.makedirs(logs_dir, exist_ok=True)
    file_path = os.path.join(logs_dir, f"glances-{date_str}.csv")
    needs_header = not os.path.exists(file_path) or os.path.getsize(file_path) == 0

    current_file_handle = open(file_path, "a", encoding="utf-8")
    if needs_header:
        current_file_handle.write(EXPECTED_HEADER + "\n")
        current_file_handle.flush()

    current_file_date = date_str
    return current_file_handle


def main():
    global running, glances_proc, current_file_handle

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Resolve project root: tools/mac-monitor -> tool-box root
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    default_logs_dir = os.path.join(project_root, "logs")
    default_interval = int(os.environ.get("MONITOR_INTERVAL", 5))

    parser = argparse.ArgumentParser(description="Coletor de uso do Mac via Glances")
    parser.add_argument(
        "-t", "--interval",
        type=int,
        default=default_interval,
        help=f"Intervalo de amostragem em segundos (padrão: {default_interval})"
    )
    parser.add_argument(
        "-d", "--logs-dir",
        type=str,
        default=default_logs_dir,
        help=f"Diretório dos arquivos CSV de log (padrão: {default_logs_dir})"
    )
    parser.add_argument(
        "--pid-file",
        type=str,
        default=os.path.join(default_logs_dir, "monitor.pid"),
        help="Caminho para o arquivo de PID"
    )

    args = parser.parse_args()
    logs_dir = os.path.abspath(args.logs_dir)
    os.makedirs(logs_dir, exist_ok=True)

    pid_file = os.path.abspath(args.pid_file)
    with open(pid_file, "w") as f:
        f.write(str(os.getpid()) + "\n")

    glances_bin = get_glances_binary(project_root)
    print(f"[collector] Glances: {glances_bin}")
    print(f"[collector] Intervalo: {args.interval}s")
    print(f"[collector] Logs: {logs_dir}")
    print(f"[collector] PID: {os.getpid()} (salvo em {pid_file})")

    cmd = [
        glances_bin,
        "-t", str(args.interval),
        "--stdout-csv",
        "now,cpu.total,mem.used,mem.percent"
    ]

    try:
        while running:
            print("[collector] Iniciando processo Glances...")
            glances_proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1
            )

            for raw_line in glances_proc.stdout:
                if not running:
                    break

                line = raw_line.strip()
                if not line:
                    continue

                if line.startswith("now.iso"):
                    continue

                parts = line.split(",")
                if len(parts) < 5:
                    continue

                iso_timestamp = parts[0]
                date_str = iso_timestamp[:10]
                if len(date_str) != 10 or "-" not in date_str:
                    date_str = time.strftime("%Y-%m-%d")

                try:
                    f_out = ensure_target_file(logs_dir, date_str)
                    f_out.write(line + "\n")
                    f_out.flush()
                except Exception as err:
                    sys.stderr.write(f"[collector] Erro ao gravar CSV: {err}\n")

            return_code = glances_proc.poll()
            if running and return_code is not None:
                stderr_output = glances_proc.stderr.read()
                sys.stderr.write(f"[collector] Glances finalizou inesperadamente (código {return_code}). Stderr: {stderr_output}\n")
                print("[collector] Reiniciando Glances em 3 segundos...")
                time.sleep(3)

    finally:
        if glances_proc and glances_proc.poll() is None:
            try:
                glances_proc.terminate()
                glances_proc.wait(timeout=2)
            except Exception:
                glances_proc.kill()

        if current_file_handle and not current_file_handle.closed:
            try:
                current_file_handle.flush()
                current_file_handle.close()
            except Exception:
                pass

        if os.path.exists(pid_file):
            try:
                os.remove(pid_file)
            except Exception:
                pass
        print("[collector] Coletor finalizado com sucesso.")


if __name__ == "__main__":
    main()
