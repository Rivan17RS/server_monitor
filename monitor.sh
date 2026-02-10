#!/bin/bash

# ----------------------------------------------------------------
# Script: monitor.sh
# Author: Ivan Rojas Salazar
# Fecha: 2026-02-08
# Revisited: 2026-02-10
# Descripción: 
#  Este script obtiene información del sistema, como uso de CPU, 
# memoria y disco, y genera un reporte en formato HTML y JSON. 
# Además, rota los reportes cada 30 días para mantener el directorio limpio. 
# El script también genera un cron job para ejecutarse automáticamente 2 horas. 
#  
# Uso:
# 1. Configure la variable "BASE_DIR" con el directorio deseado.
# 2. Configure de manera local el cronjob, por ejemplo:
#    0 */2 * * * /ruta/a/monitor.sh 
# 3. Ejecute el script './monitor.sh' y se creará 
#    un backup con la fecha actual en el nombre del archivo.
# 4. Creará un reporte HTML y JSON en los directorios correspondientes.
# 5. Git push automático de los reportes generados (yo uso ssh).
#    para poder utilizarlo, asegurese de configurar el repo:
#     git init
#     git remote add origin https://github.com/<usuario>/<repositorio>.git
# --------------------------------------------------------------------

# ==== CONFIGURACION ====
BASE_DIR="$HOME/server_monitor"
HTML_DIR="$BASE_DIR/reports/html"
JSON_DIR="$BASE_DIR/reports/json"
LOG_DIR="$BASE_DIR/logs"

mkdir -p $HTML_DIR $JSON_DIR $LOG_DIR

LOG_FILE="$LOG_DIR/monitor.log"

DATE_FULL=$(date)
DATE_FILE=$(date +"%Y%m%d_%H%M%S")
HOSTNAME=$(hostname)
USER_EXEC=$(whoami)

REPORT_HTML="$HTML_DIR/${DATE_FILE}_${HOSTNAME}_${USER_EXEC}.html"
REPORT_JSON="$JSON_DIR/${DATE_FILE}_${HOSTNAME}_${USER_EXEC}.json"

DISK_ALERT_THRESHOLD=80

# He utilizado funciones para organizar el codigo y mejorar su legibilidad.
# log: Utiliza timestamp para registrar mensajes en el archivo de log.
# collect_system_info: Obtiene informacion general del sistema.
# collect_metrics: Obtiene metricas de uso de CPU, memoria y disco.
# collect_top_files: Obtiene top 10 de archivos grandes.
# collect_top_processes: Obtiene top 10 procesos.
# check_alerts: Verifica si alguna metrica supera el umbral definido y genera una alerta (puntos extra jeje).
# generate_json: Rreporte en formato JSON.
# generate_html: Reporte en formato HTML.
# rotate_reports: Elimina reportes antiguos de mas de 30 dias.
# main: Funcion principal que ejecuta todas las tareas en orden.
# ----->

log() {
    echo "$(date) - $1" >> $LOG_FILE
}


collect_system_info() {
    UPTIME=$(uptime -p)
}

# ------ metricas de uso y archivos/procesos ------
collect_metrics() {

    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
    MEM_USAGE=$(free | awk '/Mem:/ {printf("%.2f"), $3/$2 * 100}')
    ROOT_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

}


collect_top_files() {
    TOP_FILES=$(du -ah / 2>/dev/null | sort -rh | head -n 10)
}


collect_top_processes() {
    TOP_PROCESSES=$(ps -eo pid,comm,%cpu --sort=-%cpu | head -n 11)
}

# ------ alertas ------
check_alerts() {
    ALERT_MESSAGE=""

    if [ "$ROOT_USAGE" -gt "$DISK_ALERT_THRESHOLD" ]; then
        ALERT_MESSAGE="⚠ ALERT: Root partition above ${DISK_ALERT_THRESHOLD}%"
        log "$ALERT_MESSAGE"
    fi
}

#------ generacion de reportes JSON y HTML ------
generate_json() {

cat <<EOF > $REPORT_JSON
{
  "hostname": "$HOSTNAME",
  "user": "$USER_EXEC",
  "date": "$DATE_FULL",
  "uptime": "$UPTIME",
  "cpu_usage": "$CPU_USAGE",
  "memory_usage": "$MEM_USAGE",
  "root_usage": "$ROOT_USAGE",
  "alert": "$ALERT_MESSAGE"
}
EOF

}


generate_html() {

if [ "$ROOT_USAGE" -gt "$DISK_ALERT_THRESHOLD" ]; then
    ROOT_COLOR="red"
else
    ROOT_COLOR="green"
fi

cat <<EOF > $REPORT_HTML
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Server Report - $HOSTNAME</title>
<style>
body { font-family: Arial; background:#f0f2f5; padding:30px; }
.card { background:white; padding:20px; margin-bottom:20px; border-radius:10px; box-shadow:0 2px 5px rgba(0,0,0,0.1);}
.bar { height:20px; background:steelblue; margin-bottom:10px;}
.alert { color:red; font-weight:bold; }
</style>
</head>

<body>

<h1>Server Monitoring Dashboard</h1>

<div class="card">
<h2>General Info</h2>
<p><b>Hostname:</b> $HOSTNAME</p>
<p><b>User:</b> $USER_EXEC</p>
<p><b>Date:</b> $DATE_FULL</p>
<p><b>Uptime:</b> $UPTIME</p>
<p class="alert">$ALERT_MESSAGE</p>
</div>

<div class="card">
<h2>Performance Metrics</h2>

<p>CPU Usage: $CPU_USAGE%</p>
<div class="bar" style="width:${CPU_USAGE}%"></div>

<p>Memory Usage: $MEM_USAGE%</p>
<div class="bar" style="width:${MEM_USAGE}%"></div>

<p>Root Partition: $ROOT_USAGE%</p>
<div class="bar" style="width:${ROOT_USAGE}%; background:$ROOT_COLOR;"></div>

</div>

<div class="card">
<h2>Top 10 Largest Files</h2>
<pre>$TOP_FILES</pre>
</div>

<div class="card">
<h2>Top 10 CPU Processes</h2>
<pre>$TOP_PROCESSES</pre>
</div>

</body>
</html>
EOF

}

rotate_reports() {
    find $HTML_DIR -type f -mtime +30 -delete
    find $JSON_DIR -type f -mtime +30 -delete
}

# -------- push a git --------
push_to_git() {

    log "Starting Git upload process"

    cd "$BASE_DIR" || {
        log "ERROR: Cannot access BASE_DIR"
        return 1
    }

    # Verificar si es repositorio git
    if [ ! -d ".git" ]; then
        log "ERROR: Not a git repository"
        return 1
    fi

    # Agregar solo los reportes nuevos
    git add "$REPORT_HTML" "$REPORT_JSON"

    # Verificar si hay cambios
    if git diff --cached --quiet; then
        log "No changes to commit"
        return 0
    fi

    COMMIT_MSG="Automated report - $DATE_FILE - $HOSTNAME"

    git commit -m "$COMMIT_MSG" >> "$LOG_FILE" 2>&1

    git push origin main >> "$LOG_FILE" 2>&1

    if [ $? -eq 0 ]; then
        log "Git push successful"
    else
        log "ERROR: Git push failed"
    fi
}

#------ funcion Main ------
main() {

    log "Starting monitoring execution"

    collect_system_info
    collect_metrics
    collect_top_files
    collect_top_processes
    check_alerts
    generate_json
    generate_html
    rotate_reports
    push_to_git

    log "Execution completed successfully"

}

# llamado principal de main
main
