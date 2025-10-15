# RJ SuperApp Data Lake Analysis

[![GitHub](https://img.shields.io/badge/GitHub-Repository-blue)](https://github.com/username/rj-superapp-datalake-analysis)
[![BigQuery](https://img.shields.io/badge/BigQuery-Data%20Warehouse-orange)](https://cloud.google.com/bigquery)
[![Mermaid](https://img.shields.io/badge/Mermaid-Diagrams-green)](https://mermaid-js.github.io/mermaid/)
[![SQL](https://img.shields.io/badge/SQL-Analysis-red)](https://cloud.google.com/bigquery/docs/reference/standard-sql)

## � Visão Geral

Este repositório contém uma análise exploratória completa do **Data Lake do RJ SuperApp**, focada no **tracking de usuários** e **análise cross-platform**. O projeto documenta 9 tabelas distribuídas em 2 datasets principais, fornecendo insights sobre jornada do usuário, engajamento educacional e efetividade de comunicação.

### 🎯 Objetivos Principais
- **Tracking de Usuários**: Análise completa da jornada cross-platform
- **Engajamento Educacional**: Métricas de conversão e retenção
- **Efetividade de Comunicação**: Análise de opt-in/opt-out por canal
- **Segmentação de Usuários**: Beta vs regular, multi vs single-platform

## 📁 Estrutura do Repositório

```
rj-superapp-datalake-analysis/
├── README.md                 # Este arquivo
├── docs/                     # Documentação
│   ├── data-lake-inventory.md    # Inventário completo das tabelas
│   ├── architecture-guide.md     # Guia de arquitetura
│   └── user-tracking-guide.md    # Guia de tracking de usuários
├── sql/                      # Queries SQL
│   ├── user-tracking-analysis.sql    # Análises de tracking
│   ├── data-quality-checks.sql       # Validações de qualidade
│   └── materialized-views.sql        # Views para analytics
├── diagrams/                 # Diagramas e visualizações
│   ├── architecture-flowchart.mmd    # Fluxograma de arquitetura
│   ├── entity-relationship.mmd       # Diagrama ERD
│   └── README.md                     # Como visualizar os diagramas
└── data/                     # Schemas e metadados
    ├── table-schemas.csv             # Esquemas das tabelas
    └── sample-queries.md             # Queries de exemplo
```

## 🚀 Quick Start

### 1. Exploração do Inventário
```bash
# Visualizar o inventário completo das tabelas
cat docs/data-lake-inventory.md
```

### 2. Executar Análises SQL
```sql
-- Exemplo: Usuários únicos por plataforma
SELECT 'RMI' as platform, COUNT(DISTINCT cpf) as users
FROM `rj-superapp.brutos_rmi.rmi_avatars`
UNION ALL
SELECT 'GO' as platform, COUNT(DISTINCT cpf) as users  
FROM `rj-superapp.brutos_go.inscricoes`;
```

### 3. Visualizar Diagramas
Os diagramas estão em formato Mermaid. Para visualizá-los:
- Use o [Mermaid Live Editor](https://mermaid.live/)
- Extensões do VS Code para Mermaid
- GitHub renderiza automaticamente

## 📊 Principais Descobertas

### Estrutura dos Dados
- **9 tabelas** distribuídas em 2 datasets
- **CPF como chave universal** para linking cross-platform
- **Tracking temporal** em múltiplos formatos
- **Eventos de auditoria** completos no sistema RMI

### Oportunidades de Analytics
- **Jornada cross-platform** (RMI → GO)
- **Segmentação de usuários** por engajamento
- **Análise de conversão educacional**
- **Padrões de comunicação** e opt-in/opt-out

### Datasets Principais

#### 🔧 brutos_rmi (Sistema Principal)
- `rmi_audit_logs` - Logs de auditoria e ações
- `rmi_avatars` - Perfis completos dos usuários
- `rmi_opt_in_history` - Histórico de consentimento
- `rmi_beta_groups` - Grupos de teste
- `rmi_phone_cpf_mappings` - Mapeamentos telefone-CPF
- `rmi_self_declared` - Dados autodeclarados
- `rmi_users_config` - Configurações de usuários

#### 🎓 brutos_go (Plataforma Educacional)
- `cursos` - Catálogo de cursos
- `inscricoes` - Inscrições e jornada educacional

## 🔍 Casos de Uso Implementados

### 1. **Tracking de Usuários**
- Análise de eventos de auditoria
- Padrões de opt-in/opt-out por canal
- Jornada educacional completa

### 2. **Analytics Cross-Platform**
- Usuários presentes em ambas plataformas
- Conversão de RMI para GO
- Engajamento por segmento

### 3. **Business Intelligence**
- Taxa de conclusão de cursos
- Efetividade de canais de comunicação
- Análise temporal de atividade

### 4. **Data Quality**
- Validação de CPFs
- Consistência temporal
- Identificação de duplicatas

## 🛠️ Tecnologias Utilizadas

- **BigQuery** - Data warehouse
- **Airbyte** - Pipeline ETL
- **Mermaid** - Diagramação
- **SQL** - Análise de dados
- **Markdown** - Documentação

## 📈 Métricas Principais

| Métrica | Descrição | Query Localização |
|---------|-----------|-------------------|
| **Usuários Únicos** | Total por plataforma | `sql/user-tracking-analysis.sql` |
| **Taxa de Conversão** | RMI → GO | `sql/user-tracking-analysis.sql` |
| **Engajamento** | Ações por usuário | `sql/user-tracking-analysis.sql` |
| **Conclusão de Cursos** | % de conclusão | `sql/user-tracking-analysis.sql` |

## 🔐 Considerações de Segurança

- **LGPD Compliance** - Dados pessoais identificados
- **Anonimização** - Recomendada para analytics agregadas
- **Auditoria** - Tracking completo implementado
- **Acesso Controlado** - Dados sensíveis de saúde e assistência social

**Data:** Setembro 2025  
**Versão:** 1.0  

---

**Última atualização:** 18 de setembro de 2025
