# Table Schema: rj-superapp.brutos_rmi

## rmi_audit_logs
```csv
Column,Type,Mode,Description
_airbyte_raw_id,STRING,REQUIRED,ID único do registro Airbyte
_airbyte_extracted_at,TIMESTAMP,REQUIRED,Timestamp de extração
_airbyte_meta,JSON,REQUIRED,Metadados Airbyte
_airbyte_generation_id,INT64,NULLABLE,ID da geração Airbyte
_id,STRING,NULLABLE,ID interno do registro
cpf,STRING,NULLABLE,CPF do usuário (chave de ligação)
action,STRING,NULLABLE,Tipo de ação realizada
resource,STRING,NULLABLE,Recurso afetado
old_value,STRING,NULLABLE,Valor anterior
new_value,STRING,NULLABLE,Valor novo
timestamp,STRING,NULLABLE,Timestamp da ação
ip_address,STRING,NULLABLE,IP do usuário
user_agent,STRING,NULLABLE,User agent do navegador
request_id,STRING,NULLABLE,ID da requisição
metadata_field,STRING,NULLABLE,Campo de metadados
metadata_phone,STRING,NULLABLE,Telefone nos metadados
metadata_operation,STRING,NULLABLE,Tipo de operação
```

## rmi_avatars
```csv
Column,Type,Mode,Description
_airbyte_raw_id,STRING,REQUIRED,ID único do registro Airbyte
_airbyte_extracted_at,TIMESTAMP,REQUIRED,Timestamp de extração
_id,STRING,NULLABLE,ID interno
cpf,STRING,NULLABLE,CPF - Chave universal
name,STRING,NULLABLE,Nome do usuário
nome,STRING,NULLABLE,Nome alternativo
raca,STRING,NULLABLE,Raça/cor
sexo,STRING,NULLABLE,Sexo
mae_cpf,JSON,NULLABLE,CPF da mãe
mae_nome,STRING,NULLABLE,Nome da mãe
menor_idade,BOOL,NULLABLE,Indicador menor de idade
nascimento_data,STRING,NULLABLE,Data de nascimento
nascimento_uf,STRING,NULLABLE,UF de nascimento
nascimento_pais,STRING,NULLABLE,País de nascimento
nascimento_municipio,STRING,NULLABLE,Município de nascimento
obito_indicador,BOOL,NULLABLE,Indicador de óbito
obito_ano,INT64,NULLABLE,Ano do óbito
email_principal,JSON,NULLABLE,Email principal (JSON)
email_principal_valor,STRING,NULLABLE,Valor do email principal
telefone_principal,JSON,NULLABLE,Telefone principal (JSON)
telefone_principal_valor,STRING,NULLABLE,Valor do telefone principal
telefone_principal_ddd,STRING,NULLABLE,DDD do telefone principal
endereco_principal,JSON,NULLABLE,Endereço principal (JSON)
endereco_principal_cep,STRING,NULLABLE,CEP do endereço principal
endereco_principal_bairro,STRING,NULLABLE,Bairro do endereço principal
endereco_principal_municipio,STRING,NULLABLE,Município do endereço principal
endereco_principal_logradouro,STRING,NULLABLE,Logradouro do endereço principal
assistencia_social_cadunico_indicador,BOOL,NULLABLE,Indicador CadÚnico
assistencia_social_cras_nome,STRING,NULLABLE,Nome do CRAS
saude_clinica_familia_indicador,BOOL,NULLABLE,Indicador clínica da família
saude_clinica_familia_nome,STRING,NULLABLE,Nome da clínica da família
datalake_last_updated,STRING,NULLABLE,Última atualização no data lake
```

## rmi_beta_groups
```csv
Column,Type,Mode,Description
_airbyte_raw_id,STRING,REQUIRED,ID único do registro Airbyte
_airbyte_extracted_at,TIMESTAMP,REQUIRED,Timestamp de extração
_id,STRING,NULLABLE,ID interno
cpf,STRING,NULLABLE,CPF do usuário
status,STRING,NULLABLE,Status no grupo beta
phone_number,STRING,NULLABLE,Número de telefone
beta_group_id,STRING,NULLABLE,ID do grupo beta
created_at,STRING,NULLABLE,Data de criação
updated_at,STRING,NULLABLE,Data de atualização
```

## rmi_opt_in_history
```csv
Column,Type,Mode,Description
_airbyte_raw_id,STRING,REQUIRED,ID único do registro Airbyte
_airbyte_extracted_at,TIMESTAMP,REQUIRED,Timestamp de extração
_id,STRING,NULLABLE,ID interno
cpf,STRING,NULLABLE,CPF do usuário
action,STRING,NULLABLE,Ação (opt-in/opt-out)
channel,STRING,NULLABLE,Canal (SMS WhatsApp Email)
reason,STRING,NULLABLE,Motivo da ação
phone_number,STRING,NULLABLE,Número de telefone
timestamp,STRING,NULLABLE,Timestamp da ação
```

## rmi_phone_cpf_mappings
```csv
Column,Type,Mode,Description
_airbyte_raw_id,STRING,REQUIRED,ID único do registro Airbyte
_airbyte_extracted_at,TIMESTAMP,REQUIRED,Timestamp de extração
_id,STRING,NULLABLE,ID interno
cpf,STRING,NULLABLE,CPF do usuário
nome,STRING,NULLABLE,Nome do usuário
phone_number,STRING,NULLABLE,Número de telefone
```

## rmi_self_declared
```csv
Column,Type,Mode,Description
_airbyte_raw_id,STRING,REQUIRED,ID único do registro Airbyte
_airbyte_extracted_at,TIMESTAMP,REQUIRED,Timestamp de extração
_id,STRING,NULLABLE,ID interno
cpf,STRING,NULLABLE,CPF do usuário
name,STRING,NULLABLE,Nome
created_at,STRING,NULLABLE,Data de criação
updated_at,STRING,NULLABLE,Data de atualização
```

## rmi_users_config
```csv
Column,Type,Mode,Description
_airbyte_raw_id,STRING,REQUIRED,ID único do registro Airbyte
_airbyte_extracted_at,TIMESTAMP,REQUIRED,Timestamp de extração
_id,STRING,NULLABLE,ID interno
name,STRING,NULLABLE,Nome
cpf,STRING,NULLABLE,CPF do usuário
created_at,STRING,NULLABLE,Data de criação
updated_at,STRING,NULLABLE,Data de atualização
```