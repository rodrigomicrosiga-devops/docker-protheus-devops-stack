# 🎛️ TOTVS Protheus - Microservices DevOps Stack Orchestrator

Este repositório é um componente isolado da arquitetura TOTVS Protheus Modern DevOps [https://github.com/rodrigomicrosiga-devops/totvs-protheus-modern-devops], e centraliza a orquestração global do ecossistema distribuído do ERP TOTVS Protheus na organização **`rodrigomicrosiga-devops`**. Ele consome as imagens imutáveis geradas pelas fábricas de CI/CD do Docker Hub e consolida a conectividade de rede, persistência volumétrica e gerência de ciclo de vida de todo o barramento do ERP com um único comando.

---

## 🏗️ Topologia de Redes e Dependências de Subida

A stack gerencia as dependências internas do ecossistema através de sondas de saúde (*healthchecks*), garantindo que as camadas de persistência e validação estejam prontas antes do acoplamento dos tradutores e servidores de aplicação.

```mermaid
graph TD
    %% Camada de Persistência e Licença
    A[(protheus_postgres)] -->|Health Check| C{Motores Prontos?}
    B[protheus_license] -->|Health Check| C
    
    %% Camada de Conectividade
    C -->|Sim| D[protheus_dbaccess]
    
    %% Camada de Entrega de Interface
    E[protheus_webapp:10.2.0] -->|Popula Volume| F[(Volume: webapp_shared_module)]
    
    %% Camada do AppServer Core
    D -->|Health Check OK| G[protheus_appserver_core]
    F -->|Montagem Read-Only| G
    
    %% Inicialização Final
    G --> H[🚀 ERP ONLINE - Porta 5000 / WebApp Ativa]

    %% Estilização
    style A fill:#bbf,stroke:#333,stroke-width:2px
    style B fill:#bbf,stroke:#333,stroke-width:2px
    style D fill:#f9f,stroke:#333,stroke-width:2px
    style E fill:#f9f,stroke:#333,stroke-width:2px
    style G fill:#bfb,stroke:#333,stroke-width:2px
```

### 🚀 Como Executar a Stack Completa

Para levantar o ecossistema completo amarrando a gerência dinâmica de variáveis, execute o comando apontando o arquivo de ambiente:

```bash
# Inicialização global da infraestrutura distribuída do Protheus
docker compose --env-file .env.protheus --profile postgres up -d
```


