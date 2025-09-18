# 🚀 User Tracking Analysis Guide

Este guia explica como executar as análises de tracking de usuários no RJ SuperApp Data Lake.

## 📋 Pré-requisitos

- Acesso ao BigQuery com datasets `rj-superapp.brutos_rmi` e `rj-superapp.brutos_go`
- Permissões de leitura nos datasets
- Conhecimento básico de SQL

## 🎯 Casos de Uso Principais

### 1. Análise de Jornada Cross-Platform
```sql
-- Execute no BigQuery
-- Identifica usuários presentes em ambas as plataformas
WITH rmi_users AS (
    SELECT DISTINCT cpf FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
    WHERE cpf IS NOT NULL
),
go_users AS (
    SELECT DISTINCT cpf FROM `rj-superapp.brutos_go.inscricoes`
    WHERE cpf IS NOT NULL
)
SELECT 
    'Ambas Plataformas' as segmento,
    COUNT(*) as usuarios
FROM rmi_users r
WHERE r.cpf IN (SELECT cpf FROM go_users);
```

### 2. Análise de Engajamento
```sql
-- Taxa de conclusão por curso
SELECT 
    c.titulo,
    c.modalidade,
    COUNT(*) as total_inscricoes,
    COUNT(i.concluded_at) as total_conclusoes,
    ROUND(COUNT(i.concluded_at) * 100.0 / COUNT(*), 2) as taxa_conclusao_pct
FROM `rj-superapp.brutos_go.inscricoes` i
JOIN `rj-superapp.brutos_go.cursos` c ON i.curso_id = c.id
GROUP BY c.titulo, c.modalidade
ORDER BY taxa_conclusao_pct DESC;
```

### 3. Análise Temporal
```sql
-- Atividade por dia da semana
SELECT 
    EXTRACT(DAYOFWEEK FROM PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp)) as dia_semana,
    COUNT(*) as total_eventos,
    COUNT(DISTINCT cpf) as usuarios_unicos
FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
WHERE timestamp IS NOT NULL
GROUP BY dia_semana
ORDER BY dia_semana;
```

## 📊 Métricas Importantes

| Métrica | Descrição | Query Principal |
|---------|-----------|-----------------|
| **Taxa de Conversão** | % usuários que concluem cursos | Seção 8.1 |
| **Engajamento Cross-Platform** | Usuários ativos em ambas plataformas | Seção 5.1 |
| **Retenção** | Usuários ativos por período | Seção 11.5 |
| **Opt-out Rate** | Taxa de descadastro por canal | Seção 3.1 |


## ⚠️ Considerações Importantes

- **Timestamps RMI**: Formato STRING, requer parsing
- **CPF**: Campo chave universal para ligação
- **Performance**: Use LIMIT para testes iniciais

## 📈 Interpretando Resultados

### Segmentação de Usuários
- **Alto Engajamento**: 10+ ações totais
- **Médio Engajamento**: 3-9 ações totais  
- **Baixo Engajamento**: 1-2 ações totais

### Plataformas
- **RMI**: Sistema principal de gestão
- **GO**: Plataforma educacional
- **BOTH**: Usuários multi-plataforma (maior valor)

## 🔄 Atualizações Automáticas

Para análises recorrentes, considere:
- Agendar queries no BigQuery
- Criar alertas de qualidade de dados
- Implementar dashboards no Looker/Data Studio
