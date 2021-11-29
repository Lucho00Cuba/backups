#!/bin/bash

# FUNCTIONS
helpBackup() {
        echo -e "\n\tEjemplo: ./backup <type> (full|diff|inc) path-absolute\n"
        exit 0
}

compruebaDir() {
        if [ ! -d "$DIR" ]; then
                echo -e "ERROR: No es posible respaldar $DIR. El directorio no existe.\n"
        fi
}

checkBackup() {
        ESTADO="OK"
        if [ "$1" == "error" ]; then
                ESTADO="ERROR"
                echo -e "\nEMERG: No se pudo verificar el archivador $TAR. Se recomienda revisar la última copia\n"
        elif [ "$1" == "$TAR".gz ]; then
                echo -e "\nINFO: Comprobando backup...\n"
                if [ "$2" == "full" ]; then
                        CAMBIOS=$(tar -tf "$TAR".gz | wc -l)
                        echo -e "\nSe han realizado $CAMBIOS cambios - $(date "+[%x %X]")\n"
                elif [ "$2" == "diff" ]; then
                        CAMBIOS=$(tar -tf "$TAR".gz | wc -l)
                        echo -e "\nSe han realizado $CAMBIOS cambios - $(date "+[%x %X]")\n"
                elif [ "$2" == "inc" ]; then
                        CAMBIOS=$(tar -tf "$TAR".gz | wc -l)
                        echo -e "\nSe han realizado $CAMBIOS cambios - $(date "+[%x %X]")\n"
                fi
                gzip -vt "$TAR".gz
                if [ "$?" -ne "0" ]; then
                        ESTADO="ERROR"
                else
                        echo -e "\nLa copia $TAR.gz ha finalizado correctamente - $(date "+[%x %X]")\n"
                fi
        fi
}

if [[ ! -n "$1" || ! -n "$2" ]]; then
        helpBackup
fi

# VAR's
. ~/.profile
DIR="$2"
BASE="$2/../backups"
MOUNTPOINT="$2/../s3"
DESTINO="$MOUNTPOINT"
EXT="$(date +%d%b%y.tar)"
DIA=$(date | cut -d" " -f1)
SNAP="$BASE/history"
LOGS="$BASE/log"
LOG="$BASE/log/backup.log"
OLDLOGS="$BASE/log/old"

if [ ! -d "$LOGS" ]; then
        mkdir -p "$LOGS" &>>/dev/null
        if [ "$?" -ne "0" ]; then
                echo -e "No es posible escribir en el directorio base ($BASE). \nEl directorio $LOGS no puede ser creado.\nInterrumpiendo ejecución...\n"
                exit 1
        fi
fi

# LOG
exec &>"$LOG"

for dir in "$DESTINO" "$BASE" "$SNAP" "$OLDLOGS"; do
        test -d "$dir" || mkdir -p "$dir" &>>/dev/null
        if [ "$?" -ne "0" ]; then
                case "$dir" in
                "$DESTINO") MSG="No se pudo crear el directorio $DESTINO. Abortado." ;;
                "$BASE") MSG="No se pudo crear el directorio $BASE. Abortado." ;;
                "$SNAP") MSG="No se pudo crear el directorio $SNAP. Abortado." ;;
                "$OLDLOGS") MSG="No se pudo crear el directorio $OLDLOGS. Abortado." ;;
                esac
        fi
done

# LOG
exec &>"$LOG"

# MAIN
NOMBRE=$(echo "$DIR" | egrep -o "[^/]+$")
HIST="$SNAP"/"$NOMBRE".snap

if [ ! -e "$HIST" ] || [ "$1" == "full" ]; then
        echo -e "-----------------------------"
        echo -e "La copia para $DIR será full.\n"
        TIPO="full"
elif [ "diff" == "$1" ]; then
        TIPO="diff"
elif [ "inc" == "$1" ]; then
        TIPO="inc"
else
        "NOT FOUND"
fi

case "$TIPO" in
full)
        PREFIJO="full"
        TAR="$DESTINO"/"$PREFIJO"_"$NOMBRE"_"$EXT"
        compruebaDir "$DIR"
        if [ -f "$HIST" ]; then
                rm "$HIST"
                echo -e "Archivo histórico $HIST eliminado\n"
        fi
        echo -e "Iniciando FullBackup para $DIR\t $(date "+[%x %X]")\n"
        cd "$DIR"
        if tar -cpvWf "$TAR" -g "$HIST" *; then
                gzip -8f "$TAR"
                checkBackup "$TAR".gz "full"
        else
                checkBackup "error"
        fi

        if [ "$ESTADO" == "OK" ]; then
                echo -e "Buscando backups de $DIR anteriores a este último full..."
                BACKOLD=$(find "$DESTINO" -maxdepth 1 -type f -mmin +600 -name *_"$NOMBRE"_*.tar.gz | wc -l)
                if [ "$BACKOLD" -eq "0" ]; then
                        echo -e "No se han encontrado backups antiguos de $DIR para eliminar.\n"
                else
                        find "$DESTINO" -maxdepth 1 -type f -mmin +600 -name *_"$NOMBRE"_* -exec rm -f {} \; && echo -e "Backups anteriores encontrados y eliminados.\n"
                fi
        else
                echo -e "El FullBackup anterior no será eliminado. Esta copia ha finalizado con errores\n"
                FIN="ERROR"
        fi
        ;;
inc)
        PREFIJO="inc"
        TAR="$DESTINO"/"$PREFIJO"_"$NOMBRE"_"$EXT"
        compruebaDir "$DIR"
        echo -e "----------------------------------------------------------------------------------------------"
        echo -e "Iniciando backup INCREMENTAL para $DIR $(date "+[%x %X]")\n"
        cd "$DIR"
        if tar -cpvWf "$TAR" -g "$HIST" *; then
                gzip -8f "$TAR"
                checkBackup "$TAR".gz "inc"
        else
                checkBackup "error"
                FIN="ERROR"
        fi
        ;;
diff)
        PREFIJO="diff"
        TAR="$DESTINO"/"$PREFIJO"_"$NOMBRE"_"$EXT"
        TARFULL=$(ls -l "$DESTINO" | grep full_"$NOMBRE" | awk '{printf $NF}')
        FECHA=$(date -r "$DESTINO"/"$TARFULL" "+%F %H:%M")
        compruebaDir "$DIR"
        echo -e "----------------------------------------------------------------------------------------------"
        echo -e "Iniciando backup DIFERENCIAL para $DIR $(date "+[%x %X]")\n"
        cd "$DIR"
        if tar -cpvzf "$TAR" * -N "$FECHA"; then 
                gzip -8f "$TAR"
                checkBackup "$TAR".gz "diff"
        else
                checkBackup "error"
                FIN="ERROR"
        fi
        ;;
esac

cp "$LOG" "$OLDLOGS"/backup_"$(date +%d%b%y)".log