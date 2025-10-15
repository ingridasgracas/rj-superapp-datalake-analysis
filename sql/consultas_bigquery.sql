
-- ANÁLISE EXPLORATÓRIA DE TRACKING DE USUÁRIOS
--1 Tipos de ações mais frequentes
SELECT  
    action,
    resource,
    COUNT(*) AS frequency,
    COUNT(DISTINCT cpf) AS unique_users
FROM (
    SELECT *,
           PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E6S', JSON_EXTRACT_SCALAR(TO_JSON_STRING(t), '$.timestamp')) AS event_timestamp
    FROM `rj-superapp.brutos_rmi.rmi_audit_logs` t
) WHERE event_timestamp >= TIMESTAMP('2025-09-05')
  AND action IS NOT NULL
GROUP BY action, resource
ORDER BY frequency DESC
LIMIT 20;


--2 Caminho completo de ações por usuário (VERSÃO ORIGINAL)
WITH user_actions_ordered AS (
  SELECT 
    cpf,
    action,
    resource,
    timestamp,
    old_value,
    new_value,
    ROW_NUMBER() OVER (
      PARTITION BY cpf 
      ORDER BY 
        CASE 
          WHEN REGEXP_CONTAINS(timestamp, r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') 
          THEN PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)
          ELSE PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp)
        END
    ) as action_sequence
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND old_value IS NOT NULL 
    AND resource = 'phone'
    AND (
      CASE 
        WHEN REGEXP_CONTAINS(timestamp, r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') 
        THEN PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)
        ELSE PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp)
      END
    ) >= TIMESTAMP('2025-09-05')
),
user_action_paths AS (
  SELECT 
    cpf,
    action,
    resource,
    timestamp,
    old_value,
    new_value,
    action_sequence,
    -- Criar array de todas as ações anteriores + atual
    ARRAY_AGG(action) OVER (
      PARTITION BY cpf 
      ORDER BY action_sequence 
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as action_path_array
  FROM user_actions_ordered
)
SELECT 
  cpf,
  action,
  resource,
  timestamp,
  old_value,
  new_value,
  action_sequence,
  -- Breadcrumb completo: todas as ações até o momento
  ARRAY_TO_STRING(action_path_array, ' → ') as action_breadcrumb,
  -- Contagem de ações no caminho
  ARRAY_LENGTH(action_path_array) as path_length
FROM user_action_paths
ORDER BY cpf, action_sequence;

--2B Caminho de ações OTIMIZADO PARA SANKEY DIAGRAM
WITH user_actions_ordered AS (
  SELECT 
    cpf,
    action,
    ROW_NUMBER() OVER (
      PARTITION BY cpf 
      ORDER BY 
        CASE 
          WHEN REGEXP_CONTAINS(timestamp, r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') 
          THEN PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)
          ELSE PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp)
        END
    ) as step_order
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND old_value IS NOT NULL 
    AND resource = 'phone'
    AND (
      CASE 
        WHEN REGEXP_CONTAINS(timestamp, r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') 
        THEN PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)
        ELSE PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp)
      END
    ) >= TIMESTAMP('2025-09-05')
),
action_transitions AS (
  SELECT 
    a1.action as source_action,
    a2.action as target_action,
    CONCAT('Passo ', a1.step_order, ' → ', a2.step_order) as transition_step,
    COUNT(*) as transition_count,
    COUNT(DISTINCT a1.cpf) as unique_users
  FROM user_actions_ordered a1
  JOIN user_actions_ordered a2 
    ON a1.cpf = a2.cpf 
    AND a2.step_order = a1.step_order + 1
  GROUP BY a1.action, a2.action, a1.step_order, a2.step_order
)
SELECT 
  source_action,
  target_action,
  transition_step,
  transition_count,
  unique_users
FROM action_transitions
ORDER BY transition_count DESC;


--3 Jornada com contexto de mudanças (VERSÃO ORIGINAL)
WITH user_phone_journey AS (
  SELECT 
    cpf,
    action,
    resource,
    timestamp,
    old_value,
    new_value,
    ROW_NUMBER() OVER (PARTITION BY cpf ORDER BY PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)) as step_number,
    LAG(new_value) OVER (PARTITION BY cpf ORDER BY PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)) as previous_value
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND old_value IS NOT NULL 
    AND resource = 'phone'
    AND PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp) >= TIMESTAMP('2025-09-05')
),
journey_with_context AS (
  SELECT 
    *,
    -- Criar contexto da mudança
    CASE 
      WHEN step_number = 1 THEN CONCAT('INÍCIO: ', action, ' (', old_value, ' → ', new_value, ')')
      ELSE CONCAT('PASSO ', step_number, ': ', action, ' (', old_value, ' → ', new_value, ')')
    END as step_description,
    -- Array de todas as mudanças até agora
    ARRAY_AGG(CONCAT(action, ':', old_value, '→', new_value)) OVER (
      PARTITION BY cpf 
      ORDER BY step_number 
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as journey_breadcrumb
  FROM user_phone_journey
)
SELECT 
  cpf,
  action,
  resource,
  timestamp,
  old_value,
  new_value,
  step_number,
  step_description,
  -- Breadcrumb da jornada completa
  ARRAY_TO_STRING(journey_breadcrumb, ' ➤ ') as full_journey_breadcrumb,
  -- Resumo da jornada
  CONCAT(
    'Jornada de ', ARRAY_LENGTH(journey_breadcrumb), ' passos: ',
    ARRAY_TO_STRING(journey_breadcrumb, ' ➤ ')
  ) as journey_summary
FROM journey_with_context
ORDER BY cpf, step_number;

--3B Jornada OTIMIZADA PARA SÉRIE TEMPORAL
WITH user_phone_journey AS (
  SELECT 
    cpf,
    action,
    resource,
    PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp) as event_timestamp,
    old_value,
    new_value,
    ROW_NUMBER() OVER (PARTITION BY cpf ORDER BY PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)) as step_number
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND old_value IS NOT NULL 
    AND resource = 'phone'
    AND PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp) >= TIMESTAMP('2025-09-05')
),
temporal_aggregation AS (
  SELECT 
    DATE(event_timestamp) as date_only,
    DATETIME(TIMESTAMP_TRUNC(event_timestamp, HOUR)) as hour_timestamp,
    action,
    COUNT(*) as action_count,
    COUNT(DISTINCT cpf) as unique_users,
    AVG(step_number) as avg_step_number,
    MAX(step_number) as max_step_number,
    MIN(step_number) as min_step_number
  FROM user_phone_journey
  GROUP BY DATE(event_timestamp), DATETIME(TIMESTAMP_TRUNC(event_timestamp, HOUR)), action
)
SELECT 
  date_only,
  hour_timestamp,
  action,
  action_count,
  unique_users,
  avg_step_number,
  max_step_number,
  min_step_number
FROM temporal_aggregation
ORDER BY hour_timestamp, action;

-- 4 BREADCRUMBS - Análise de padrões de jornada (VERSÃO ORIGINAL)
WITH user_journey_patterns AS (
  SELECT 
    cpf,
    ARRAY_AGG(action ORDER BY PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)) as action_sequence,
    COUNT(*) as total_actions,
    MIN(timestamp) as first_action_time,
    MAX(timestamp) as last_action_time
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND old_value IS NOT NULL 
    AND resource = 'phone'
    AND PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp) >= TIMESTAMP('2025-09-05')
  GROUP BY cpf
)
SELECT 
  cpf,
  total_actions,
  first_action_time,
  last_action_time,
  -- Breadcrumb da sequência completa de ações
  ARRAY_TO_STRING(action_sequence, ' → ') as complete_user_journey,
  -- Primeira e última ação
  action_sequence[OFFSET(0)] as first_action,
  action_sequence[OFFSET(ARRAY_LENGTH(action_sequence) - 1)] as last_action,
  -- Padrão da jornada
  CASE 
    WHEN total_actions = 1 THEN 'Ação Única'
    WHEN action_sequence[OFFSET(0)] = action_sequence[OFFSET(ARRAY_LENGTH(action_sequence) - 1)] THEN 'Jornada Circular'
    ELSE 'Jornada Linear'
  END as journey_pattern
FROM user_journey_patterns
ORDER BY total_actions DESC, cpf;

-- 4B Análise de padrões OTIMIZADA PARA GRÁFICO DE BOLHAS
WITH user_journey_patterns AS (
  SELECT 
    cpf,
    ARRAY_AGG(action ORDER BY PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)) as action_sequence,
    COUNT(*) as total_actions,
    MIN(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)) as first_action_time,
    MAX(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)) as last_action_time
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND old_value IS NOT NULL 
    AND resource = 'phone'
    AND PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp) >= TIMESTAMP('2025-09-05')
  GROUP BY cpf
),
pattern_analysis AS (
  SELECT 
    cpf,
    total_actions,
    -- Duração da jornada em horas
    DATETIME_DIFF(last_action_time, first_action_time, HOUR) as journey_duration_hours,
    -- Primeira e última ação
    action_sequence[OFFSET(0)] as first_action,
    action_sequence[OFFSET(ARRAY_LENGTH(action_sequence) - 1)] as last_action,
    -- Padrão da jornada
    CASE 
      WHEN total_actions = 1 THEN 'Ação Única'
      WHEN action_sequence[OFFSET(0)] = action_sequence[OFFSET(ARRAY_LENGTH(action_sequence) - 1)] THEN 'Jornada Circular'
      ELSE 'Jornada Linear'
    END as journey_pattern,
    -- Velocidade da jornada (ações por hora)
    CASE 
      WHEN DATETIME_DIFF(last_action_time, first_action_time, HOUR) > 0 
      THEN total_actions / DATETIME_DIFF(last_action_time, first_action_time, HOUR)
      ELSE total_actions
    END as actions_per_hour
  FROM user_journey_patterns
),
aggregated_patterns AS (
  SELECT 
    journey_pattern,
    total_actions,
    journey_duration_hours,
    first_action,
    last_action,
    COUNT(*) as user_count,
    AVG(actions_per_hour) as avg_actions_per_hour,
    -- Categoria de complexidade
    CASE 
      WHEN total_actions = 1 THEN 'Simples'
      WHEN total_actions BETWEEN 2 AND 5 THEN 'Moderada'
      WHEN total_actions BETWEEN 6 AND 10 THEN 'Complexa'
      ELSE 'Muito Complexa'
    END as complexity_level,
    -- Categoria de duração
    CASE 
      WHEN journey_duration_hours = 0 THEN 'Instantânea'
      WHEN journey_duration_hours <= 1 THEN 'Rápida (≤1h)'
      WHEN journey_duration_hours <= 24 THEN 'Diária (≤24h)'
      ELSE 'Longa (>24h)'
    END as duration_category
  FROM pattern_analysis
  GROUP BY 
    journey_pattern, 
    total_actions, 
    journey_duration_hours, 
    first_action, 
    last_action,
    complexity_level,
    duration_category
)
SELECT 
  journey_pattern,
  total_actions,
  journey_duration_hours,
  first_action,
  last_action,
  user_count,
  avg_actions_per_hour,
  complexity_level,
  duration_category
FROM aggregated_patterns
ORDER BY user_count DESC, total_actions;

-- 5 Distribuição de ações de opt-in/opt-out
SELECT 
    action,
    channel,
    reason,
    COUNT(*) as frequency,
    COUNT(DISTINCT cpf) as unique_users
FROM `rj-superapp.brutos_rmi.rmi_opt_in_history`
WHERE PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp) >= TIMESTAMP('2025-09-05')
GROUP BY action, channel, reason
ORDER BY frequency DESC;

-- 6 Usuários com histórico de opt-out
SELECT 
 --   cpf,   -- identificar c a tab rj-superapp.brutos_go.inscricoes` i
    phone_number,
    action,
    reason,
    timestamp
FROM `rj-superapp.brutos_rmi.rmi_opt_in_history`
WHERE action LIKE '%opt%'
    AND cpf IS NOT NULL
    AND PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp) >= TIMESTAMP('2025-09-05')
ORDER BY cpf, PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp) DESC;


--7 Usuários únicos por dia da semana
SELECT 
    EXTRACT(DAYOFWEEK FROM TIMESTAMP(timestamp)) as dia_semana,
    CASE EXTRACT(DAYOFWEEK FROM TIMESTAMP(timestamp))
        WHEN 1 THEN 'Domingo'
        WHEN 2 THEN 'Segunda'
        WHEN 3 THEN 'Terça'
        WHEN 4 THEN 'Quarta'
        WHEN 5 THEN 'Quinta'
        WHEN 6 THEN 'Sexta'
        WHEN 7 THEN 'Sábado'
    END as nome_dia,
    COUNT(DISTINCT cpf) as usuarios_unicos,
    COUNT(*) as total_eventos
FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
WHERE timestamp IS NOT NULL 
    AND cpf IS NOT NULL
    AND (
      CASE 
        WHEN REGEXP_CONTAINS(timestamp, r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') 
        THEN PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)
        ELSE PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp)
      END
    ) >= TIMESTAMP('2025-09-05')
GROUP BY dia_semana, nome_dia
ORDER BY dia_semana;


-- 8 Canais de comunicação mais utilizados
SELECT 
    channel,
    action,
    COUNT(*) as frequency,
    COUNT(DISTINCT phone_number) as unique_phones
FROM `rj-superapp.brutos_rmi.rmi_opt_in_history`
WHERE channel IS NOT NULL
    AND PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp) >= TIMESTAMP('2025-09-05')
GROUP BY channel, action
ORDER BY frequency DESC;

-- ==========================================
-- 9. RASTREABILIDADE DE INSCRIÇÕES EM CURSOS
-- ==========================================

-- 9.1 Usuários inscritos e eventos por data de inscrição
WITH inscricoes_usuarios AS (
  SELECT 
    cpf,
    curso_id,
    name,
    enrolled_at,
    DATE(enrolled_at) as data_inscricao,
    status
  FROM `rj-superapp.brutos_go.inscricoes`
  WHERE enrolled_at >= TIMESTAMP('2025-09-05')
    AND cpf IS NOT NULL
),
eventos_usuarios AS (
  SELECT 
    cpf,
    action,
    resource,
    timestamp,
    old_value,
    new_value,
    PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp) as event_timestamp
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL
    AND PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp) >= TIMESTAMP('2025-09-05')
)
SELECT 
  i.cpf,
  i.curso_id,
  i.name,
  i.enrolled_at,
  i.data_inscricao,
  i.status as inscricao_status,
  e.action,
  e.resource,
  e.event_timestamp,
  e.old_value,
  e.new_value,
  -- Classificar se evento foi antes, durante ou após inscrição
  CASE 
    WHEN e.event_timestamp < i.enrolled_at THEN 'Antes da Inscrição'
    WHEN DATE(e.event_timestamp) = i.data_inscricao THEN 'Dia da Inscrição'
    ELSE 'Após Inscrição'
  END as momento_evento
FROM inscricoes_usuarios i
LEFT JOIN eventos_usuarios e ON i.cpf = e.cpf
ORDER BY i.cpf, i.enrolled_at, e.event_timestamp;

-- 9.2 Resumo de eventos por usuário inscrito
WITH inscricoes_usuarios AS (
  SELECT 
    cpf,
    COUNT(DISTINCT curso_id) as total_cursos,
    MIN(enrolled_at) as primeira_inscricao,
    MAX(enrolled_at) as ultima_inscricao,
    STRING_AGG(DISTINCT name, '; ') as cursos_inscritos
  FROM `rj-superapp.brutos_go.inscricoes`
  WHERE enrolled_at >= TIMESTAMP('2025-09-05')
    AND cpf IS NOT NULL
  GROUP BY cpf
),
eventos_resumo AS (
  SELECT 
    cpf,
    COUNT(*) as total_eventos,
    COUNT(DISTINCT action) as tipos_acao_distintos,
    COUNT(DISTINCT resource) as recursos_distintos,
    STRING_AGG(DISTINCT action, '; ') as acoes_realizadas,
    MIN(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)) as primeiro_evento,
    MAX(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp)) as ultimo_evento
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL
    AND PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', timestamp) >= TIMESTAMP('2025-09-05')
  GROUP BY cpf
)
SELECT 
  i.cpf,
  i.total_cursos,
  i.primeira_inscricao,
  i.ultima_inscricao,
  i.cursos_inscritos,
  COALESCE(e.total_eventos, 0) as total_eventos,
  COALESCE(e.tipos_acao_distintos, 0) as tipos_acao_distintos,
  COALESCE(e.recursos_distintos, 0) as recursos_distintos,
  e.acoes_realizadas,
  e.primeiro_evento,
  e.ultimo_evento,
  -- Calcular se usuário teve atividade antes ou depois da inscrição
  CASE 
    WHEN e.primeiro_evento < i.primeira_inscricao THEN 'Usuário Ativo Antes'
    WHEN e.primeiro_evento = i.primeira_inscricao THEN 'Primeiro Evento = Inscrição'
    WHEN e.primeiro_evento > i.primeira_inscricao THEN 'Ativou Após Inscrição'
    ELSE 'Sem Eventos'
  END as perfil_ativacao
FROM inscricoes_usuarios i
LEFT JOIN eventos_resumo e ON i.cpf = e.cpf
ORDER BY i.primeira_inscricao, i.cpf;

-- 9.3 Eventos mais comuns por período pós-inscrição
WITH inscricoes_base AS (
  SELECT 
    cpf,
    enrolled_at,
    curso_id,
    name
  FROM `rj-superapp.brutos_go.inscricoes`
  WHERE enrolled_at >= TIMESTAMP('2025-09-05')
    AND cpf IS NOT NULL
),
eventos_pos_inscricao AS (
  SELECT 
    i.cpf,
    i.curso_id,
    i.name,
    i.enrolled_at,
    e.action,
    e.resource,
    PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp) as event_timestamp,
    -- Calcular diferença em dias desde a inscrição
    DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) as dias_pos_inscricao,
    -- Categorizar período pós-inscrição
    CASE 
      WHEN DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) = 0 THEN 'Dia 0 (Inscrição)'
      WHEN DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) BETWEEN 1 AND 7 THEN 'Primeira Semana'
      WHEN DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) BETWEEN 8 AND 30 THEN 'Primeiro Mês'
      WHEN DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) > 30 THEN 'Após 30 dias'
      ELSE 'Antes da Inscrição'
    END as periodo_pos_inscricao
  FROM inscricoes_base i
  LEFT JOIN `rj-superapp.brutos_rmi.rmi_audit_logs` e ON i.cpf = e.cpf
  WHERE e.timestamp IS NOT NULL
    AND PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp) >= i.enrolled_at
)
SELECT 
  periodo_pos_inscricao,
  action,
  resource,
  COUNT(*) as frequencia_evento,
  COUNT(DISTINCT cpf) as usuarios_unicos,
  ROUND(AVG(dias_pos_inscricao), 2) as media_dias_pos_inscricao
FROM eventos_pos_inscricao
WHERE periodo_pos_inscricao != 'Antes da Inscrição'
GROUP BY periodo_pos_inscricao, action, resource
ORDER BY periodo_pos_inscricao, frequencia_evento DESC;

-- ============================================================
-- 9.3B - VERSÃO OTIMIZADA PARA LOOKER STUDIO
-- GRÁFICO COMBINADO: BARRAS + LINHA
-- ============================================================

-- Query otimizada para gráfico de barras (eventos) + linha (usuários únicos)
-- DIMENSÕES: periodo_ordenado, acao_principal
-- MÉTRICAS BARRAS: total_eventos, eventos_por_acao  
-- MÉTRICAS LINHA: usuarios_unicos_periodo, taxa_engajamento
SELECT 
  CASE 
    WHEN periodo_pos_inscricao = 'Dia 0 (Inscrição)' THEN '1. Dia 0'
    WHEN periodo_pos_inscricao = 'Primeira Semana' THEN '2. Primeira Semana'  
    WHEN periodo_pos_inscricao = 'Primeiro Mês' THEN '3. Primeiro Mês'
    WHEN periodo_pos_inscricao = 'Após 30 dias' THEN '4. Após 30 dias'
    ELSE periodo_pos_inscricao
  END as periodo_ordenado,
  CASE 
    WHEN action IN ('create', 'insert', 'add') THEN 'Criação'
    WHEN action IN ('update', 'edit', 'modify') THEN 'Atualização'  
    WHEN action IN ('delete', 'remove') THEN 'Remoção'
    WHEN action IN ('view', 'read', 'access') THEN 'Visualização'
    ELSE COALESCE(action, 'Outros')
  END as acao_principal,
  frequencia_evento as total_eventos,
  ROUND(frequencia_evento / SUM(frequencia_evento) OVER (PARTITION BY periodo_pos_inscricao) * 100, 1) as pct_eventos_periodo,
  usuarios_unicos as usuarios_unicos_periodo,
  ROUND(usuarios_unicos / SUM(usuarios_unicos) OVER () * 100, 1) as pct_usuarios_total,
  ROUND(frequencia_evento / usuarios_unicos, 2) as eventos_por_usuario,
  ROUND(media_dias_pos_inscricao, 1) as dias_medio_acao,
  resource as recurso_detalhado,
  action as acao_detalhada,
  ROW_NUMBER() OVER (PARTITION BY periodo_pos_inscricao ORDER BY frequencia_evento DESC) as rank_no_periodo,
  ROUND(
    (frequencia_evento * 0.7 + usuarios_unicos * 0.3) / 
    MAX(frequencia_evento * 0.7 + usuarios_unicos * 0.3) OVER (PARTITION BY periodo_pos_inscricao) * 100, 
    1
  ) as indice_atividade

FROM (
  WITH inscricoes_base AS (
    SELECT 
      cpf,
      enrolled_at,
      curso_id,
      name
    FROM `rj-superapp.brutos_go.inscricoes`
    WHERE enrolled_at >= TIMESTAMP('2025-09-05')
      AND cpf IS NOT NULL
  ),
  eventos_pos_inscricao AS (
    SELECT 
      i.cpf,
      i.curso_id,
      i.name,
      i.enrolled_at,
      e.action,
      e.resource,
      PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp) as event_timestamp,
      DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) as dias_pos_inscricao,
      CASE 
        WHEN DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) = 0 THEN 'Dia 0 (Inscrição)'
        WHEN DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) BETWEEN 1 AND 7 THEN 'Primeira Semana'
        WHEN DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) BETWEEN 8 AND 30 THEN 'Primeiro Mês'
        WHEN DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) > 30 THEN 'Após 30 dias'
        ELSE 'Antes da Inscrição'
      END as periodo_pos_inscricao
    FROM inscricoes_base i
    LEFT JOIN `rj-superapp.brutos_rmi.rmi_audit_logs` e ON i.cpf = e.cpf
    WHERE e.timestamp IS NOT NULL
      AND PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp) >= i.enrolled_at
  )
  SELECT 
    periodo_pos_inscricao,
    action,
    resource,
    COUNT(*) as frequencia_evento,
    COUNT(DISTINCT cpf) as usuarios_unicos,
    ROUND(AVG(dias_pos_inscricao), 2) as media_dias_pos_inscricao
  FROM eventos_pos_inscricao
  WHERE periodo_pos_inscricao != 'Antes da Inscrição'
  GROUP BY periodo_pos_inscricao, action, resource
)
ORDER BY 
  periodo_ordenado, 
  rank_no_periodo;


-- Total de eventos por período (ideal para gráfico de pizza)
SELECT 
  CASE 
    WHEN periodo_pos_inscricao = 'Dia 0 (Inscrição)' THEN '1. Dia 0'
    WHEN periodo_pos_inscricao = 'Primeira Semana' THEN '2. Primeira Semana'
    WHEN periodo_pos_inscricao = 'Primeiro Mês' THEN '3. Primeiro Mês'
    WHEN periodo_pos_inscricao = 'Após 30 dias' THEN '4. Após 30 dias'
    ELSE periodo_pos_inscricao
  END as periodo,
  SUM(frequencia_evento) as total_eventos,
  SUM(usuarios_unicos) as total_usuarios_distintos,
  ROUND(AVG(media_dias_pos_inscricao), 1) as media_dias
FROM (
  -- Subquery da análise anterior
  WITH inscricoes_base AS (
    SELECT 
      cpf,
      enrolled_at,
      curso_id,
      name
    FROM `rj-superapp.brutos_go.inscricoes`
    WHERE enrolled_at >= TIMESTAMP('2025-09-05')
      AND cpf IS NOT NULL
  ),
  eventos_pos_inscricao AS (
    SELECT 
      i.cpf,
      i.curso_id,
      i.name,
      i.enrolled_at,
      e.action,
      e.resource,
      PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp) as event_timestamp,
      DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) as dias_pos_inscricao,
      CASE 
        WHEN DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) = 0 THEN 'Dia 0 (Inscrição)'
        WHEN DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) BETWEEN 1 AND 7 THEN 'Primeira Semana'
        WHEN DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) BETWEEN 8 AND 30 THEN 'Primeiro Mês'
        WHEN DATE_DIFF(DATE(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp)), DATE(i.enrolled_at), DAY) > 30 THEN 'Após 30 dias'
        ELSE 'Antes da Inscrição'
      END as periodo_pos_inscricao
    FROM inscricoes_base i
    LEFT JOIN `rj-superapp.brutos_rmi.rmi_audit_logs` e ON i.cpf = e.cpf
    WHERE e.timestamp IS NOT NULL
      AND PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp) >= i.enrolled_at
  )
  SELECT 
    periodo_pos_inscricao,
    action,
    resource,
    COUNT(*) as frequencia_evento,
    COUNT(DISTINCT cpf) as usuarios_unicos,
    ROUND(AVG(dias_pos_inscricao), 2) as media_dias_pos_inscricao
  FROM eventos_pos_inscricao
  WHERE periodo_pos_inscricao != 'Antes da Inscrição'
  GROUP BY periodo_pos_inscricao, action, resource
)
GROUP BY periodo_pos_inscricao
ORDER BY periodo;

-- 9.4 Timeline de atividade por usuário inscrito
WITH timeline_usuario AS (
  SELECT 
    i.cpf,
    i.name,
    i.enrolled_at,
    'INSCRIÇÃO' as tipo_evento,
    i.enrolled_at as event_timestamp,
    CONCAT('Inscrito no curso: ', i.name) as descricao_evento
  FROM `rj-superapp.brutos_go.inscricoes` i
  WHERE i.enrolled_at >= TIMESTAMP('2025-09-05')
    AND i.cpf IS NOT NULL
  
  UNION ALL
  
  SELECT 
    e.cpf,
    NULL as name,
    NULL as enrolled_at,
    'AÇÃO' as tipo_evento,
    PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp) as event_timestamp,
    CONCAT(e.action, ' - ', e.resource, 
           CASE 
             WHEN e.old_value IS NOT NULL AND e.new_value IS NOT NULL 
             THEN CONCAT(' (', e.old_value, ' → ', e.new_value, ')')
             ELSE ''
           END) as descricao_evento
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs` e
  WHERE e.cpf IS NOT NULL 
    AND e.timestamp IS NOT NULL
    AND PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp) >= TIMESTAMP('2025-09-05')
    AND e.cpf IN (
      SELECT DISTINCT cpf 
      FROM `rj-superapp.brutos_go.inscricoes` 
      WHERE enrolled_at >= TIMESTAMP('2025-09-05')
    )
)
SELECT 
  cpf,
  tipo_evento,
  event_timestamp,
  descricao_evento,
  name,
  enrolled_at,
  -- Sequência temporal de eventos por usuário
  ROW_NUMBER() OVER (PARTITION BY cpf ORDER BY event_timestamp) as sequencia_evento
FROM timeline_usuario
ORDER BY cpf, event_timestamp;

-- ============================================================
-- 9.5 Timeline OTIMIZADA com campos detalhados para análise
-- ============================================================

-- Versão expandida da 9.4 com todos os campos solicitados e métricas adicionais
WITH inscricoes_completas AS (
  SELECT 
    cpf,
    name as curso_nome,
    enrolled_at,
    curso_id,
    status as status_inscricao
  FROM `rj-superapp.brutos_go.inscricoes`
  WHERE enrolled_at >= TIMESTAMP('2025-09-05')
    AND cpf IS NOT NULL
),
eventos_inscricao AS (
  SELECT 
    i.cpf,
    i.curso_nome as name,
    i.enrolled_at,
    i.curso_id,
    i.status_inscricao,
    'INSCRIÇÃO' as tipo_evento,
    i.enrolled_at as event_timestamp,
    'inscricao' as resource,
    NULL as action,
    NULL as old_value,
    NULL as new_value,
    CONCAT('Inscrição no curso: ', i.curso_nome) as descricao_evento
  FROM inscricoes_completas i
  
  UNION ALL
  
  SELECT 
    e.cpf,
    i.curso_nome as name,
    i.enrolled_at,
    i.curso_id,
    i.status_inscricao,
    'AÇÃO' as tipo_evento,
    PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp) as event_timestamp,
    e.resource,
    e.action,
    e.old_value,
    e.new_value,
    CONCAT(
      COALESCE(e.action, 'N/A'), ' - ', 
      COALESCE(e.resource, 'N/A'),
      CASE 
        WHEN e.old_value IS NOT NULL AND e.new_value IS NOT NULL 
        THEN CONCAT(' (', e.old_value, ' → ', e.new_value, ')')
        WHEN e.old_value IS NOT NULL 
        THEN CONCAT(' (valor anterior: ', e.old_value, ')')
        WHEN e.new_value IS NOT NULL 
        THEN CONCAT(' (novo valor: ', e.new_value, ')')
        ELSE ''
      END
    ) as descricao_evento
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs` e
  LEFT JOIN inscricoes_completas i ON e.cpf = i.cpf
  WHERE e.cpf IS NOT NULL 
    AND e.timestamp IS NOT NULL
    AND PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*S', e.timestamp) >= TIMESTAMP('2025-09-05')
    AND e.cpf IN (SELECT DISTINCT cpf FROM inscricoes_completas)
),
timeline_enriquecida AS (
  SELECT 
    *,
    -- Sequência temporal por usuário
    ROW_NUMBER() OVER (PARTITION BY cpf ORDER BY event_timestamp) as sequencia_evento,
    -- Sequência por curso (quando aplicável)
    ROW_NUMBER() OVER (PARTITION BY cpf, curso_id ORDER BY event_timestamp) as sequencia_por_curso,
    -- Tempo desde a inscrição (em horas)
    CASE 
      WHEN enrolled_at IS NOT NULL 
      THEN DATETIME_DIFF(DATETIME(event_timestamp), DATETIME(enrolled_at), HOUR)
      ELSE NULL
    END as horas_pos_inscricao,
    -- Classificação temporal
    CASE 
      WHEN tipo_evento = 'INSCRIÇÃO' THEN 'Marco: Inscrição'
      WHEN enrolled_at IS NULL THEN 'Evento Sem Contexto de Curso'
      WHEN event_timestamp < enrolled_at THEN 'Antes da Inscrição'
      WHEN DATE(event_timestamp) = DATE(enrolled_at) THEN 'Mesmo Dia da Inscrição'
      WHEN DATETIME_DIFF(DATETIME(event_timestamp), DATETIME(enrolled_at), HOUR) <= 24 THEN 'Primeiras 24h'
      WHEN DATETIME_DIFF(DATETIME(event_timestamp), DATETIME(enrolled_at), DAY) <= 7 THEN 'Primeira Semana'
      WHEN DATETIME_DIFF(DATETIME(event_timestamp), DATETIME(enrolled_at), DAY) <= 30 THEN 'Primeiro Mês'
      ELSE 'Após Primeiro Mês'
    END as periodo_pos_inscricao
  FROM eventos_inscricao
)
SELECT 
  -- Campos solicitados na ordem especificada
  descricao_evento,
  resource,
  cpf,
  tipo_evento,
  event_timestamp,
  name,
  enrolled_at,
  
  -- Campos adicionais para análise
  curso_id,
  status_inscricao,
  action,
  old_value,
  new_value,
  sequencia_evento,
  sequencia_por_curso,
  horas_pos_inscricao,
  periodo_pos_inscricao,
  
  -- Métricas calculadas
  CASE 
    WHEN horas_pos_inscricao IS NOT NULL AND horas_pos_inscricao >= 0 
    THEN CONCAT('T+', CAST(horas_pos_inscricao AS STRING), 'h')
    WHEN horas_pos_inscricao IS NOT NULL AND horas_pos_inscricao < 0 
    THEN CONCAT('T', CAST(horas_pos_inscricao AS STRING), 'h')
    ELSE 'N/A'
  END as tempo_relativo_inscricao,
  
  -- Flag de primeiro evento por tipo
  CASE 
    WHEN ROW_NUMBER() OVER (PARTITION BY cpf, resource ORDER BY event_timestamp) = 1 
    THEN TRUE 
    ELSE FALSE 
  END as primeiro_evento_recurso

FROM timeline_enriquecida
ORDER BY cpf, event_timestamp, sequencia_evento;


-- ANÁLISE DE FREQUÊNCIA DE ALTERAÇÕES POR RECURSO COM PERCENTUAL DE USUÁRIOS
SELECT 
    resource as alteracao,
    COUNT(*) AS frequencia,
    COUNT(DISTINCT cpf) AS usuarios_unicos,
    ROUND(COUNT(DISTINCT cpf) * 100.0 / (
        SELECT COUNT(DISTINCT cpf) 
        FROM `rj-superapp.brutos_rmi.rmi_audit_logs` 
        WHERE action IS NOT NULL 
        AND TIMESTAMP_TRUNC(_airbyte_extracted_at, DAY) >= TIMESTAMP("2025-09-05")
    ), 2) AS percentual_usuarios
FROM `rj-superapp.brutos_rmi.rmi_audit_logs` t
WHERE action IS NOT NULL
AND TIMESTAMP_TRUNC(_airbyte_extracted_at, DAY) >= TIMESTAMP("2025-09-05")
GROUP BY 1
ORDER BY 2 DESC;

