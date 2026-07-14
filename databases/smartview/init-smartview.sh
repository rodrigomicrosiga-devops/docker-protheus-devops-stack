#!/bin/sh
# ==============================================================================
# TOTVS SmartView - Multi-SGBD Dynamic Provisioner (Postgres, MSSQL & Oracle)
# Author: Rodrigo dos Santos Brandão
# Version: 2.3.0 (POSIX Compliant)
# ==============================================================================
set -e

# 🔑 Conversão POSIX universal de minúsculo para maiúsculo usando 'tr'
SGBD_UPPER=$(echo "$SGBD" | tr '[:lower:]' '[:upper:]')

echo "🚀 [SmartView Init] Iniciando provisionamento dinâmico do banco..."
echo "📊 SGBD Selecionado: [$SGBD_UPPER]"

case "$SGBD" in
    "mssql")
        echo "⏳ [SmartView Init] Aguardando o SQL Server (protheus_mssql:1433) ficar operacional..."
        until sqlcmd -S protheus_mssql -U sa -P "$MSSQL_SA_PASSWORD" -Q "SELECT 1" -C -No > /dev/null 2>&1; do
            sleep 2
        done

        echo "⚙️ [SmartView Init] Executando script de provisionamento no MSSQL..."
        sqlcmd -S protheus_mssql -U sa -P "$MSSQL_SA_PASSWORD" \
            -i /opt/smartview_init/mssql/init-smartview.sql \
            -v SV_DBNAME="$SV_DBNAME" SV_USER="$SV_USER" SV_PASS="$SV_PASS" \
            -C -No
        echo "✅ [SmartView Init] Estrutura do SmartView provisionada com sucesso no SQL Server!"
        ;;

    "postgres")
        echo "⏳ [SmartView Init] Aguardando o Postgres (protheus_postgres:5432) ficar operacional..."
        export PGPASSWORD=${POSTGRES_ROOT_PASSWORD}
        until psql -h protheus_postgres -U "${POSTGRES_ROOT_USER}" -d "${POSTGRES_ROOT_USER}" -c "SELECT 1" > /dev/null 2>&1; do
            sleep 2
        done

        echo "⚙️ [SmartView Init] Executando script de provisionamento no Postgres..."
        psql -h protheus_postgres -U "${POSTGRES_ROOT_USER}" -d "${POSTGRES_ROOT_USER}" \
             -c "SET custom.sv_user = '${SV_USER}'; SET custom.sv_pass = '${SV_PASS}'; SET custom.sv_dbname = '${SV_DBNAME}';" \
             -f /opt/smartview_init/postgres/init-smartview.sql
        echo "✅ [SmartView Init] Estrutura do SmartView provisionada com sucesso no Postgres!"
        ;;

    "oracle")
        echo "⏳ [SmartView Init] Aguardando o Oracle (protheus_oracle:1521) ficar operacional..."
        until echo "EXIT" | sqlplus -S sys/"$ORACLE_ROOT_PASSWORD"@protheus_oracle:1521/ORCLPDB1 as sysdba > /dev/null 2>&1; do
            sleep 5
        done

        echo "⚙️ [SmartView Init] Executando script de provisionamento no Oracle..."
        sqlplus -S sys/"$ORACLE_ROOT_PASSWORD"@protheus_oracle:1521/ORCLPDB1 as sysdba <<EOF
            DEFINE SV_USER = '${SV_USER}';
            DEFINE SV_PASS = '${SV_PASS}';
            @/opt/smartview_init/oracle/init-smartview.sql
            EXIT;
EOF
        echo "✅ [SmartView Init] Estrutura do SmartView provisionada com sucesso no Oracle!"
        ;;

    *)
        echo "❌ [SmartView Init] SGBD desconhecido ou não configurado para inicialização: '$SGBD'"
        exit 1
        ;;
esac