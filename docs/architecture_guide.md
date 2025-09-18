# 🏗️ Architecture Guide

Esta documentação descreve a arquitetura do Data Lake RJ SuperApp e como interpretar os diagramas.

## 📊 Visão Geral da Arquitetura

O data lake do RJ SuperApp é composto por:

- **2 Datasets principais**: `brutos_rmi` (7 tabelas) e `brutos_go` (2 tabelas)
- **Pipeline ETL**: Airbyte para extração e carregamento
- **Chave Universal**: CPF para linking cross-platform
- **Tracking Cross-Platform**: Jornada unificada do usuário

## 🔄 Fluxo de Dados

### 1. Fontes de Dados
- **Sistema RMI**: Gestão de usuários, perfis, auditoria
- **Plataforma GO**: Cursos e educação continuada

### 2. Camada ETL
- **Airbyte**: Pipeline de Extract, Transform, Load
- **Frequência**: Tempo real/Near real-time
- **Campos Airbyte**: `_airbyte_extracted_at`, `_airbyte_raw_id`

### 3. Armazenamento
- **BigQuery**: Data warehouse principal
- **Particionamento**: Por data de extração
- **Esquema**: Raw data + campos de auditoria

## 🔑 Identificadores e Chaves

### Chave Universal: CPF
- Liga todas as tabelas do sistema
- Permite tracking cross-platform
- Presente em 8 das 9 tabelas

### Chaves Secundárias
- **Email**: Identificação alternativa
- **Telefone**: Canal de comunicação
- **IDs Internos**: `_id`, `curso_id`

## 📈 Camada de Tracking

### Eventos RMI (Sistema Principal)
- **Audit Logs**: Todas as mudanças de dados
- **Opt-in/Opt-out**: Consentimento para comunicação  
- **Beta Groups**: Participação em testes
- **Profile Updates**: Modificações de perfil

### Eventos GO (Educacional)
- **Inscrições**: Entrada em cursos
- **Progressão**: Andamento educacional
- **Conclusões**: Finalização com certificado
- **Gestão de Cursos**: Ofertas educacionais

## 🎯 Casos de Uso Analytics

### 1. Análise de Engajamento
- Taxa de conversão educacional
- Padrões temporais de uso
- Efetividade de canais de comunicação

### 2. Segmentação de Usuários
- **Beta vs Regular**: Usuários em teste vs produção
- **Multi vs Single Platform**: Cross-platform vs único sistema
- **Perfil Demográfico**: Baseado em dados do RMI

### 3. Funil de Conversão
- **Inscrição → Conclusão**: Jornada educacional completa
- **Tempo Médio**: Duração típica dos cursos
- **Taxa de Abandono**: Identificação de drop-offs

### 4. Comunicação Efetiva
- **Opt-in/Opt-out Patterns**: Preferências de contato
- **Canal Preferencial**: SMS, WhatsApp, Email
- **Resposta a Campanhas**: Efetividade das comunicações

## ⏰ Dimensão Temporal

### Formatos de Timestamp
- **RMI**: STRING format (`'YYYY-MM-DD HH:MM:SS'`)
- **GO**: TIMESTAMP/DATETIME nativo
- **Airbyte**: TIMESTAMP UTC

### Campos Temporais Principais
- `timestamp` (audit logs)
- `enrolled_at`, `concluded_at` (educacional)
- `created_at`, `updated_at` (gerais)
- `_airbyte_extracted_at` (pipeline)

## 🔍 Qualidade dos Dados

### Validações Recomendadas
- **Completude CPF**: Campo crítico para linking
- **Consistência Temporal**: Ordem lógica de eventos
- **Duplicatas**: Verificação de registros únicos
- **Integridade Referencial**: Relacionamentos válidos

### Monitoramento
- Volume diário de registros
- Latência do pipeline Airbyte
- Taxa de nulos em campos críticos
- Alertas de anomalias

## 🚀 Performance e Otimização

### Índices Recomendados
- Particionamento por `_airbyte_extracted_at`
- Clustering por `cpf`
- Índices em `timestamp`, `curso_id`

### Views Materializadas
- **USER_JOURNEY**: Consolidação cross-platform
- **Daily/Monthly Aggregations**: Métricas pré-calculadas
- **Retention Cohorts**: Análise de retenção

## 🔐 Segurança e Governança

### Dados Sensíveis
- **CPF**: PII crítico, requer masking
- **Endereços**: Informações pessoais
- **Histórico Médico**: Dados de saúde

### Conformidade
- **LGPD**: Lei Geral de Proteção de Dados
- **Audit Trail**: Rastreabilidade completa
- **Consentimento**: Tracking de opt-in/opt-out

## 📋 Próximos Passos

1. **Implementar Data Quality Checks**
2. **Criar Dashboards Executivos**
3. **Desenvolver Alertas Automáticos**
4. **Expandir Tracking para Outros Sistemas**