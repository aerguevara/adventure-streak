#!/bin/bash

# build_check.sh
# Script para compilar Adventure Streak y mostrar errores, advertencias y éxito.

PROJECT="Adventure Streak.xcodeproj"
SCHEME="Adventure Streak"
LOG_FILE="build_output.txt"

echo "⏳ Compilando $SCHEME..."

# Ejecutar xcodebuild y redirigir todo al log
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -sdk iphonesimulator build > "$LOG_FILE" 2>&1
STATUS=$?

# Extraer advertencias del compilador (formato: archivo:linea:col: warning: mensaje)
# También incluimos la línea de resumen de xcodebuild si hay errores
WARNINGS=$(grep -E ": [Ww]arning:" "$LOG_FILE" | grep -v "skipping copy" | sort -u)
ERRORS=$(grep -E ": [Ee]rror:" "$LOG_FILE")

if [ ! -z "$WARNINGS" ]; then
    echo ""
    echo "⚠️  ADVERTENCIAS DETECTADAS:"
    echo "---------------------------"
    echo "$WARNINGS"
    echo "---------------------------"
fi

if [ $STATUS -eq 0 ]; then
    echo ""
    if [ ! -z "$WARNINGS" ]; then
        echo "✅ COMPILACIÓN EXITOSA (con advertencias)"
    else
        echo "✅ COMPILACIÓN EXITOSA"
    fi
else
    echo ""
    echo "❌ ERROR EN LA COMPILACIÓN"
    echo "---------------------------"
    if [ ! -z "$ERRORS" ]; then
        echo "$ERRORS"
    else
        # Si no hay errores detectados con el patrón anterior, mostrar el final del log
        tail -n 20 "$LOG_FILE"
    fi
    echo "---------------------------"
    echo "Revisa el archivo $LOG_FILE para el log completo."
fi

exit $STATUS
