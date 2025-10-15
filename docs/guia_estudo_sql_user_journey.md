# 📚 GUIA DE ESTUDO: SQL AVANÇADO E ANÁLISE DE JORNADA DE USUÁRIOS

> Material baseado nas queries do projeto RJ SuperApp Data Lake Analysis

## 📑 ÍNDICE

1. [Fundamentos SQL Avançado](#1-fundamentos-sql-avançado)
2. [Window Functions e Analytics](#2-window-functions-e-analytics)
3. [Breadcrumbs e Jornadas de Usuário](#3-breadcrumbs-e-jornadas-de-usuário)
4. [Análise de Produto e Comportamento](#4-análise-de-produto-e-comportamento)
5. [Técnicas BigQuery Específicas](#5-técnicas-bigquery-específicas)
6. [Padrões de Data Analytics](#6-padrões-de-data-analytics)
7. [Exercícios Práticos](#7-exercícios-práticos)

---

## 1. FUNDAMENTOS SQL AVANÇADO

### 1.1 Common Table Expressions (CTEs)

**Conceito**: CTEs são tabelas temporárias nomeadas que existem apenas durante a execução da query.

```sql
-- ✅ EXEMPLO BÁSICO
WITH vendas_mensais AS (
    SELECT 
        EXTRACT(MONTH FROM data_venda) as mes,
        SUM(valor) as total_vendas
    FROM vendas
    GROUP BY mes
)
SELECT * FROM vendas_mensais WHERE total_vendas > 10000;
```

**🔍 No projeto RJ SuperApp:**
```sql
-- Multiple CTEs para análise de jornada
WITH user_actions_ordered AS (
    SELECT cpf, action, timestamp,
           ROW_NUMBER() OVER (PARTITION BY cpf ORDER BY timestamp) as seq
    FROM audit_logs
),
user_action_paths AS (
    SELECT *, 
           ARRAY_AGG(action) OVER (
               PARTITION BY cpf ORDER BY seq 
               ROWS UNBOUNDED PRECEDING
           ) as path
    FROM user_actions_ordered
)
SELECT * FROM user_action_paths;
```

**💡 Casos de Uso:**
- Quebrar queries complexas em etapas lógicas
- Reutilizar sub-consultas
- Melhorar legibilidade do código
- Criar pipelines de transformação de dados

### 1.2 UNION vs UNION ALL

**Conceito**: Combinação de resultados de múltiplas queries.

```sql
-- ✅ UNION (remove duplicatas)
SELECT 'RMI' as plataforma, COUNT(*) as usuarios FROM rmi_users
UNION
SELECT 'GO' as plataforma, COUNT(*) as usuarios FROM go_users;

-- ✅ UNION ALL (mais rápido, mantém duplicatas)
SELECT 'RMI' as plataforma, COUNT(*) as usuarios FROM rmi_users
UNION ALL
SELECT 'GO' as plataforma, COUNT(*) as usuarios FROM go_users;
```

**🎯 Quando usar cada um:**
- **UNION**: Quando precisar eliminar duplicatas
- **UNION ALL**: Quando souber que não há duplicatas (mais performático)

---

## 2. WINDOW FUNCTIONS E ANALYTICS

### 2.1 ROW_NUMBER(), RANK(), DENSE_RANK()

**Conceito**: Funções para numeração e ranking dentro de partições.

```sql
-- ✅ DIFERENÇAS ENTRE AS FUNÇÕES
SELECT 
    usuario_id,
    score,
    ROW_NUMBER() OVER (ORDER BY score DESC) as row_num,
    RANK() OVER (ORDER BY score DESC) as rank_pos,
    DENSE_RANK() OVER (ORDER BY score DESC) as dense_rank_pos
FROM user_scores;

-- Resultado com scores: 100, 100, 90, 80
-- row_num: 1, 2, 3, 4
-- rank_pos: 1, 1, 3, 4  
-- dense_rank: 1, 1, 2, 3
```

**🔍 No projeto (sequenciamento de ações):**
```sql
ROW_NUMBER() OVER (
    PARTITION BY cpf 
    ORDER BY PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp)
) as action_sequence
```

### 2.2 LAG() e LEAD()

**Conceito**: Acessar valores de linhas anteriores ou posteriores.

```sql
-- ✅ ANÁLISE DE MUDANÇAS
SELECT 
    cpf,
    action,
    timestamp,
    new_value,
    LAG(new_value) OVER (PARTITION BY cpf ORDER BY timestamp) as previous_value,
    LEAD(action) OVER (PARTITION BY cpf ORDER BY timestamp) as next_action
FROM audit_logs;
```

**💡 Casos de Uso:**
- Calcular diferenças entre períodos
- Identificar mudanças de estado
- Analisar tendências sequenciais

### 2.3 ARRAY_AGG() com Window Functions

**Conceito**: Criar arrays acumulativos com window functions.

```sql
-- ✅ BREADCRUMBS ACUMULATIVOS
SELECT 
    cpf,
    action,
    timestamp,
    ARRAY_AGG(action) OVER (
        PARTITION BY cpf 
        ORDER BY timestamp 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as journey_path
FROM user_actions;
```

---

## 3. BREADCRUMBS E JORNADAS DE USUÁRIO

### 3.1 Conceito de Breadcrumbs

**Definição**: Caminho de navegação que mostra onde o usuário esteve e como chegou ao estado atual.

**🍞 Tipos de Breadcrumbs:**

#### A) **Breadcrumb Simples**
```sql
-- Mostra posição na sequência
CONCAT(action, ' (', action_sequence, ')') as breadcrumb
-- Resultado: "login (1)", "update_profile (2)", "logout (3)"
```

#### B) **Breadcrumb Completo**
```sql
-- Mostra caminho completo
ARRAY_TO_STRING(action_path_array, ' → ') as breadcrumb
-- Resultado: "login → update_profile → logout"
```

#### C) **Breadcrumb Contextual**
```sql
-- Inclui detalhes das mudanças
ARRAY_TO_STRING(
    ARRAY_AGG(CONCAT(action, ':', old_value, '→', new_value)), 
    ' ➤ '
) as detailed_breadcrumb
-- Resultado: "update:123→456 ➤ delete:456→null"
```

### 3.2 Implementação no BigQuery

**❌ O que NÃO funciona (Oracle/PostgreSQL):**
```sql
-- CTEs recursivas não suportadas no BigQuery
WITH RECURSIVE breadcrumbs AS (
    SELECT id, name, parent_id, name as path FROM categories WHERE parent_id IS NULL
    UNION ALL
    SELECT c.id, c.name, c.parent_id, CONCAT(b.path, ' → ', c.name)
    FROM categories c JOIN breadcrumbs b ON c.parent_id = b.id
)
```

**✅ Solução BigQuery:**
```sql
WITH user_journey AS (
    SELECT 
        cpf,
        action,
        timestamp,
        ROW_NUMBER() OVER (PARTITION BY cpf ORDER BY timestamp) as step,
        ARRAY_AGG(action) OVER (
            PARTITION BY cpf ORDER BY timestamp 
            ROWS UNBOUNDED PRECEDING
        ) as breadcrumb_array
    FROM audit_logs
)
SELECT 
    cpf,
    action,
    step,
    ARRAY_TO_STRING(breadcrumb_array, ' → ') as user_journey_breadcrumb
FROM user_journey;
```

### 3.3 Análise de Padrões de Jornada

```sql
-- ✅ CLASSIFICAÇÃO DE JORNADAS
WITH journey_analysis AS (
    SELECT 
        cpf,
        ARRAY_AGG(action ORDER BY timestamp) as full_journey,
        COUNT(*) as journey_length
    FROM audit_logs
    GROUP BY cpf
)
SELECT 
    cpf,
    journey_length,
    full_journey[OFFSET(0)] as first_action,
    full_journey[OFFSET(journey_length-1)] as last_action,
    CASE 
        WHEN journey_length = 1 THEN 'Single Action'
        WHEN full_journey[OFFSET(0)] = full_journey[OFFSET(journey_length-1)] 
        THEN 'Circular Journey'
        ELSE 'Linear Journey'
    END as journey_pattern
FROM journey_analysis;
```

---

## 4. ANÁLISE DE PRODUTO E COMPORTAMENTO

### 4.1 Métricas de Engajamento

#### A) **Taxa de Conversão**
```sql
SELECT 
    produto,
    COUNT(*) as total_usuarios,
    COUNT(CASE WHEN acao = 'conversao' THEN 1 END) as conversoes,
    ROUND(COUNT(CASE WHEN acao = 'conversao' THEN 1 END) * 100.0 / COUNT(*), 2) as taxa_conversao_pct
FROM user_actions
GROUP BY produto;
```

#### B) **Funil de Conversão**
```sql
WITH funil AS (
    SELECT 
        cpf,
        MAX(CASE WHEN action = 'view' THEN 1 ELSE 0 END) as visualizou,
        MAX(CASE WHEN action = 'click' THEN 1 ELSE 0 END) as clicou,
        MAX(CASE WHEN action = 'signup' THEN 1 ELSE 0 END) as se_inscreveu,
        MAX(CASE WHEN action = 'purchase' THEN 1 ELSE 0 END) as comprou
    FROM user_actions
    GROUP BY cpf
)
SELECT 
    'Step 1: View' as etapa, SUM(visualizou) as usuarios,
    ROUND(SUM(visualizou) * 100.0 / COUNT(*), 2) as taxa_pct
FROM funil
UNION ALL
SELECT 'Step 2: Click', SUM(clicou), ROUND(SUM(clicou) * 100.0 / SUM(visualizou), 2)
FROM funil WHERE visualizou = 1
UNION ALL
SELECT 'Step 3: Signup', SUM(se_inscreveu), ROUND(SUM(se_inscreveu) * 100.0 / SUM(clicou), 2)
FROM funil WHERE clicou = 1;
```

### 4.2 Análise de Coorte

```sql
-- ✅ COORTE POR MÊS DE PRIMEIRA AÇÃO
WITH first_action AS (
    SELECT 
        cpf,
        MIN(DATE(timestamp)) as primeira_acao_data,
        EXTRACT(YEAR FROM MIN(DATE(timestamp))) as coorte_ano,
        EXTRACT(MONTH FROM MIN(DATE(timestamp))) as coorte_mes
    FROM user_actions
    GROUP BY cpf
),
monthly_activity AS (
    SELECT 
        f.cpf,
        f.coorte_ano,
        f.coorte_mes,
        EXTRACT(YEAR FROM DATE(a.timestamp)) as atividade_ano,
        EXTRACT(MONTH FROM DATE(a.timestamp)) as atividade_mes
    FROM first_action f
    JOIN user_actions a ON f.cpf = a.cpf
)
SELECT 
    coorte_ano,
    coorte_mes,
    atividade_ano,
    atividade_mes,
    COUNT(DISTINCT cpf) as usuarios_ativos
FROM monthly_activity
GROUP BY coorte_ano, coorte_mes, atividade_ano, atividade_mes
ORDER BY coorte_ano, coorte_mes, atividade_ano, atividade_mes;
```

### 4.3 Análise de Churn

```sql
-- ✅ IDENTIFICAÇÃO DE USUÁRIOS EM RISCO
WITH last_activity AS (
    SELECT 
        cpf,
        MAX(DATE(timestamp)) as ultima_atividade,
        COUNT(*) as total_acoes
    FROM user_actions
    GROUP BY cpf
)
SELECT 
    cpf,
    ultima_atividade,
    total_acoes,
    DATE_DIFF(CURRENT_DATE(), ultima_atividade, DAY) as dias_sem_atividade,
    CASE 
        WHEN DATE_DIFF(CURRENT_DATE(), ultima_atividade, DAY) > 30 THEN 'Churn'
        WHEN DATE_DIFF(CURRENT_DATE(), ultima_atividade, DAY) > 14 THEN 'Em Risco'
        ELSE 'Ativo'
    END as status_usuario
FROM last_activity
ORDER BY dias_sem_atividade DESC;
```

---

## 5. TÉCNICAS BIGQUERY ESPECÍFICAS

### 5.1 Tratamento de Timestamps

```sql
-- ✅ MÚLTIPLOS FORMATOS DE TIMESTAMP
CASE 
    WHEN REGEXP_CONTAINS(timestamp, r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') 
    THEN PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)
    ELSE PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp)
END as parsed_timestamp
```

### 5.2 Manipulação de Arrays

```sql
-- ✅ OPERAÇÕES COM ARRAYS
SELECT 
    usuario_id,
    acoes_array,
    -- Primeiro e último elemento
    acoes_array[OFFSET(0)] as primeira_acao,
    acoes_array[OFFSET(ARRAY_LENGTH(acoes_array)-1)] as ultima_acao,
    -- Transformar em string
    ARRAY_TO_STRING(acoes_array, ' → ') as jornada,
    -- Verificar se contém elemento
    'login' IN UNNEST(acoes_array) as fez_login
FROM user_journeys;
```

### 5.3 Expressões Regulares

```sql
-- ✅ VALIDAÇÃO E EXTRAÇÃO DE DADOS
SELECT 
    cpf,
    phone,
    -- Validar formato CPF
    REGEXP_CONTAINS(cpf, r'^\d{3}\.\d{3}\.\d{3}-\d{2}$') as cpf_valido,
    -- Extrair apenas números do telefone
    REGEXP_REPLACE(phone, r'[^\d]', '') as phone_clean,
    -- Verificar se é celular
    REGEXP_CONTAINS(phone, r'^\(\d{2}\)\s9\d{4}-\d{4}$') as is_celular
FROM users;
```

---

## 6. PADRÕES DE DATA ANALYTICS

### 6.1 Análise Temporal

```sql
-- ✅ PADRÕES DE ATIVIDADE POR TEMPO
SELECT 
    EXTRACT(DAYOFWEEK FROM timestamp) as dia_semana,
    EXTRACT(HOUR FROM timestamp) as hora,
    COUNT(*) as total_eventos,
    COUNT(DISTINCT cpf) as usuarios_unicos,
    AVG(COUNT(*)) OVER (PARTITION BY EXTRACT(DAYOFWEEK FROM timestamp)) as media_por_dia
FROM user_actions
GROUP BY dia_semana, hora
ORDER BY dia_semana, hora;
```

### 6.2 Segmentação de Usuários

```sql
-- ✅ RFM ANALYSIS (Recency, Frequency, Monetary)
WITH user_metrics AS (
    SELECT 
        cpf,
        DATE_DIFF(CURRENT_DATE(), MAX(DATE(timestamp)), DAY) as recency,
        COUNT(*) as frequency,
        COUNT(DISTINCT DATE(timestamp)) as monetary_days
    FROM user_actions
    GROUP BY cpf
),
quartiles AS (
    SELECT 
        cpf, recency, frequency, monetary_days,
        NTILE(4) OVER (ORDER BY recency DESC) as r_score,
        NTILE(4) OVER (ORDER BY frequency) as f_score,
        NTILE(4) OVER (ORDER BY monetary_days) as m_score
    FROM user_metrics
)
SELECT 
    cpf,
    CONCAT(r_score, f_score, m_score) as rfm_score,
    CASE 
        WHEN CONCAT(r_score, f_score, m_score) IN ('444', '434', '443', '344') THEN 'Champions'
        WHEN CONCAT(r_score, f_score, m_score) IN ('334', '343', '433', '424') THEN 'Loyal Customers'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'At Risk'
        ELSE 'Others'
    END as segmento
FROM quartiles;
```

### 6.3 Análise Cross-Platform

```sql
-- ✅ COMPORTAMENTO MULTI-PLATAFORMA
WITH platform_activity AS (
    SELECT 
        cpf,
        'RMI' as platform,
        COUNT(*) as actions,
        MAX(DATE(timestamp)) as last_activity
    FROM rmi_audit_logs
    GROUP BY cpf
    
    UNION ALL
    
    SELECT 
        cpf,
        'GO' as platform,
        COUNT(*) as actions,
        MAX(DATE(enrolled_at)) as last_activity
    FROM go_inscricoes
    GROUP BY cpf
)
SELECT 
    cpf,
    COUNT(DISTINCT platform) as platforms_used,
    STRING_AGG(platform, ', ') as platforms_list,
    SUM(actions) as total_actions,
    MAX(last_activity) as most_recent_activity
FROM platform_activity
GROUP BY cpf
HAVING COUNT(DISTINCT platform) > 1  -- Apenas usuários multi-plataforma
ORDER BY total_actions DESC;
```

---

## 7. EXERCÍCIOS PRÁTICOS

### 🎯 **Nível Iniciante**

#### Exercício 1: Contagem Básica
```sql
-- Conte quantos usuários únicos existem em cada dataset
-- Dica: Use COUNT(DISTINCT cpf) e UNION ALL
```

#### Exercício 2: Filtros e Ordenação
```sql
-- Liste os últimos 10 eventos de auditoria para telefone
-- Dica: Use WHERE resource = 'phone' e ORDER BY timestamp DESC
```

### 🎯 **Nível Intermediário**

#### Exercício 3: Window Functions
```sql
-- Para cada usuário, numere suas ações em ordem cronológica
-- e identifique qual foi a primeira e última ação
-- Dica: Use ROW_NUMBER(), FIRST_VALUE() e LAST_VALUE()
```

#### Exercício 4: Análise de Conversão
```sql
-- Calcule a taxa de conclusão de cursos por modalidade
-- apenas para cursos com mais de 5 inscrições
-- Dica: Use JOIN, COUNT(), HAVING
```

### 🎯 **Nível Avançado**

#### Exercício 5: Breadcrumbs Personalizado
```sql
-- Crie um breadcrumb que mostre apenas as mudanças de valor
-- no formato: "antigo→novo" para o resource 'phone'
-- Dica: Use ARRAY_AGG() com CONCAT() e ARRAY_TO_STRING()
```

#### Exercício 6: Análise de Jornada Complexa
```sql
-- Identifique usuários que fizeram opt-out e depois opt-in
-- mostrando o tempo entre as ações
-- Dica: Use LAG(), CASE e TIMESTAMP_DIFF()
```

#### Exercício 7: Segmentação Avançada
```sql
-- Classifique usuários em:
-- - 'New': primeira ação nos últimos 7 dias
-- - 'Active': ação nos últimos 30 dias
-- - 'Dormant': última ação entre 30-90 dias
-- - 'Churned': última ação > 90 dias
```

---

## 📖 **RECURSOS ADICIONAIS**

### Documentação
- [BigQuery SQL Reference](https://cloud.google.com/bigquery/docs/reference/standard-sql/)
- [BigQuery Array Functions](https://cloud.google.com/bigquery/docs/reference/standard-sql/array_functions)
- [BigQuery Window Functions](https://cloud.google.com/bigquery/docs/reference/standard-sql/window-function-calls)

### Ferramentas de Prática
- [BigQuery Sandbox](https://cloud.google.com/bigquery/docs/sandbox)
- [SQL Fiddle](http://sqlfiddle.com/)
- [DB Fiddle](https://www.db-fiddle.com/)

### Livros Recomendados
- "Learning SQL" por Alan Beaulieu
- "SQL Performance Explained" por Markus Winand
- "The Data Warehouse Toolkit" por Ralph Kimball

---

## 🎓 **PRÓXIMOS PASSOS**

1. **Pratique**: Execute as queries do projeto e modifique-as
2. **Experimente**: Tente diferentes abordagens para os mesmos problemas
3. **Optimize**: Use EXPLAIN para entender o plano de execução
4. **Escale**: Teste com datasets maiores
5. **Explore**: Adicione novas métricas e análises

---

*Material criado com base no projeto RJ SuperApp Data Lake Analysis*
*Última atualização: Setembro 2025*