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
    MIN(TIMESTAMP(timestamp)) as first_interaction,
    MAX(TIMESTAMP(timestamp)) as last_interaction
  FROM `rj-superapp.brutos_rmi.rmi_audit_logs`
  WHERE cpf IS NOT NULL 
    AND timestamp IS NOT NULL
    AND TIMESTAMP(timestamp) >= '2025-09-05'
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
    AND (i.enrolled_at >= '2025-09-05' OR i.updated_at >= '2025-09-05')
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