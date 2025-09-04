/*****************************************************************************************
demo_compile_configs

usage:    dbt compile --project-dir . --profiles-dir . --target dev \
            --select demo_compile_configs

******************************************************************************************

properties debugging info:

target
{{ target }}

target.schema
{{ target.schema }}

target.name
{{ target.name }}

model
{{model}}

this
{{ this }}

this.type
{{ this.type }}

config  {{ config }}

model.config
{{ model.config}}

model.config.tags
{{ model.config.tags }}

model.tags
{{ model.tags }}

'graph' is massive
graph.nodes['model.devbt.demo_compile_configs']
{{ graph.nodes['model.devbt.demo_compile_configs'] }}

########### Nothings ###########
config.tags  {{ config.tag }}
node {{ node }}
tags {{ tags }}
tag {{ tag }}
relation {{ relation }}
model.type {{ model.type }}
model.is_table {{model.is_table}}

*****************************************************************************************/
select
    'hello there' col1
    , 'general kenobi' col2
