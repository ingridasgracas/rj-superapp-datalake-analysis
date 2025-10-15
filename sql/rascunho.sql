
-- Usuários únicos por dia da semana (a partir de 05/09/2025)
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
    AND TIMESTAMP(timestamp) >= '2025-09-05'
GROUP BY dia_semana, nome_dia
ORDER BY dia_semana;
