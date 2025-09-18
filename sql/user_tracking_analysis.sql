-- ========================================
-- ANÁLISE EXPLORATÓRIA DE TRACKING DE USUÁRIOS
-- Datasets: rj-superapp.brutos_rmi e rj-superapp.brutos_go
-- ========================================

-- ==========================================
-- 1. INVENTÁRIO DE USUÁRIOS ÚNICOS
-- ==========================================

-- 1.1 Contagem de usuários únicos por dataset
SELECT 'RMI Audit Logs' as dataset, COUNT(DISTINCT cpf) as usuarios_unicos
FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
WHERE cpf IS NOT NULL

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
-- 2. ANÁLISE DE EVENTOS DE AUDITORIA (RMI)
-- ==========================================

-- 2.1 Tipos de ações mais frequentes
SELECT 
    action,
    resource,
    COUNT(*) as frequency,
    COUNT(DISTINCT cpf) as unique_users
FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
WHERE action IS NOT NULL
GROUP BY action, resource
ORDER BY frequency DESC
LIMIT 20;

-- 2.2 Timeline de ações por usuário (últimos 30 dias)
SELECT 
    cpf,
    action,
    resource,
    timestamp,
    old_value,
    new_value
FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL
    AND PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp) >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
ORDER BY cpf, PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp) DESC;

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
ORDER BY cpf, PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp) DESC;

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
    EXTRACT(DAYOFWEEK FROM PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp)) as dia_semana,
    CASE EXTRACT(DAYOFWEEK FROM PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp))
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
GROUP BY dia_semana, nome_dia
ORDER BY dia_semana;

-- 6.2 Horários de maior atividade
SELECT 
    EXTRACT(HOUR FROM PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp)) as hora,
    COUNT(*) as total_eventos,
    COUNT(DISTINCT cpf) as usuarios_unicos
FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
WHERE timestamp IS NOT NULL
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

-- ==========================================
-- 11. MATERIALIZAÇÃO DA ENTIDADE USER-JOURNEY
-- ==========================================

-- 11.1 Criação da view USER_JOURNEY consolidando dados cross-platform
CREATE OR REPLACE VIEW `rj-superapp.analytics.user_journey` AS
WITH rmi_activity AS (
  SELECT 
    cpf,
    'RMI' as platform,
    COUNT(*) as total_actions,
    MIN(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp)) as first_interaction,
    MAX(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S', timestamp)) as last_interaction
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL AND timestamp IS NOT NULL
  GROUP BY cpf
),
go_activity AS (
  SELECT 
    i.cpf,
    'GO' as platform,
    COUNT(DISTINCT i.curso_id) as total_courses,
    COUNT(*) as total_enrollments,
    MIN(i.enrolled_at) as first_enrollment,
    MAX(i.updated_at) as last_activity,
    COUNT(i.concluded_at) as completed_courses
  FROM `rj-superapp.brutos_go.inscricoes` i
  WHERE i.cpf IS NOT NULL
  GROUP BY i.cpf
),
user_base AS (
  SELECT DISTINCT cpf
  FROM (
    SELECT cpf FROM `rj-superapp.brutos_rmi.rmi_avatars` WHERE cpf IS NOT NULL
    UNION DISTINCT
    SELECT cpf FROM `rj-superapp.brutos_go.inscricoes` WHERE cpf IS NOT NULL
  )
)
SELECT 
  u.cpf,
  CASE 
    WHEN r.cpf IS NOT NULL AND g.cpf IS NOT NULL THEN 'BOTH'
    WHEN r.cpf IS NOT NULL THEN 'RMI'
    WHEN g.cpf IS NOT NULL THEN 'GO'
    ELSE 'UNKNOWN'
  END as platform,
  COALESCE(
    LEAST(r.first_interaction, g.first_enrollment),
    r.first_interaction,
    g.first_enrollment
  ) as first_interaction,
  COALESCE(
    GREATEST(r.last_interaction, g.last_activity),
    r.last_interaction,
    g.last_activity
  ) as last_interaction,
  COALESCE(r.total_actions, 0) as total_actions,
  COALESCE(g.total_courses, 0) as total_courses,
  COALESCE(g.total_enrollments, 0) as total_enrollments,
  COALESCE(g.completed_courses, 0) as completed_courses,
  CASE 
    WHEN COALESCE(r.total_actions, 0) + COALESCE(g.total_enrollments, 0) >= 10 THEN 'Alto'
    WHEN COALESCE(r.total_actions, 0) + COALESCE(g.total_enrollments, 0) >= 3 THEN 'Médio'
    ELSE 'Baixo'
  END as engagement_level,
  CASE 
    WHEN g.total_courses > 0 AND g.completed_courses > 0 
    THEN ROUND(g.completed_courses * 100.0 / g.total_courses, 2)
    ELSE 0
  END as completion_rate
FROM user_base u
LEFT JOIN rmi_activity r ON u.cpf = r.cpf
LEFT JOIN go_activity g ON u.cpf = g.cpf;

-- 11.2 Análise de segmentos de usuários baseada na jornada
SELECT 
  platform,
  engagement_level,
  COUNT(*) as usuarios,
  AVG(total_actions) as media_acoes,
  AVG(total_courses) as media_cursos,
  AVG(completion_rate) as taxa_conclusao_media,
  MIN(first_interaction) as primeira_interacao,
  MAX(last_interaction) as ultima_interacao
FROM `rj-superapp.analytics.user_journey`
GROUP BY platform, engagement_level
ORDER BY platform, engagement_level;

-- 11.3 Identificação de usuários churned (sem atividade recente)
SELECT 
  cpf,
  platform,
  engagement_level,
  last_interaction,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), last_interaction, DAY) as dias_sem_atividade,
  total_actions,
  total_courses,
  completion_rate
FROM `rj-superapp.analytics.user_journey`
WHERE last_interaction < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND engagement_level IN ('Alto', 'Médio')
ORDER BY dias_sem_atividade DESC, engagement_level;

-- 11.4 Análise de conversão RMI → GO
SELECT 
  'Apenas RMI' as segmento,
  COUNT(*) as usuarios,
  AVG(total_actions) as media_acoes_rmi
FROM `rj-superapp.analytics.user_journey`
WHERE platform = 'RMI'

UNION ALL

SELECT 
  'RMI + GO' as segmento,
  COUNT(*) as usuarios,
  AVG(total_actions) as media_acoes_rmi
FROM `rj-superapp.analytics.user_journey`
WHERE platform = 'BOTH'

UNION ALL

SELECT 
  'Apenas GO' as segmento,
  COUNT(*) as usuarios,
  0 as media_acoes_rmi
FROM `rj-superapp.analytics.user_journey`
WHERE platform = 'GO';

-- 11.5 Coorte de retenção por mês de primeira interação
WITH monthly_cohorts AS (
  SELECT 
    cpf,
    DATE_TRUNC(first_interaction, MONTH) as cohort_month,
    last_interaction,
    platform
  FROM `rj-superapp.analytics.user_journey`
  WHERE first_interaction IS NOT NULL
),
cohort_retention AS (
  SELECT 
    cohort_month,
    platform,
    COUNT(DISTINCT cpf) as cohort_size,
    COUNT(DISTINCT CASE 
      WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), last_interaction, DAY) <= 30 
      THEN cpf 
    END) as active_30d,
    COUNT(DISTINCT CASE 
      WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), last_interaction, DAY) <= 90 
      THEN cpf 
    END) as active_90d
  FROM monthly_cohorts
  GROUP BY cohort_month, platform
)
SELECT 
  cohort_month,
  platform,
  cohort_size,
  active_30d,
  active_90d,
  ROUND(active_30d * 100.0 / cohort_size, 2) as retention_30d_pct,
  ROUND(active_90d * 100.0 / cohort_size, 2) as retention_90d_pct
FROM cohort_retention
WHERE cohort_size >= 10  -- Apenas coortes com pelo menos 10 usuários
ORDER BY cohort_month DESC, platform;