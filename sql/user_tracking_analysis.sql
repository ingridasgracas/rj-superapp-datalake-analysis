-- ========================================
-- ANÁLISE EXPLORATÓRIA DE TRACKING DE USUÁRIOS
-- Datasets: -- 2.2.2 BREADCRuser_action_paths AS (
  SELECT 
    cpf,
    action,
    resource,
    timestamp,
    old_value,
    new_value,
    ROW_NUMBER() OVER (PARTITION BY cpf ORDER BY TIMESTAMP(timestamp)) as action_sequence
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND old_value IS NOT NULL 
    AND resource = 'phone'
),completo de navegação
WITH user_actions AS (
  SELECT 
    cpf,
    action,
    resource,
    timestamp,
    old_value,
    new_value,
    ROW_NUMBER() OVER (PARTITION BY cpf ORDER BY TIMESTAMP(timestamp)) as action_sequence
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND old_value IS NOT NULL 
    AND resource = 'phone'
),os_rmi e rj-superapp.brutos_go
-- ========================================

-- ==========================================
-- 1. INVENTÁRIO DE USUÁRIOS ÚNICOS
-- ==========================================

-- 1.1 Contagem de usuários únicos por dataset
SELECT 'RMI Audit Logs' as dataset, COUNT(DISTINCT cpf) as usuarios_unicos
FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
WHERE cpf IS NOT NULL
  AND TIMESTAMP(timestamp) >= '2025-09-05'

UNION ALL

SELECT 'RMI Avatars' as dataset, COUNT(DISTINCT cpf) as usuarios_unicos
FROM `rj-superapp.brutos_rmi.rmi_avatars`
WHERE cpf IS NOT NULL

UNION ALL

SELECT 'RMI Beta Groups' as dataset, COUNT(DISTINCT cpf) as usuarios_unicos
FROM `rj-superapp.brutos_rmi.rmi_beta_groups`
WHERE cpf IS NOT NULL

UNION ALL

SELECT 'RMI Opt-in History' as dataset, COUNT(DISTINCT cpf) as usuarios_unicos
FROM `rj-superapp.brutos_rmi.rmi_opt_in_history`
WHERE cpf IS NOT NULL

UNION ALL

SELECT 'GO Inscricoes' as dataset, COUNT(DISTINCT cpf) as usuarios_unicos
FROM `rj-superapp.brutos_go.inscricoes`
WHERE cpf IS NOT NULL;

-- ==========================================
-- 2. ANÁLISE DE EVENTOS DE AUDITORIA (RMI) COM BREADCRUMBS
-- ==========================================
-- 
-- CONCEITO DE BREADCRUMBS NO BIGQUERY:
-- Como o BigQuery não suporta CTEs recursivas como Oracle/PostgreSQL,
-- usamos window functions com ARRAY_AGG para criar caminhos de navegação.
-- 
-- Diferentes abordagens implementadas:
-- 1. Breadcrumb simples: ação + sequência
-- 2. Breadcrumb completo: caminho completo de ações
-- 3. Breadcrumb contextual: jornada com detalhes das mudanças
-- 4. Análise de padrões: identificação de tipos de jornada
-- ==========================================

-- 2.1 Tipos de ações mais frequentes
SELECT 
    action,
    resource,
    COUNT(*) as frequency,
    COUNT(DISTINCT cpf) as unique_users
FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
WHERE action IS NOT NULL
  AND TIMESTAMP(timestamp) >= '2025-09-05'
GROUP BY action, resource
ORDER BY frequency DESC
LIMIT 20;

-- 2.2 Timeline de ações por usuário com breadcrumbs
SELECT cpf,
    action,
    resource,
    timestamp,
    old_value,
    new_value
FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
WHERE cpf IS NOT NULL 
  AND timestamp IS NOT NULL 
  AND old_value IS NOT NULL 
  AND resource = 'phone'
  AND TIMESTAMP(timestamp) >= '2025-09-05'
ORDER BY cpf DESC;

-- 2.2.1 BREADCRUMBS - Caminho de ações por usuário (Versão Simples)
WITH user_actions AS (
  SELECT 
    cpf,
    action,
    resource,
    timestamp,
    old_value,
    new_value,
    ROW_NUMBER() OVER (PARTITION BY cpf ORDER BY TIMESTAMP(timestamp)) as action_sequence
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND old_value IS NOT NULL 
    AND resource = 'phone'
)
SELECT 
  cpf,
  action,
  resource,
  timestamp,
  old_value,
  new_value,
  action_sequence,
  -- Breadcrumb simples: ação atual + sequência
  CONCAT(action, ' (', action_sequence, ')') as action_breadcrumb
FROM user_actions
ORDER BY cpf, action_sequence;

-- 2.2.2 BREADCRUMBS - Caminho completo de ações por usuário
WITH user_actions_ordered AS (
  SELECT 
    cpf,
    action,
    resource,
    timestamp,
    old_value,
    new_value,
    ROW_NUMBER() OVER (PARTITION BY cpf ORDER BY TIMESTAMP(timestamp)) as action_sequence
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND old_value IS NOT NULL 
    AND resource = 'phone'
    AND TIMESTAMP(timestamp) >= '2025-09-05'
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

-- 2.2.3 BREADCRUMBS - Jornada com contexto de mudanças
WITH user_phone_journey AS (
  SELECT 
    cpf,
    action,
    resource,
    timestamp,
    old_value,
    new_value,
    ROW_NUMBER() OVER (PARTITION BY cpf ORDER BY TIMESTAMP(timestamp)) as step_number,
    LAG(new_value) OVER (PARTITION BY cpf ORDER BY TIMESTAMP(timestamp)) as previous_value
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND old_value IS NOT NULL 
    AND resource = 'phone'
    AND TIMESTAMP(timestamp) >= '2025-09-05'
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

-- 2.2.4 BREADCRUMBS - Análise de padrões de jornada
WITH user_journey_patterns AS (
  SELECT 
    cpf,
    ARRAY_AGG(action ORDER BY TIMESTAMP(timestamp)) as action_sequence,
    COUNT(*) as total_actions,
    MIN(timestamp) as first_action_time,
    MAX(timestamp) as last_action_time
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL 
    AND old_value IS NOT NULL 
    AND resource = 'phone'
    AND TIMESTAMP(timestamp) >= '2025-09-05'
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

-- ==========================================
-- 3. ANÁLISE DE OPT-IN/OPT-OUT
-- ==========================================

-- 3.1 Distribuição de ações de opt-in/opt-out
SELECT 
    action,
    channel,
    reason,
    COUNT(*) as frequency,
    COUNT(DISTINCT cpf) as unique_users
FROM `rj-superapp.brutos_rmi.rmi_opt_in_history`
GROUP BY action, channel, reason
ORDER BY frequency DESC;

-- 3.2 Usuários com histórico de opt-out
SELECT 
    cpf,
    phone_number,
    action,
    reason,
    timestamp
FROM `rj-superapp.brutos_rmi.rmi_opt_in_history`
WHERE action LIKE '%opt%'
    AND cpf IS NOT NULL
    AND TIMESTAMP(timestamp) >= '2025-09-05'
ORDER BY cpf, TIMESTAMP(timestamp) DESC;

-- ==========================================
-- 4. ANÁLISE DE ENGAJAMENTO EM CURSOS (GO)
-- ==========================================

-- 4.1 Jornada do usuário em cursos
SELECT 
    i.cpf,
    i.name,
    i.email,
    i.status,
    i.reason,
    i.enrolled_at,
    i.concluded_at,
    c.titulo as curso_titulo,
    c.modalidade,
    c.carga_horaria,
    CASE 
        WHEN i.concluded_at IS NOT NULL THEN 'Concluído'
        WHEN i.enrolled_at IS NOT NULL THEN 'Em Andamento'
        ELSE 'Inscrito'
    END as status_jornada
FROM `rj-superapp.brutos_go.inscricoes` i
LEFT JOIN `rj-superapp.brutos_go.cursos` c ON i.curso_id = c.id
WHERE i.cpf IS NOT NULL
ORDER BY i.cpf, i.enrolled_at DESC;

-- 4.2 Taxa de conclusão por curso
SELECT 
    c.titulo,
    c.modalidade,
    COUNT(*) as total_inscricoes,
    COUNT(i.concluded_at) as total_conclusoes,
    ROUND(COUNT(i.concluded_at) * 100.0 / COUNT(*), 2) as taxa_conclusao_pct
FROM `rj-superapp.brutos_go.inscricoes` i
JOIN `rj-superapp.brutos_go.cursos` c ON i.curso_id = c.id
GROUP BY c.titulo, c.modalidade
HAVING COUNT(*) >= 10  -- Apenas cursos com pelo menos 10 inscrições
ORDER BY taxa_conclusao_pct DESC;

-- ==========================================
-- 5. ANÁLISE CROSS-PLATFORM
-- ==========================================

-- 5.1 Usuários presentes em ambas as plataformas
WITH rmi_users AS (
    SELECT DISTINCT cpf
    FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
    WHERE cpf IS NOT NULL
),
go_users AS (
    SELECT DISTINCT cpf
    FROM `rj-superapp.brutos_go.inscricoes`
    WHERE cpf IS NOT NULL
)
SELECT 
    'Apenas RMI' as segmento,
    COUNT(*) as usuarios
FROM rmi_users r
WHERE r.cpf NOT IN (SELECT cpf FROM go_users)

UNION ALL

SELECT 
    'Apenas GO' as segmento,
    COUNT(*) as usuarios
FROM go_users g
WHERE g.cpf NOT IN (SELECT cpf FROM rmi_users)

UNION ALL

SELECT 
    'Ambas Plataformas' as segmento,
    COUNT(*) as usuarios
FROM rmi_users r
WHERE r.cpf IN (SELECT cpf FROM go_users);

-- ==========================================
-- 6. ANÁLISE TEMPORAL DE ATIVIDADE
-- ==========================================

-- 6.1 Atividade por dia da semana (RMI Audit Logs)
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
    COUNT(*) as total_eventos,
    COUNT(DISTINCT cpf) as usuarios_unicos
FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
WHERE timestamp IS NOT NULL
  AND TIMESTAMP(timestamp) >= '2025-09-05'
GROUP BY dia_semana, nome_dia
ORDER BY dia_semana;

-- 6.2 Horários de maior atividade
SELECT 
    EXTRACT(HOUR FROM TIMESTAMP(timestamp)) as hora,
    COUNT(*) as total_eventos,
    COUNT(DISTINCT cpf) as usuarios_unicos
FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
WHERE timestamp IS NOT NULL
  AND TIMESTAMP(timestamp) >= '2025-09-05'
GROUP BY hora
ORDER BY hora;

-- ==========================================
-- 7. ANÁLISE DE COMPORTAMENTO BETA
-- ==========================================

-- 7.1 Usuários em grupos beta
SELECT 
    beta_group_id,
    status,
    COUNT(*) as usuarios,
    MIN(created_at) as primeira_entrada,
    MAX(updated_at) as ultima_atualizacao
FROM `rj-superapp.brutos_rmi.rmi_beta_groups`
WHERE beta_group_id IS NOT NULL
GROUP BY beta_group_id, status
ORDER BY usuarios DESC;

-- ==========================================
-- 8. ANÁLISE DE CONVERSÃO EDUCACIONAL
-- ==========================================

-- 8.1 Tempo médio entre inscrição e conclusão
SELECT 
    c.modalidade,
    COUNT(*) as cursos_concluidos,
    AVG(TIMESTAMP_DIFF(i.concluded_at, i.enrolled_at, DAY)) as tempo_medio_dias,
    MIN(TIMESTAMP_DIFF(i.concluded_at, i.enrolled_at, DAY)) as tempo_minimo_dias,
    MAX(TIMESTAMP_DIFF(i.concluded_at, i.enrolled_at, DAY)) as tempo_maximo_dias
FROM `rj-superapp.brutos_go.inscricoes` i
JOIN `rj-superapp.brutos_go.cursos` c ON i.curso_id = c.id
WHERE i.enrolled_at IS NOT NULL 
    AND i.concluded_at IS NOT NULL
    AND i.concluded_at > i.enrolled_at
GROUP BY c.modalidade
ORDER BY tempo_medio_dias;

-- ==========================================
-- 9. ANÁLISE DE COMUNICAÇÃO E CONTATO
-- ==========================================

-- 9.1 Canais de comunicação mais utilizados
SELECT 
    channel,
    action,
    COUNT(*) as frequency,
    COUNT(DISTINCT phone_number) as unique_phones
FROM `rj-superapp.brutos_rmi.rmi_opt_in_history`
WHERE channel IS NOT NULL
GROUP BY channel, action
ORDER BY frequency DESC;

-- ==========================================
-- 10. QUERY DE EXEMPLO PARA TRACKING COMPLETO
-- ==========================================

-- 10.1 Visão 360 do usuário (exemplo com um CPF específico)
-- Substitua 'XXX.XXX.XXX-XX' pelo CPF desejado
/*
WITH user_cpf AS (SELECT 'XXX.XXX.XXX-XX' as target_cpf)

SELECT 
    'RMI Audit' as fonte,
    a.timestamp as evento_timestamp,
    a.action as evento,
    a.resource as detalhe,
    a.old_value,
    a.new_value
FROM `rj-superapp.brutos_rmi.rmi_audit_logs` a
CROSS JOIN user_cpf u
WHERE a.cpf = u.target_cpf
  AND TIMESTAMP(a.timestamp) >= '2025-09-05'

UNION ALL

SELECT 
    'RMI Opt-in' as fonte,
    o.timestamp as evento_timestamp,
    o.action as evento,
    o.channel as detalhe,
    o.reason as old_value,
    NULL as new_value
FROM `rj-superapp.brutos_rmi.rmi_opt_in_history` o
CROSS JOIN user_cpf u
WHERE o.cpf = u.target_cpf

UNION ALL

SELECT 
    'GO Inscricao' as fonte,
    CAST(i.enrolled_at as STRING) as evento_timestamp,
    'Enrolled' as evento,
    c.titulo as detalhe,
    i.status as old_value,
    CAST(i.concluded_at as STRING) as new_value
FROM `rj-superapp.brutos_go.inscricoes` i
JOIN `rj-superapp.brutos_go.cursos` c ON i.curso_id = c.id
CROSS JOIN user_cpf u
WHERE i.cpf = u.target_cpf

ORDER BY evento_timestamp DESC;
*/