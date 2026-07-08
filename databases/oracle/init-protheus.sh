#!/bin/bash
echo "⚙️ Configurando ambiente TOTVS Protheus no Oracle 21c..."

export ORACLE_SID=ORCLCDB
export ORACLE_HOME=/opt/oracle/product/21c/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

sqlplus -s / as sysdba <<EOF
-- 1. Fixa parâmetros de inicialização de memória e limites no CDB
ALTER SYSTEM SET CURSOR_SHARING=EXACT SCOPE=BOTH;
ALTER SYSTEM SET PROCESSES=500 SCOPE=SPFILE;
ALTER SYSTEM SET SESSIONS=550 SCOPE=SPFILE;

-- Ajusta os limites estáticos de SGA e PGA para caberem confortavelmente no container e evitar Swap
ALTER SYSTEM SET MEMORY_TARGET=0 SCOPE=SPFILE;
ALTER SYSTEM SET SGA_TARGET=2G SCOPE=SPFILE;
ALTER SYSTEM SET PGA_AGGREGATE_TARGET=1G SCOPE=SPFILE;

-- Otimiza a frequência de checkpoints para aliviar o gargalo de Redo Log (LGWR switch)
ALTER SYSTEM SET FAST_START_MTTR_TARGET=30 SCOPE=BOTH;

-- 2. Chaveia explicitamente a sessão para o Pluggable Database (PDB) do Protheus
ALTER SESSION SET CONTAINER = ORCLPDB1;

-- 3. Criação da Tablespace dedicada exclusiva dentro do PDB com arquivo físico isolado
-- Se já existir devido ao volume persistido, o script apenas reportará e seguirá
CREATE TABLESPACE PROTHEUS_DATA DATAFILE '/opt/oracle/oradata/protheus_data_pdb.dbf' SIZE 1G AUTOEXTEND ON NEXT 500M MAXSIZE UNLIMITED;

-- 4. Garante a criação do Usuário Local dentro do PDB associado à Tablespace correta
CREATE USER ${DB_USER} IDENTIFIED BY "${DB_PASS}" DEFAULT TABLESPACE PROTHEUS_DATA QUOTA UNLIMITED ON PROTHEUS_DATA;

-- 5. Concessão de Privilégios locais exigidos pelo DBAccess
GRANT CONNECT, RESOURCE, DBA TO ${DB_USER};

EXIT;
EOF

echo "✅ Banco de Dados Oracle configurado e pronto para o Protheus!"