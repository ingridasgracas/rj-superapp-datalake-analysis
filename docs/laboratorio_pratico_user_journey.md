# 🔬 LABORATÓRIO PRÁTICO: ANÁLISE DE JORNADA DE USUÁRIOS

> Exemplos práticos baseados nas queries do RJ SuperApp

## 📋 CENÁRIOS DE ANÁLISE

### 🔍 **Cenário 1: Investigação de Mudanças de Telefone**

#### Problema de Negócio
*"Precisamos entender por que usuários estão alterando telefones com frequência e identificar possíveis fraudes."*

#### Solução SQL - Breadcrumbs de Telefone
```sql
-- ANÁLISE: Usuários com múltiplas mudanças de telefone
WITH phone_changes AS (
  SELECT 
    cpf,
    action,
    old_value as telefone_antigo,
    new_value as telefone_novo,
    timestamp,
    ROW_NUMBER() OVER (
      PARTITION BY cpf 
      ORDER BY PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)
    ) as mudanca_numero
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE resource = 'phone' 
    AND old_value IS NOT NULL 
    AND new_value IS NOT NULL
),
users_with_multiple_changes AS (
  SELECT 
    cpf,
    COUNT(*) as total_mudancas,
    MIN(timestamp) as primeira_mudanca,
    MAX(timestamp) as ultima_mudanca,
    -- Breadcrumb das mudanças
    ARRAY_TO_STRING(
      ARRAY_AGG(
        CONCAT(telefone_antigo, '→', telefone_novo) 
        ORDER BY mudanca_numero
      ), 
      ' ➤ '
    ) as jornada_telefones
  FROM phone_changes
  GROUP BY cpf
  HAVING COUNT(*) >= 3  -- 3 ou mais mudanças
)
SELECT 
  cpf,
  total_mudancas,
  primeira_mudanca,
  ultima_mudanca,
  TIMESTAMP_DIFF(
    PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', ultima_mudanca),
    PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', primeira_mudanca),
    DAY
  ) as dias_entre_primeira_ultima,
  jornada_telefones,
  -- Flag de suspeita
  CASE 
    WHEN total_mudancas >= 5 THEN 'ALTA SUSPEITA'
    WHEN total_mudancas >= 3 AND TIMESTAMP_DIFF(
      PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', ultima_mudanca),
      PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', primeira_mudanca),
      DAY
    ) <= 7 THEN 'MUDANÇAS FREQUENTES'
    ELSE 'MONITORAR'
  END as nivel_risco
FROM users_with_multiple_changes
ORDER BY total_mudancas DESC, dias_entre_primeira_ultima ASC;
```

#### 💡 Insights Esperados
- Usuários com muitas mudanças em pouco tempo
- Padrões de telefones (sequenciais, similares)
- Possíveis casos de fraude ou teste

---

### 📊 **Cenário 2: Funil de Engajamento Educacional**

#### Problema de Negócio
*"Queremos entender onde perdemos usuários no processo de inscrição → início → conclusão de cursos."*

#### Solução SQL - Análise de Funil
```sql
-- ANÁLISE: Funil completo de engajamento em cursos
WITH user_course_journey AS (
  SELECT 
    i.cpf,
    i.curso_id,
    c.titulo,
    c.modalidade,
    i.created_at as inscricao_data,
    i.enrolled_at as inicio_data,
    i.concluded_at as conclusao_data,
    i.status,
    -- Etapas do funil
    CASE 
      WHEN i.created_at IS NOT NULL THEN 1 ELSE 0 
    END as etapa_inscricao,
    CASE 
      WHEN i.enrolled_at IS NOT NULL THEN 1 ELSE 0 
    END as etapa_inicio,
    CASE 
      WHEN i.concluded_at IS NOT NULL THEN 1 ELSE 0 
    END as etapa_conclusao
  FROM `rj-superapp.brutos_go.inscricoes` i
  JOIN `rj-superapp.brutos_go.cursos` c ON i.curso_id = c.id
),
funil_por_curso AS (
  SELECT 
    curso_id,
    titulo,
    modalidade,
    -- Contadores por etapa
    SUM(etapa_inscricao) as total_inscricoes,
    SUM(etapa_inicio) as total_inicios,
    SUM(etapa_conclusao) as total_conclusoes,
    -- Taxas de conversão
    ROUND(SUM(etapa_inicio) * 100.0 / SUM(etapa_inscricao), 2) as taxa_inicio_pct,
    ROUND(SUM(etapa_conclusao) * 100.0 / SUM(etapa_inicio), 2) as taxa_conclusao_pct,
    ROUND(SUM(etapa_conclusao) * 100.0 / SUM(etapa_inscricao), 2) as taxa_conversao_total
  FROM user_course_journey
  GROUP BY curso_id, titulo, modalidade
  HAVING SUM(etapa_inscricao) >= 10  -- Apenas cursos com volume
),
tempo_medio_jornada AS (
  SELECT 
    curso_id,
    -- Tempo médio entre etapas
    AVG(TIMESTAMP_DIFF(enrolled_at, created_at, DAY)) as dias_inscricao_inicio,
    AVG(TIMESTAMP_DIFF(concluded_at, enrolled_at, DAY)) as dias_inicio_conclusao,
    AVG(TIMESTAMP_DIFF(concluded_at, created_at, DAY)) as dias_total_jornada
  FROM user_course_journey
  WHERE enrolled_at IS NOT NULL
  GROUP BY curso_id
)
SELECT 
  f.titulo,
  f.modalidade,
  f.total_inscricoes,
  f.total_inicios,
  f.total_conclusoes,
  f.taxa_inicio_pct,
  f.taxa_conclusao_pct,
  f.taxa_conversao_total,
  -- Tempos médios
  ROUND(t.dias_inscricao_inicio, 1) as dias_para_iniciar,
  ROUND(t.dias_inicio_conclusao, 1) as dias_para_concluir,
  ROUND(t.dias_total_jornada, 1) as dias_jornada_completa,
  -- Classificação de performance
  CASE 
    WHEN f.taxa_conversao_total >= 70 THEN 'EXCELENTE'
    WHEN f.taxa_conversao_total >= 50 THEN 'BOA'
    WHEN f.taxa_conversao_total >= 30 THEN 'REGULAR'
    ELSE 'PRECISA MELHORAR'
  END as performance_curso
FROM funil_por_curso f
LEFT JOIN tempo_medio_jornada t ON f.curso_id = t.curso_id
ORDER BY f.taxa_conversao_total DESC;
```

---

### 🕒 **Cenário 3: Análise de Padrões Temporais**

#### Problema de Negócio
*"Quando nossos usuários são mais ativos? Precisamos otimizar horários de comunicação."*

#### Solução SQL - Heatmap de Atividade
```sql
-- ANÁLISE: Padrões de atividade por hora e dia da semana
WITH activity_patterns AS (
  SELECT 
    cpf,
    EXTRACT(DAYOFWEEK FROM PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)) as dia_semana,
    EXTRACT(HOUR FROM PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)) as hora,
    action,
    resource
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE timestamp IS NOT NULL
),
heatmap_data AS (
  SELECT 
    dia_semana,
    CASE dia_semana
      WHEN 1 THEN 'Domingo'
      WHEN 2 THEN 'Segunda' 
      WHEN 3 THEN 'Terça'
      WHEN 4 THEN 'Quarta'
      WHEN 5 THEN 'Quinta'
      WHEN 6 THEN 'Sexta'
      WHEN 7 THEN 'Sábado'
    END as nome_dia,
    hora,
    COUNT(*) as total_eventos,
    COUNT(DISTINCT cpf) as usuarios_unicos,
    -- Média móvel por hora
    AVG(COUNT(*)) OVER (
      PARTITION BY dia_semana 
      ORDER BY hora 
      ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) as media_movel_eventos
  FROM activity_patterns
  GROUP BY dia_semana, hora
),
ranking_horarios AS (
  SELECT 
    *,
    -- Ranking de atividade por dia
    ROW_NUMBER() OVER (PARTITION BY dia_semana ORDER BY total_eventos DESC) as rank_no_dia,
    -- Percentil de atividade geral
    PERCENT_RANK() OVER (ORDER BY total_eventos) as percentil_atividade
  FROM heatmap_data
)
SELECT 
  nome_dia,
  hora,
  total_eventos,
  usuarios_unicos,
  ROUND(media_movel_eventos, 1) as media_movel,
  rank_no_dia,
  ROUND(percentil_atividade * 100, 1) as percentil_pct,
  -- Classificação de intensidade
  CASE 
    WHEN percentil_atividade >= 0.9 THEN 'PICO'
    WHEN percentil_atividade >= 0.7 THEN 'ALTA'
    WHEN percentil_atividade >= 0.3 THEN 'MÉDIA'
    ELSE 'BAIXA'
  END as intensidade_atividade,
  -- Melhor horário para comunicação
  CASE 
    WHEN rank_no_dia <= 3 AND total_eventos >= 100 THEN 'IDEAL PARA COMUNICAÇÃO'
    ELSE 'HORÁRIO REGULAR'
  END as recomendacao_comunicacao
FROM ranking_horarios
ORDER BY dia_semana, hora;
```

---

### 🔄 **Cenário 4: Detecção de Jornadas Circulares**

#### Problema de Negócio
*"Identificar usuários que fazem e desfazem ações repetidamente (possível confusão de UX)."*

#### Solução SQL - Análise de Ciclos
```sql
-- ANÁLISE: Detecção de comportamentos circulares
WITH user_action_sequence AS (
  SELECT 
    cpf,
    action,
    resource,
    old_value,
    new_value,
    timestamp,
    ROW_NUMBER() OVER (
      PARTITION BY cpf, resource 
      ORDER BY PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)
    ) as action_order
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL AND resource IS NOT NULL
),
value_changes AS (
  SELECT 
    cpf,
    resource,
    action,
    old_value,
    new_value,
    action_order,
    -- Próxima ação
    LEAD(action) OVER (
      PARTITION BY cpf, resource 
      ORDER BY action_order
    ) as next_action,
    LEAD(old_value) OVER (
      PARTITION BY cpf, resource 
      ORDER BY action_order
    ) as next_old_value,
    -- Verifica se voltou ao valor anterior
    LAG(new_value) OVER (
      PARTITION BY cpf, resource 
      ORDER BY action_order
    ) = old_value as voltou_valor_anterior
  FROM user_action_sequence
),
circular_patterns AS (
  SELECT 
    cpf,
    resource,
    COUNT(*) as total_actions,
    SUM(CASE WHEN voltou_valor_anterior THEN 1 ELSE 0 END) as reversoes,
    -- Array da sequência de valores
    ARRAY_AGG(
      CONCAT(old_value, '→', new_value) 
      ORDER BY action_order
    ) as sequencia_mudancas,
    -- Identificar padrões
    STRING_AGG(
      CONCAT(action, ':', old_value, '→', new_value), 
      ' | ' 
      ORDER BY action_order
    ) as jornada_completa
  FROM value_changes
  GROUP BY cpf, resource
  HAVING COUNT(*) >= 3  -- Pelo menos 3 ações
),
circular_analysis AS (
  SELECT 
    *,
    ROUND(reversoes * 100.0 / total_actions, 2) as taxa_reversao_pct,
    -- Detectar padrões específicos
    CASE 
      WHEN taxa_reversao_pct >= 50 THEN 'ALTA CIRCULARIDADE'
      WHEN reversoes >= 3 THEN 'COMPORTAMENTO CIRCULAR'
      WHEN total_actions >= 10 AND reversoes >= 2 THEN 'POSSÍVEL CONFUSÃO UX'
      ELSE 'COMPORTAMENTO NORMAL'
    END as tipo_padrao,
    -- Contar valores únicos tentados
    ARRAY_LENGTH(
      ARRAY(
        SELECT DISTINCT value 
        FROM UNNEST(REGEXP_EXTRACT_ALL(jornada_completa, r'→([^|]+)')) as value
      )
    ) as valores_unicos_tentados
  FROM circular_patterns
)
SELECT 
  cpf,
  resource,
  total_actions,
  reversoes,
  taxa_reversao_pct,
  valores_unicos_tentados,
  tipo_padrao,
  sequencia_mudancas,
  -- Primeiras e últimas mudanças para análise
  sequencia_mudancas[OFFSET(0)] as primeira_mudanca,
  sequencia_mudancas[OFFSET(ARRAY_LENGTH(sequencia_mudancas)-1)] as ultima_mudanca,
  -- Score de complexidade da jornada
  ROUND(
    (total_actions * 0.3) + 
    (reversoes * 0.5) + 
    (valores_unicos_tentados * 0.2), 
    2
  ) as complexidade_score
FROM circular_analysis
WHERE tipo_padrao != 'COMPORTAMENTO NORMAL'
ORDER BY taxa_reversao_pct DESC, total_actions DESC;
```

---

### 📈 **Cenário 5: Análise de Retenção Cross-Platform**

#### Problema de Negócio
*"Usuários que usam ambas plataformas (RMI + GO) são mais engajados? Como é a jornada entre plataformas?"*

#### Solução SQL - Cross-Platform Journey
```sql
-- ANÁLISE: Jornada cross-platform e retenção
WITH rmi_activity AS (
  SELECT 
    cpf,
    MIN(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp))) as primeira_acao_rmi,
    MAX(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp))) as ultima_acao_rmi,
    COUNT(*) as total_acoes_rmi,
    COUNT(DISTINCT DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp))) as dias_ativos_rmi
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL AND timestamp IS NOT NULL
  GROUP BY cpf
),
go_activity AS (
  SELECT 
    cpf,
    MIN(DATE(created_at)) as primeira_inscricao_go,
    MAX(DATE(COALESCE(concluded_at, enrolled_at, created_at))) as ultima_acao_go,
    COUNT(*) as total_cursos_go,
    COUNT(concluded_at) as cursos_concluidos_go
  FROM `rj-superapp.brutos_go.inscricoes`
  WHERE cpf IS NOT NULL
  GROUP BY cpf
),
cross_platform_users AS (
  SELECT 
    COALESCE(r.cpf, g.cpf) as cpf,
    -- Atividade RMI
    r.primeira_acao_rmi,
    r.ultima_acao_rmi,
    COALESCE(r.total_acoes_rmi, 0) as total_acoes_rmi,
    COALESCE(r.dias_ativos_rmi, 0) as dias_ativos_rmi,
    -- Atividade GO
    g.primeira_inscricao_go,
    g.ultima_acao_go,
    COALESCE(g.total_cursos_go, 0) as total_cursos_go,
    COALESCE(g.cursos_concluidos_go, 0) as cursos_concluidos_go,
    -- Classificação de usuário
    CASE 
      WHEN r.cpf IS NOT NULL AND g.cpf IS NOT NULL THEN 'CROSS_PLATFORM'
      WHEN r.cpf IS NOT NULL THEN 'APENAS_RMI'
      ELSE 'APENAS_GO'
    END as tipo_usuario,
    -- Análise temporal cross-platform
    CASE 
      WHEN r.cpf IS NOT NULL AND g.cpf IS NOT NULL THEN
        CASE 
          WHEN r.primeira_acao_rmi < g.primeira_inscricao_go THEN 'RMI_PRIMEIRO'
          WHEN g.primeira_inscricao_go < r.primeira_acao_rmi THEN 'GO_PRIMEIRO'
          ELSE 'SIMULTANEO'
        END
      ELSE NULL
    END as jornada_cross_platform
  FROM rmi_activity r
  FULL OUTER JOIN go_activity g ON r.cpf = g.cpf
),
engagement_metrics AS (
  SELECT 
    *,
    -- Métricas de engajamento
    CASE 
      WHEN tipo_usuario = 'CROSS_PLATFORM' THEN total_acoes_rmi + total_cursos_go
      WHEN tipo_usuario = 'APENAS_RMI' THEN total_acoes_rmi
      ELSE total_cursos_go
    END as engajamento_total,
    
    -- Dias de atividade cross-platform
    CASE 
      WHEN tipo_usuario = 'CROSS_PLATFORM' AND primeira_acao_rmi IS NOT NULL AND primeira_inscricao_go IS NOT NULL
      THEN DATE_DIFF(
        GREATEST(COALESCE(ultima_acao_rmi, DATE('1900-01-01')), COALESCE(ultima_acao_go, DATE('1900-01-01'))),
        LEAST(primeira_acao_rmi, primeira_inscricao_go),
        DAY
      )
      ELSE NULL
    END as dias_lifetime_cross_platform,
    
    -- Taxa de conversão GO
    CASE 
      WHEN total_cursos_go > 0 
      THEN ROUND(cursos_concluidos_go * 100.0 / total_cursos_go, 2)
      ELSE NULL
    END as taxa_conclusao_go
  FROM cross_platform_users
)
SELECT 
  tipo_usuario,
  jornada_cross_platform,
  COUNT(*) as total_usuarios,
  -- Métricas de engajamento médio
  ROUND(AVG(engajamento_total), 2) as engajamento_medio,
  ROUND(AVG(dias_ativos_rmi), 2) as dias_ativos_rmi_medio,
  ROUND(AVG(total_cursos_go), 2) as cursos_go_medio,
  ROUND(AVG(taxa_conclusao_go), 2) as taxa_conclusao_media,
  ROUND(AVG(dias_lifetime_cross_platform), 2) as lifetime_cross_platform_medio,
  
  -- Distribuição percentual
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentual_usuarios
FROM engagement_metrics
GROUP BY tipo_usuario, jornada_cross_platform
ORDER BY engajamento_medio DESC;
```

---

## 🎯 **EXERCÍCIOS PARA PRATICAR**

### **Desafio 1: Detector de Anomalias**
Crie uma query que identifique usuários com comportamento anômalo (ex: 10+ ações em 1 hora).

### **Desafio 2: Análise de Sazonalidade**
Identifique padrões sazonais de inscrições em cursos por mês/trimestre.

### **Desafio 3: Score de Engajamento**
Desenvolva um score de 0-100 baseado em frequência, recência e diversidade de ações.

### **Desafio 4: Análise de Coorte**
Crie uma análise de coorte mensal mostrando retenção de usuários.

### **Desafio 5: Predição de Churn**
Identifique características de usuários que provavelmente farão churn.

---

## 📊 **VISUALIZAÇÕES RECOMENDADAS**

Para cada análise, considere estas visualizações:

1. **Breadcrumbs**: Sankey Diagram, Flowchart
2. **Funil**: Funnel Chart, Bar Chart
3. **Temporal**: Line Chart, Heatmap  
4. **Circular**: Network Graph, Chord Diagram
5. **Cross-Platform**: Venn Diagram, Multi-axis Chart

---

*Laboratório criado com base no projeto RJ SuperApp Data Lake Analysis*