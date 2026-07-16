#!/bin/bash
# ==============================================================================
# TOTVS Protheus DevOps Stack - Unified Environment Controller (CLI)
# Author: Rodrigo dos Santos Brandão
# Version: 2.4.0 (MSSQL / Postgres / Oracle Supported - Printer Component Added)
# ==============================================================================
set -e

# Captura os argumentos e sanitiza para minúsculo
SGBD=$(echo "$1" | tr '[:upper:]' '[:lower:]')
SERVICE=$(echo "$2" | tr '[:upper:]' '[:lower:]')
COMMAND=$(echo "$3" | tr '[:upper:]' '[:lower:]')

export SGBD  # <-- Torna a variável visível para o ecossistema do Docker Compose

# Inverte variáveis caso o usuário use a sintaxe clássica "down" no segundo bloco
if [ "$SERVICE" = "down" ]; then
    COMMAND="down"
    SERVICE=""
fi

# ------------------------------------------------------------------------------
# INTERCEPTOR: Destruição ou Parada Total da Infraestrutura (--profile *)
# ------------------------------------------------------------------------------
if [ "$SGBD" = "down" ]; then
    echo "🛑 [DevOps] Derrubando a infraestrutura global e limpando volumes persistentes..."
    ENV_ARG=""
    [ -f ".env.protheus" ] && ENV_ARG="--env-file .env.protheus"
    docker compose $ENV_ARG --profile "*" down -v 2>/dev/null
    echo "✅ [DevOps] Ambiente totalmente limpo com segurança!"
    exit 0
fi

# Validação do SGBD escolhido para a stack
if [ -z "$SGBD" ] || { [ "$SGBD" != "postgres" ] && [ "$SGBD" != "mssql" ] && [ "$SGBD" != "oracle" ]; }; then
    echo "❌ Uso correto: ./run.sh [postgres | mssql | oracle | down] [serviço] [comando]"
    echo "📊 Serviços Contínuos:  core | rest | telnet | smartview | webapp | printer"
    echo "⚡ Serviços Efêmeros:   worker | compile | upddistr"
    echo "🔧 Ações Especiais:     update"
    echo "👉 Exemplo Base:        ./run.sh mssql"
    echo "👉 Exemplo Atualizar:   ./run.sh postgres update printer"
    echo "👉 Exemplo Desligar:    ./run.sh mssql down"
    exit 1
fi

# Validação do arquivo especialista do banco (.env.mssql, .env.postgres, etc)
ENV_SPEC=".env.$SGBD"
if [ ! -f "$ENV_SPEC" ]; then
    echo "❌ Erro crítico: O arquivo de ambiente especialista $ENV_SPEC não foi localizado!"
    exit 1
fi

# 🔑 MAPEAMENTO DINÂMICO DOS SERVIÇOS DE BANCO CONFORME COMPOSE
if [ "$SGBD" = "mssql" ]; then
    DB_SERVICE_NAME="mssql_db"
elif [ "$SGBD" = "postgres" ]; then
    DB_SERVICE_NAME="postgres_db"
elif [ "$SGBD" = "oracle" ]; then
    DB_SERVICE_NAME="oracle_db"
fi

# Validação e injeção do arquivo específico do SmartView se ele for acionado
ENV_SMARTVIEW=""
if [ "$SERVICE" = "smartview" ] && [ -f ".env.smartview" ]; then
    ENV_SMARTVIEW="--env-file .env.smartview"
fi

# Validação de escopo de serviços aceitos pela CLI
if [ -n "$SERVICE" ] && [ "$SERVICE" != "down" ] && [ "$SERVICE" != "update" ]; then
    if [ "$SERVICE" != "core" ] && [ "$SERVICE" != "rest" ] && [ "$SERVICE" != "telnet" ] && [ "$SERVICE" != "smartview" ] && [ "$SERVICE" != "webapp" ] && [ "$SERVICE" != "printer" ] && [ "$SERVICE" != "worker" ] && [ "$SERVICE" != "upddistr" ] && [ "$SERVICE" != "compile" ]; then
        echo "❌ Serviço desconhecido: $SERVICE"
        echo "👉 Use: core, rest, telnet, smartview, webapp, printer, worker, upddistr ou compile"
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# PROCESSAMENTO DE COMANDO: DOWN ISOLADO
# ------------------------------------------------------------------------------
if [ "$COMMAND" = "down" ]; then
    if [ -n "$SERVICE" ]; then
        echo "🔻 [DevOps] Desligando especificamente o contêiner: [appserver_$SERVICE]..."
        docker compose --env-file .env.protheus $ENV_SMARTVIEW --env-file "$ENV_SPEC" stop appserver_$SERVICE 2>/dev/null || docker compose --env-file .env.protheus $ENV_SMARTVIEW --env-file "$ENV_SPEC" stop $SERVICE
        docker compose --env-file .env.protheus $ENV_SMARTVIEW --env-file "$ENV_SPEC" rm -f appserver_$SERVICE 2>/dev/null || docker compose --env-file .env.protheus $ENV_SMARTVIEW --env-file "$ENV_SPEC" rm -f $SERVICE
    else
        echo "🔻 [DevOps] Desligando a stack base sob o banco [${SGBD^^}]..."
        docker compose --env-file .env.protheus --env-file "$ENV_SPEC" --profile "$SGBD" down
    fi
    exit 0
fi

# ------------------------------------------------------------------------------
# PROCESSAMENTO DE COMANDO: ATUALIZAÇÃO À QUENTE DE CONTAINER (UPDATE EXCLUSIVO)
# ------------------------------------------------------------------------------
if [ "$SERVICE" = "update" ]; then
    TARGET_UPDATE=$(echo "$3" | tr '[:upper:]' '[:lower:]')
    
    if [ "$TARGET_UPDATE" != "core" ] && [ "$TARGET_UPDATE" != "rest" ] && [ "$TARGET_UPDATE" != "telnet" ] && [ "$TARGET_UPDATE" != "smartview" ] && [ "$TARGET_UPDATE" != "webapp" ] && [ "$TARGET_UPDATE" != "printer" ]; then
        echo "❌ Uso correto para atualização: ./run.sh $SGBD update [core | rest | telnet | smartview | webapp | printer]"
        exit 1
    fi

    # Mapeamento do nome exato do serviço no Docker Compose
    if [ "$TARGET_UPDATE" = "webapp" ]; then
        COMPOSE_SERVICE_NAME="protheus_webapp"
    elif [ "$TARGET_UPDATE" = "printer" ]; then
        COMPOSE_SERVICE_NAME="protheus_printer"
    elif [ "$TARGET_UPDATE" = "smartview" ]; then
        COMPOSE_SERVICE_NAME="smartview"
    else
        COMPOSE_SERVICE_NAME="appserver_$TARGET_UPDATE"
    fi

    echo "🕵️  [DevOps] Mapeando estado atual da malha Protheus para isolar a atualização..."
    
    CORE_ACTIVE=$(docker compose --env-file .env.protheus --env-file "$ENV_SPEC" ps --status running --format json | grep -q "appserver_core" && echo "true" || echo "false")
    REST_ACTIVE=$(docker compose --env-file .env.protheus --env-file "$ENV_SPEC" ps --status running --format json | grep -q "appserver_rest" && echo "true" || echo "false")
    TELNET_ACTIVE=$(docker compose --env-file .env.protheus --env-file "$ENV_SPEC" ps --status running --format json | grep -q "appserver_telnet" && echo "true" || echo "false")
    SMART_ACTIVE=$(docker compose --env-file .env.protheus --env-file "$ENV_SPEC" ps --status running --format json | grep -q "smartview" && echo "true" || echo "false")
    WEB_ACTIVE=$(docker compose --env-file .env.protheus --env-file "$ENV_SPEC" ps --status running --format json | grep -q "protheus_webapp" && echo "true" || echo "false")
    PRINTER_ACTIVE=$(docker compose --env-file .env.protheus --env-file "$ENV_SPEC" ps --status running --format json | grep -q "protheus_printer" && echo "true" || echo "false")

    echo "🛑 [DevOps] Modo de Manutenção: Pausando serviços síncronos para evitar travamentos de arquivos..."
    [ "$CORE_ACTIVE" = "true" ]   && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" stop appserver_core
    [ "$REST_ACTIVE" = "true" ]   && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" stop appserver_rest
    [ "$TELNET_ACTIVE" = "true" ] && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" stop appserver_telnet
    [ "$SMART_ACTIVE" = "true" ]  && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" stop protheus_smartview 2>/dev/null || true
    [ "$WEB_ACTIVE" = "true" ]    && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" stop protheus_webapp 2>/dev/null || true
    [ "$PRINTER_ACTIVE" = "true" ] && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" stop protheus_printer 2>/dev/null || true

    echo "⚡ [DevOps] Atualizando o container [$COMPOSE_SERVICE_NAME] de forma isolada..."
    docker compose --env-file .env.protheus $ENV_SMARTVIEW --env-file "$ENV_SPEC" up -d --no-deps "$COMPOSE_SERVICE_NAME"
    
    echo "🔄 [DevOps] Restabelecendo o ecossistema ativo anterior com a nova versão..."
    [ "$WEB_ACTIVE" = "true" ]    && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up -d protheus_webapp
    [ "$PRINTER_ACTIVE" = "true" ] && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up -d protheus_printer
    [ "$CORE_ACTIVE" = "true" ]   && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up -d appserver_core
    [ "$REST_ACTIVE" = "true" ]   && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up -d appserver_rest
    [ "$TELNET_ACTIVE" = "true" ] && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up -d appserver_telnet
    [ "$SMART_ACTIVE" = "true" ]  && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up -d protheus_smartview 2>/dev/null || true

    echo "✅ [DevOps] Atualização exclusiva realizada e ecossistema restaurado!"
    echo "📊 [DevOps] Estado atual da malha de contêineres:"
    docker compose --env-file .env.protheus --env-file "$ENV_SPEC" --profile "*" ps
    exit 0
fi

# ------------------------------------------------------------------------------
# CENÁRIO ESPECIAL: ESTEIRA ELÁSTICA SÍNCRONA (WORKER, COMPILER, UPDDISTR)
# ------------------------------------------------------------------------------
if [ "$SERVICE" = "worker" ] || [ "$SERVICE" = "compile" ] || [ "$SERVICE" = "upddistr" ]; then
    echo "🕵️  [DevOps] Mapeando estado atual dos contêineres Protheus ativos para garantir exclusividade..."
    
    CORE_ACTIVE=$(docker compose --env-file .env.protheus --env-file "$ENV_SPEC" ps --status running --format json | grep -q "appserver_core" && echo "true" || echo "false")
    REST_ACTIVE=$(docker compose --env-file .env.protheus --env-file "$ENV_SPEC" ps --status running --format json | grep -q "appserver_rest" && echo "true" || echo "false")
    TELNET_ACTIVE=$(docker compose --env-file .env.protheus --env-file "$ENV_SPEC" ps --status running --format json | grep -q "appserver_telnet" && echo "true" || echo "false")
    SMART_ACTIVE=$(docker compose --env-file .env.protheus --env-file "$ENV_SPEC" ps --status running --format json | grep -q "smartview" && echo "true" || echo "false")

    echo "🛑 [DevOps] Isolando RPO: Interrompendo temporariamente serviços de leitura concorrente..."
    [ "$CORE_ACTIVE" = "true" ]   && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" stop appserver_core
    [ "$REST_ACTIVE" = "true" ]   && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" stop appserver_rest
    [ "$TELNET_ACTIVE" = "true" ] && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" stop appserver_telnet
    [ "$SMART_ACTIVE" = "true" ]  && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" stop protheus_smartview 2>/dev/null || true

    if [ "$SERVICE" = "worker" ]; then
        echo "🚀 [DevOps] Invocando Automated Deploy Worker (Modo CLI Job)..."
        set +e
        docker compose --env-file .env.protheus --env-file "$ENV_SPEC" run --rm appserver_worker
        EXEC_EXIT_CODE=$?
        set -e
    elif [ "$SERVICE" = "compile" ]; then
        echo "🚀 [DevOps] Invocando Esteira de Compilação Síncrona GitOps..."
        set +e
        docker compose --env-file .env.protheus --env-file "$ENV_SPEC" run --rm appserver_compiler
        EXEC_EXIT_CODE=$?
        set -e
    else
        echo "🚀 [DevOps] Inicializando Executor UPDDISTR Síncrono..."
        rm -f ./protheus/systemload/Result.json ./protheus/systemload/result.json
        docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up -d appserver_upddistr
        
        echo "⏳ [DevOps] Monitorando output do dicionário (Aguarde)..."
        set +e
        while true; do
            TARGET_FILE=""
            [ -f "./protheus/systemload/Result.json" ] && TARGET_FILE="./protheus/systemload/Result.json"
            [ -f "./protheus/systemload/result.json" ] && TARGET_FILE="./protheus/systemload/result.json"

            if [ -n "$TARGET_FILE" ]; then
                echo "📝 [DevOps] Resultado detectado: [$TARGET_FILE]"
                cat "$TARGET_FILE" && echo ""
                grep -q "success" "$TARGET_FILE" && EXEC_EXIT_CODE=0 || EXEC_EXIT_CODE=1
                break
            fi

            CONTAINER_RUNNING=$(docker compose --env-file .env.protheus --env-file "$ENV_SPEC" ps --status running --format json | grep -q "protheus_upddistr" && echo "true" || echo "false")
            if [ "$CONTAINER_RUNNING" = "false" ] && [ -z "$TARGET_FILE" ]; then
                echo "❌ [DevOps] ERRO: Container UPDDISTR encerrou sem gerar arquivo de veredito!"
                EXEC_EXIT_CODE=1
                break
            fi
            sleep 5
        done
        set -e
        docker compose --env-file .env.protheus --env-file "$ENV_SPEC" stop appserver_upddistr rm -f appserver_upddistr 2>/dev/null || true
    fi

    echo "🔄 [DevOps] Restaurando o ecossistema de produção original..."
    [ "$CORE_ACTIVE" = "true" ]   && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up -d appserver_core
    [ "$REST_ACTIVE" = "true" ]   && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up -d appserver_rest
    [ "$TELNET_ACTIVE" = "true" ] && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up -d appserver_telnet
    [ "$SMART_ACTIVE" = "true" ]  && docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up -d protheus_smartview 2>/dev/null || true

    if [ $EXEC_EXIT_CODE -ne 0 ]; then exit 1; fi

# ------------------------------------------------------------------------------
# CENÁRIO: SERVIÇOS CONTÍNUOS (CORE, REST, TELNET, SMARTVIEW, WEBAPP, PRINTER)
# ------------------------------------------------------------------------------
else
    if [ "$SERVICE" = "smartview" ]; then
        echo "🚀 [DevOps] Acoplando a plataforma de relatórios [SMARTVIEW]..."
        docker compose --env-file .env.protheus $ENV_SMARTVIEW --env-file "$ENV_SPEC" up --no-recreate -d smartview
    elif [ "$SERVICE" = "webapp" ]; then
        echo "🚀 [DevOps] Inicializando serviço de interface SmartClient HTML [WEBAPP]..."
        docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up --no-recreate -d protheus_webapp
    elif [ "$SERVICE" = "printer" ]; then
        echo "🚀 [DevOps] Inicializando serviço do driver de relatórios [PRINTER]..."
        docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up --no-recreate -d protheus_printer
    elif [ -n "$SERVICE" ] && [ "$SERVICE" != "core" ]; then
        echo "🚀 [DevOps] Inicializando serviço especialista contínuo: [${SERVICE^^}]..."
        docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up --no-recreate -d appserver_$SERVICE
    else
        echo "🚀 [DevOps] Inicializando APENAS a infraestrutura base Protheus com banco [${SGBD^^}]..."
        docker compose --env-file .env.protheus --env-file "$ENV_SPEC" up -d \
            ${DB_SERVICE_NAME} \
            license_server \
            dbaccess \
            appserver_core \
            protheus_webapp \
            protheus_printer
    fi
fi

echo "📊 [DevOps] Estado atual da malha de contêineres:"
docker compose --env-file .env.protheus --env-file "$ENV_SPEC" --profile "*" ps