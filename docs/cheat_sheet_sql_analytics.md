# 📋 CHEAT SHEET: SQL ANALYTICS & USER JOURNEY

> Referência rápida para análise de dados e jornada de usuários

## 🔧 SINTAXE SQL ESSENCIAL

### Window Functions
```sql
-- ROW_NUMBER: numeração sequencial
ROW_NUMBER() OVER (PARTITION BY coluna ORDER BY data)

-- RANK: ranking com empates
RANK() OVER (ORDER BY valor DESC)

-- LAG/LEAD: valores anteriores/posteriores  
LAG(coluna, 1) OVER (PARTITION BY user ORDER BY data)

-- ARRAY_AGG: criar arrays acumulativos
ARRAY_AGG(coluna) OVER (ORDER BY data ROWS UNBOUNDED PRECEDING)
```

### CTEs (Common Table Expressions)
```sql
WITH primeira_cte AS (
    SELECT coluna1, COUNT(*) as contagem FROM tabela GROUP BY coluna1
),
segunda_cte AS (
    SELECT * FROM primeira_cte WHERE contagem > 10
)
SELECT * FROM segunda_cte;
```

### Array Operations (BigQuery)
```sql
-- Converter array para string
ARRAY_TO_STRING(array_coluna, ' → ')

-- Primeiro/último elemento
array_coluna[OFFSET(0)]
array_coluna[OFFSET(ARRAY_LENGTH(array_coluna)-1)]

-- Verificar se contém elemento
'valor' IN UNNEST(array_coluna)
```

---

## 📊 PADRÕES DE ANÁLISE

### 1. **Análise de Conversão**
```sql
SELECT 
    etapa,
    COUNT(*) as usuarios,
    COUNT(*) * 100.0 / LAG(COUNT(*)) OVER (ORDER BY etapa_num) as taxa_conversao
FROM funil_dados
GROUP BY etapa, etapa_num
ORDER BY etapa_num;
```

### 2. **Análise de Corte**
```sql
WITH primeira_acao AS (
    SELECT user_id, MIN(DATE(timestamp)) as cohort_date
    FROM eventos GROUP BY user_id
)
SELECT 
    cohort_date,
    DATE_DIFF(evento_date, cohort_date, MONTH) as mes_offset,
    COUNT(DISTINCT user_id) as usuarios_ativos
FROM eventos e
JOIN primeira_acao p ON e.user_id = p.user_id
GROUP BY cohort_date, mes_offset;
```

### 3. **Detecção de Anomalias**
```sql
WITH stats AS (
    SELECT 
        AVG(valor) as media,
        STDDEV(valor) as desvio_padrao
    FROM dados
)
SELECT *,
    ABS(valor - media) / desvio_padrao as z_score,
    CASE WHEN ABS(valor - media) / desvio_padrao > 2 THEN 'ANOMALIA' END as flag
FROM dados, stats;
```

### 4. **Análise RFM**
```sql
WITH rfm AS (
    SELECT 
        user_id,
        DATE_DIFF(CURRENT_DATE(), MAX(data), DAY) as recency,
        COUNT(*) as frequency,
        SUM(valor) as monetary
    FROM transacoes GROUP BY user_id
)
SELECT *,
    NTILE(5) OVER (ORDER BY recency DESC) as r_score,
    NTILE(5) OVER (ORDER BY frequency) as f_score,
    NTILE(5) OVER (ORDER BY monetary) as m_score
FROM rfm;
```

---

## 🛤️ BREADCRUMBS & JORNADAS

### Breadcrumb Simples
```sql
CONCAT(action, ' (', ROW_NUMBER() OVER (PARTITION BY user ORDER BY timestamp), ')')
```

### Breadcrumb Completo
```sql
ARRAY_TO_STRING(
    ARRAY_AGG(action) OVER (
        PARTITION BY user ORDER BY timestamp 
        ROWS UNBOUNDED PRECEDING
    ), 
    ' → '
)
```

### Breadcrumb com Contexto
```sql
ARRAY_TO_STRING(
    ARRAY_AGG(CONCAT(action, ':', old_value, '→', new_value)), 
    ' ➤ '
)
```

### Detecção de Padrões
```sql
CASE 
    WHEN total_actions = 1 THEN 'Single Action'
    WHEN first_action = last_action THEN 'Circular Journey'
    ELSE 'Linear Journey'
END
```

---

## ⏰ ANÁLISE TEMPORAL

### Extrair Componentes de Data
```sql
EXTRACT(YEAR FROM timestamp) as ano
EXTRACT(MONTH FROM timestamp) as mes  
EXTRACT(DAYOFWEEK FROM timestamp) as dia_semana
EXTRACT(HOUR FROM timestamp) as hora
```

### Diferenças de Tempo
```sql
DATE_DIFF(data_fim, data_inicio, DAY) as dias_diferenca
TIMESTAMP_DIFF(ts_fim, ts_inicio, HOUR) as horas_diferenca
```

### Agrupamentos Temporais
```sql
-- Por trimestre
CONCAT('Q', EXTRACT(QUARTER FROM data), '-', EXTRACT(YEAR FROM data))

-- Por semana
DATE_TRUNC(data, WEEK)

-- Por hora
DATETIME_TRUNC(timestamp, HOUR)
```

---

## 🔍 FILTROS E CONDIÇÕES

### Filtros de Data
```sql
-- Últimos 30 dias
WHERE DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)

-- Mês atual
WHERE EXTRACT(YEAR FROM data) = EXTRACT(YEAR FROM CURRENT_DATE())
  AND EXTRACT(MONTH FROM data) = EXTRACT(MONTH FROM CURRENT_DATE())

-- Entre datas
WHERE DATE(timestamp) BETWEEN '2025-01-01' AND '2025-12-31'
```

### Filtros de Texto
```sql
-- Contém palavra
WHERE LOWER(campo) LIKE '%palavra%'

-- Regex
WHERE REGEXP_CONTAINS(campo, r'^\d{3}\.\d{3}\.\d{3}-\d{2}$')

-- Lista de valores
WHERE status IN ('ativo', 'pendente', 'processando')
```

### Filtros de Agregação
```sql
-- HAVING para filtrar grupos
GROUP BY categoria
HAVING COUNT(*) > 10 AND AVG(valor) > 100
```

---

## 📈 MÉTRICAS DE PRODUTO

### Taxa de Conversão
```sql
COUNT(CASE WHEN converteu THEN 1 END) * 100.0 / COUNT(*) as taxa_conversao
```

### Taxa de Retenção
```sql
-- Usuários que voltaram no mês seguinte
WITH retencao AS (
    SELECT user_id, DATE_TRUNC(data, MONTH) as mes
    FROM atividades
    GROUP BY user_id, mes
)
SELECT 
    mes,
    COUNT(DISTINCT user_id) as usuarios_mes,
    COUNT(DISTINCT CASE WHEN proximos.user_id IS NOT NULL THEN r.user_id END) as usuarios_retidos
FROM retencao r
LEFT JOIN retencao proximos ON r.user_id = proximos.user_id 
    AND proximos.mes = DATE_ADD(r.mes, INTERVAL 1 MONTH)
GROUP BY mes;
```

### LTV (Lifetime Value)
```sql
SELECT 
    user_id,
    SUM(valor) as ltv,
    COUNT(*) as transacoes,
    AVG(valor) as ticket_medio,
    DATE_DIFF(MAX(data), MIN(data), DAY) as lifetime_days
FROM transacoes
GROUP BY user_id;
```

---

## 🎯 SEGMENTAÇÃO DE USUÁRIOS

### Por Comportamento
```sql
CASE 
    WHEN ultimo_acesso >= CURRENT_DATE() - 7 THEN 'Ativo'
    WHEN ultimo_acesso >= CURRENT_DATE() - 30 THEN 'Em Risco'  
    WHEN ultimo_acesso >= CURRENT_DATE() - 90 THEN 'Dormant'
    ELSE 'Churned'
END as segmento
```

### Por Volume de Atividade
```sql
CASE 
    WHEN total_acoes >= PERCENTILE_CONT(0.9) OVER() THEN 'Power User'
    WHEN total_acoes >= PERCENTILE_CONT(0.7) OVER() THEN 'Heavy User'
    WHEN total_acoes >= PERCENTILE_CONT(0.3) OVER() THEN 'Regular User'
    ELSE 'Light User'
END as tipo_usuario
```

### Por Valor
```sql
WITH quartis AS (
    SELECT 
        PERCENTILE_CONT(0.25) OVER() as q1,
        PERCENTILE_CONT(0.5) OVER() as q2,
        PERCENTILE_CONT(0.75) OVER() as q3
    FROM user_values
)
SELECT 
    CASE 
        WHEN valor >= q3 THEN 'Premium'
        WHEN valor >= q2 THEN 'Medium'  
        WHEN valor >= q1 THEN 'Basic'
        ELSE 'Entry'
    END as segmento_valor
FROM user_values, quartis;
```

---

## 🚨 DETECÇÃO DE PROBLEMAS

### Usuários com Comportamento Suspeito
```sql
-- Muitas ações em pouco tempo
SELECT user_id, DATE(timestamp), COUNT(*) as acoes_dia
FROM eventos
GROUP BY user_id, DATE(timestamp)
HAVING COUNT(*) > 100;

-- Reversão frequente de ações
WITH reversoes AS (
    SELECT user_id,
           LAG(new_value) OVER (PARTITION BY user_id ORDER BY timestamp) = old_value as voltou
    FROM audit_logs
)
SELECT user_id, SUM(CASE WHEN voltou THEN 1 ELSE 0 END) as total_reversoes
FROM reversoes
GROUP BY user_id
HAVING SUM(CASE WHEN voltou THEN 1 ELSE 0 END) >= 5;
```

### Dados Faltantes
```sql
SELECT 
    COUNT(*) as total_registros,
    COUNT(campo1) as campo1_preenchido,
    COUNT(*) - COUNT(campo1) as campo1_nulo,
    ROUND((COUNT(*) - COUNT(campo1)) * 100.0 / COUNT(*), 2) as percentual_nulo
FROM tabela;
```

---

## 🔧 OTIMIZAÇÃO E PERFORMANCE

### Usar LIMIT para Testes
```sql
-- Testar query com amostra pequena
SELECT * FROM tabela_grande LIMIT 1000;
```

### Filtrar Cedo
```sql
-- ✅ Bom: filtro antes do JOIN
WITH dados_filtrados AS (
    SELECT * FROM tabela WHERE data >= '2025-01-01'
)
SELECT * FROM dados_filtrados d JOIN outra_tabela o ON d.id = o.id;

-- ❌ Ruim: filtro depois do JOIN  
SELECT * FROM tabela t JOIN outra_tabela o ON t.id = o.id
WHERE t.data >= '2025-01-01';
```

### Usar APPROXIMATE para Grandes Volumes
```sql
-- Contagem aproximada (mais rápida)
SELECT APPROX_COUNT_DISTINCT(user_id) FROM eventos;

-- Quantis aproximados
SELECT APPROX_QUANTILES(valor, 100)[OFFSET(50)] as mediana FROM dados;
```

---

## 📚 GLOSSÁRIO

**Breadcrumb**: Caminho que mostra a sequência de ações/páginas visitadas
**Coorte**: Grupo de usuários que compartilham uma característica temporal
**CTR**: Click-Through Rate (taxa de cliques)
**Churn**: Taxa de abandono/cancelamento
**Funil**: Sequência de etapas que levam a uma conversão
**LTV**: Lifetime Value (valor vitalício do cliente)
**MAU**: Monthly Active Users (usuários ativos mensais)
**RFM**: Recency, Frequency, Monetary (métrica de segmentação)
**Retenção**: Percentual de usuários que retornam em um período
**Sessionização**: Agrupamento de eventos em sessões de uso

---

## 🎯 DICAS RÁPIDAS

- **Always filter early**: Aplique filtros o mais cedo possível na query
- **Use CTEs**: Para quebrar queries complexas em etapas lógicas  
- **Test with LIMIT**: Sempre teste com amostras pequenas primeiro
- **Comment your code**: Documente a lógica de negócio nas queries
- **Use meaningful names**: CTEs e colunas com nomes descritivos
- **Check data types**: Cuidado com conversões implícitas de tipos
- **Handle NULLs**: Sempre considere valores nulos nas análises
- **Validate results**: Sanity check nos resultados das análises

---

*Cheat Sheet criado com base no projeto RJ SuperApp Data Lake Analysis*