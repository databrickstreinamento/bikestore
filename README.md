# Projeto Bikestore
---
## Objetivo
Esse repositório foi criado para realização de um treinamento básico na plataforma do Databricks. Estamos usando a versão Free Edition e GitHub como ambiente.

---
## Dados do projeto
Optamos por usar o conjunto de dados disponível no Kaggle, [Bikestore](https://www.kaggle.com/datasets/dillonmyrick/bike-store-sample-database/data), por conter um volume de registros e arquivos bons para exemplificarmos as principais funcionalidades.

---
## Conceitos principais

**Nosso Objetivo:** Criar a estrutura de catálogos, schemas e volumes necessários para o workshop

### O que é a Arquitetura Medallion?

A arquitetura **Medallion** é um padrão de design para organizar dados em lakehouse, dividindo em 3 camadas:

- **🥉 Bronze (Raw)**: Dados brutos, cópia fiel da origem
  - Formato: como veio da fonte
  - Propósito: auditoria, reprocessamento, histórico

- **🥈 Silver (Refined)**: Dados limpos e conformados
  - Formato: validado, tipado, deduplicado
  - Propósito: dados confiáveis para análise

- **🥇 Gold (Curated)**: Dados prontos para consumo
  - Formato: agregado, otimizado, modelado
  - Propósito: dashboards, relatórios, ML

_NOTA_: esse é um padrão que a Databricks vem utilizando. Outros _vendors_ adotam nomes diferentes para essa arquitetura. Alguns exemplos:

- Camada Bronze - Nomes Comuns: `RAW`, `LANDING`, `STAGING`                     
- Camada Silver - Nomes Comuns: `STAGING` (para transformação), `REFINED`, `CLEANSED`,`CONFORMED`                                                                              
- Camada Gold - Nomes Comuns: `ANALYTICS`, `CONSUMPTION`, `PRESENTATION`, `MART`, `BUSINESS`

Há quem opte por criar uma camada adicional (como nós) para armazenar os dados que estão chegando, antes de carregar na bronze. Isso pode ser útil para fins de auditoria em ambientes que precisam de uma rastreabilidade maior.

---

## Unity Catalog: Coração da plataforma

No Databricks, os dados são organizados em 3 níveis:

```
Catalog (equivalente a "Database" em SQL tradicional)
  └── Schema (equivalente a "Schema" em PostgreSQL/SQL Server)
       ├── Tables (tabelas gerenciadas ou externas)
       ├── Views (visões SQL)
       └── Volumes (armazenamento de arquivos não estruturados)
```
Toda estrutura de Governança, acesso, auditabilidade, linhagem e afins se dá através do Unity Catalog.

Dentro da nossa estrutura de catálogo, podemos ter tabelas, views, funções e volumes.

**Volumes** são diretórios gerenciados pelo Unity Catalog para armazenar arquivos não estruturados:
- CSVs, JSONs, Parquet, imagens, etc.
- Acesso via `dbfs:/Volumes/{catalog}/{schema}/{volume}/`
- Suportam controle de acesso (ACLs)
- Ideal para armazenar dados brutos antes da ingestão

**Para acessar - Comparativo:**
- SQL tradicional: `Database.Schema.Table`
- Databricks: `Catalog.Schema.Table`

_NOTA:_ Nesse treinamento não abordamos questões envolvendo volumes MANAGED x EXTERNAL. Por hora, e de forma simples, usamos volumes MANAGED por serem geridos em termos de otimização, espaço e performance pelo Databricks. Volumes EXTERNAL exigem uma gestão adicional.

---
## Além desses, ainda temos:

✅ **PySpark DataFrames**: Estrutura de dados distribuída do Spark
- Diferente de Pandas DataFrame (distribuído vs em memória)
- Lazy evaluation: código cria plano de execução, não executa imediatamente
- Actions (write, show, count) disparam a execução

✅ **Delta Lake**: Formato de armazenamento ACID
- Vantagens: transações ACID, time travel, MERGE/UPDATE/DELETE
- Melhor que CSV/Parquet para lakehouses
- Suporta schema evolution e otimizações avançadas

✅ **Tabelas Gerenciadas vs Externas**:
- **Gerenciada** (`.saveAsTable()`): Databricks controla dados + metadados
- **Externa** (`.save(path)`): Você controla localização dos dados

✅ **Operações PySpark fundamentais**:
- `spark.read.csv()` - Ler arquivos CSV
- `.option()` - Configurar parâmetros de leitura
- `.withColumn()` - Adicionar/transformar colunas
- `.write.mode().format().saveAsTable()` - Gravar tabelas

✅ **MERGE INTO**: Comando SQL ACID para upsert
- Combina INSERT + UPDATE em uma operação atômica
- Mais eficiente que 3 operações separadas
- Exclusivo do Delta Lake (não existe em CSV/Parquet)

✅ **row_hash**: Técnica de detecção de mudanças
- SHA2 + CONCAT_WS para criar hash único dos dados
- Compara 1 string ao invés de N colunas (performance!)
- Evita UPDATEs desnecessários quando dados não mudaram

✅ **try_cast()**: Conversão segura de tipos
- Retorna NULL se conversão falhar (ao invés de erro)
- Essencial quando tipos na Bronze são inconsistentes
- Exemplo: `try_cast(date_string as DATE)`

✅ **SCD Type 1**: Slowly Changing Dimensions
- Sobrescreve valores antigos (não mantém histórico)
- Alternativas: SCD Type 2 (histórico completo), Type 3 (valor anterior)


✅ **Orquestração Python + SQL**: Combinando o melhor dos dois mundos
- Python: lógica condicional, loops, controle de fluxo
- SQL: manipulação de dados declarativa
- `spark.sql()`: executa SQL a partir de Python

✅ **Estratégias de Carga**:
- **Full Load** (`INSERT OVERWRITE`): primeira execução, mais rápido
- **Incremental** (`MERGE INTO`): execuções subsequentes, mais eficiente para updates

✅ **WHEN NOT MATCHED BY SOURCE**: Conceito avançado do MERGE
- Deleta registros da target que não existem mais na source
- Tudo em uma transação ACID (atomicidade garantida)

✅ **Decisão Condicional**:
```python
is_empty = spark.sql(f"SELECT COUNT(1) FROM {table}").first()[0] == 0
```
- `.first()`: pega primeira linha (Row object)
- `[0]`: acessa primeira coluna (COUNT)
- `== 0`: verifica se está vazio

✅ **F-strings em Python**: Interpolação de variáveis
```python
f"INSERT OVERWRITE {target_table} SELECT * FROM {source_query}"
```
- Substitui `{variavel}` pelo valor da variável
- Mais legível que concatenação de strings

✅ **Wide Tables**: Desnormalização para análise
- JOIN entre múltiplas tabelas dimensionais
- Reduz necessidade de JOINs em queries de consumo
- Trade-off: duplicação de dados vs performance de leitura

---

## ⚠️ Troubleshooting
**Erro: "Path does not exist: dbfs:/Volumes/..."**
- Verifique se os arquivos CSV estão no volume
- Confirme o caminho: `dbfs:/Volumes/c_bikeshop/raw/raw_files/brands.csv`
- Use o Data Explorer para navegar até o volume

**Erro: "Cannot parse date/timestamp"**
- Normal se CSV tem formatos de data inconsistentes
- `inferSchema` tenta adivinhar, mas pode falhar
- Solução: defina schema explícito ou use `try_cast` na Silver

**Performance lenta no inferSchema**
- `inferSchema=True` lê dados 2 vezes (primeira para inferir, segunda para carregar)
- Em produção: sempre defina schema explícito
- Exemplo: `.schema("brand_id INT, brand_name STRING")`

**Tabelas não aparecem no Data Explorer**
- Aguarde alguns segundos e recarregue
- Verifique se você está olhando o catálogo/schema correto

**Erro: "Table or view not found: c_bikeshop.bronze.brands"**
- Certifique-se que o notebook 00_setup foi executado
- Verifique se a célula de ingestão executou sem erros

**Erro: "Table or view not found: _nome_tabela_ "**
- Tabelas podem ter dependências! Execute células em ordem
- `sales_by_day` e `customer_lifetime_value` dependem de `bike_sales`

**Erro: "Cannot resolve column 'product_id'"**
- Verifique se tabelas Silver foram criadas corretamente
- Execute: `SHOW TABLES IN silver` para confirmar

**Performance lenta na primeira execução**
- Normal! INSERT OVERWRITE processa todos os dados
- Execuções subsequentes (MERGE) são mais rápidas

**MERGE sempre faz full scan**
- MERGE precisa comparar source vs target (inevitável)
- Para tabelas muito grandes, considere particionamento
- Exemplo: `PARTITIONED BY (order_date)`

**Erro: "Syntax error near 'BY SOURCE'"**
- `WHEN NOT MATCHED BY SOURCE` requer Delta Lake
- Verifique: `DESCRIBE EXTENDED gold.table` → Provider = delta

**count() retorna erro ao tentar [0]**
- spark.sql() retorna DataFrame, não valor direto
- Sempre use `.first()[0]` para acessar valor escalar

**row_hash sempre diferente (sempre faz UPDATE)**
- Certifique-se que campos no CONCAT_WS estão na mesma ordem
- Cuidado com NULL: `CONCAT_WS('|', NULL, 'value')` pode causar hashes diferentes
- Use COALESCE para tratar NULLs: `COALESCE(field, '')`

**Erro: "try_cast is not a valid function"**
- try_cast é do Spark SQL 3.0+
- Alternativa: `CAST ... AS ... ` com tratamento de erro separado


---

## 🔍 Comandos Úteis para Explorar

```sql
-- Ver todas as camadas do lakehouse
SHOW SCHEMAS IN c_bikeshop;

-- Comparar contagens entre camadas
SELECT 'bronze' as layer, COUNT(*) as tables FROM (SHOW TABLES IN bronze);
-- (repita para silver e gold)

-- Analizar performance de queries
EXPLAIN SELECT * FROM gold.bike_sales WHERE order_date = '2018-01-01';

-- Ver histórico de uma tabela Gold
DESCRIBE HISTORY gold.bike_sales;

-- Ver tamanho das tabelas
DESCRIBE DETAIL gold.bike_sales;

-- Ver histórico de versões (Time Travel)
DESCRIBE HISTORY c_bikeshop.bronze.brands;

-- Consultar versão antiga
SELECT * FROM c_bikeshop.bronze.brands VERSION AS OF 1;
```
---
## Links úteis:
- Exemplos de código Spark: https://sparkbyexamples.com/
- Doc. Databricks: https://docs.databricks.com/aws/en/getting-started/
- Doc. Databricks - PySpark: https://docs.databricks.com/aws/en/pyspark
- Padrão de commits: https://www.conventionalcommits.org/en/v1.0.0/#summary




