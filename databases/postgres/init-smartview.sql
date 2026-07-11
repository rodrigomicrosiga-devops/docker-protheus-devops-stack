DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_setting('custom.sv_user', true)) THEN
    EXECUTE format('CREATE USER %I WITH LOGIN ENCRYPTED PASSWORD %L', current_setting('custom.sv_user'), current_setting('custom.sv_pass'));
  END IF;
END $$;

SELECT 'CREATE DATABASE ' || current_setting('custom.sv_dbname') || ' WITH OWNER=' || current_setting('custom.sv_user') || ' ENCODING=''UTF8'''
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = current_setting('custom.sv_dbname')) \gexec

-- 🚀 CORREÇÃO DO REQUISITO 2: Concede permissão de leitura na base padrão 'postgres'
\c postgres
EXECUTE format('GRANT CONNECT ON DATABASE postgres TO %I', current_setting('custom.sv_user'));
EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', current_setting('custom.sv_user'));
EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA public TO %I', current_setting('custom.sv_user'));