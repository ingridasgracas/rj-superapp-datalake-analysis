# Table Schema: rj-superapp.brutos_go

## cursos
```csv
Column,Type,Mode,Description
_airbyte_raw_id,STRING,REQUIRED,ID único do registro Airbyte
_airbyte_extracted_at,TIMESTAMP,REQUIRED,Timestamp de extração
id,INT64,NULLABLE,ID único do curso
titulo,STRING,NULLABLE,Título do curso
theme,STRING,NULLABLE,Tema/categoria
modalidade,STRING,NULLABLE,Modalidade (presencial/online/híbrido)
turno,STRING,NULLABLE,Turno (manhã/tarde/noite)
carga_horaria,INT64,NULLABLE,Carga horária total
numero_vagas,INT64,NULLABLE,Número de vagas
data_inicio,DATETIME,NULLABLE,Data de início
data_termino,DATETIME,NULLABLE,Data de término
enrollment_start_date,TIMESTAMP,NULLABLE,Início das inscrições
enrollment_end_date,TIMESTAMP,NULLABLE,Fim das inscrições
data_limite_inscricoes,DATETIME,NULLABLE,Limite para inscrições
descricao,STRING,NULLABLE,Descrição do curso
objectives,STRING,NULLABLE,Objetivos de aprendizagem
methodology,STRING,NULLABLE,Metodologia aplicada
program_content,STRING,NULLABLE,Conteúdo programático
target_audience,STRING,NULLABLE,Público-alvo
pre_requisitos,STRING,NULLABLE,Pré-requisitos
material_used,STRING,NULLABLE,Materiais utilizados
teaching_material,STRING,NULLABLE,Material didático
resources_used,STRING,NULLABLE,Recursos pedagógicos
formato_aula,STRING,NULLABLE,Formato das aulas
facilitator,STRING,NULLABLE,Facilitador/Instrutor
organization,STRING,NULLABLE,Organização responsável
orgao_id,INT64,NULLABLE,ID do órgão
instituicao_id,INT64,NULLABLE,ID da instituição
local_realizacao,STRING,NULLABLE,Local de realização
has_certificate,BOOL,NULLABLE,Oferece certificado
certificacao_oferecida,BOOL,NULLABLE,Certificação disponível
contato_duvidas,STRING,NULLABLE,Contato para dúvidas
link_inscricao,STRING,NULLABLE,Link de inscrição
cover_image,STRING,NULLABLE,Imagem de capa
institutional_logo,STRING,NULLABLE,Logo institucional
status,STRING,NULLABLE,Status do curso
created_at,TIMESTAMP,NULLABLE,Data de criação
updated_at,TIMESTAMP,NULLABLE,Data de atualização
```

## inscricoes
```csv
Column,Type,Mode,Description
_airbyte_raw_id,STRING,REQUIRED,ID único do registro Airbyte
_airbyte_extracted_at,TIMESTAMP,REQUIRED,Timestamp de extração
id,STRING,NULLABLE,ID da inscrição
cpf,STRING,NULLABLE,CPF do usuário (chave de ligação)
curso_id,INT64,NULLABLE,ID do curso (FK)
name,STRING,NULLABLE,Nome do usuário
email,STRING,NULLABLE,Email do usuário
phone,STRING,NULLABLE,Telefone do usuário
status,STRING,NULLABLE,Status (Inscrito/Concluído/Cancelado)
reason,STRING,NULLABLE,Motivo/observações
enrolled_at,TIMESTAMP,NULLABLE,Data de inscrição
concluded_at,TIMESTAMP,NULLABLE,Data de conclusão
updated_at,TIMESTAMP,NULLABLE,Última atualização
certificate_url,STRING,NULLABLE,URL do certificado
admin_notes,STRING,NULLABLE,Notas administrativas
custom_fields_data,STRING,NULLABLE,Dados customizados
```