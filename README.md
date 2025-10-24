# DEVBT
This 'devbt' is a dbt dev overlay project, a small active project that layers on top of your team repo to provide local macros, env bridging, and safe catalog/schema overrides without touching the team’s dbt_project.yml or profiles.yml.

* git clone this repo into your dbt project repo
* the ./devbt subdirectory will be ignored by the outer repo
* install 'just' task runner to take advantage of the prepared development recipes
* this repo is .gitignored, is not added to the outer project repo

**Outer Project** - the dbt project you are making development changes on.
**Overlay Project** - this dbt project in subfolder `./devbt` which overlays the development project.

TODO: lots of rough breadcrumbs, ex tests section. streamline and finalize when you figure it all out.
TODO: setup steps for devbt init script in justfile
TODO: you can make replacements of .env variables in these docs

```bash

# to reach the outer project, the path will be custom path based on main repo
uv run dbt run --project-dir ../my_outer_project_name/src --profiles-dir ../my_outer_project_name/src/ --target dev --model my_outer_project_table
```


## SETUP
### 1. Clone the devbt repo
Clone the devbt overlay repo into the root directory of your dbt databricks project.

```bash
git clone ...etc
```

### 2. Configure .env File
Edit the .env file with the following specifics to the repo you are changing.
This configures your dev/prod environment so you can develop on your project repo without altering the existing dbt configurations.


```bash
# update these to each new project
DEVBT_OUTER_PROJECT_NAME="my_outer_project_name"
DEVBT_PATH_TO_OUTER_PROJECT="../my_outer_project_name/src"
DEVBT_DEV_CATALOG="my_dev_catalog"
DEVBT_DEV_SCHEMA="my_dev_schema"
DEVBT_PROD_CATALOG="my_outer_project_prod_catalog"
DEVBT_PROD_SCHEMA="my_outer_project_prod_schema"

# Most models take a process_date sort of parameter for dbx workflows
DEVBT_VARS='{"process_date": 2025-08-19}'
```

### 3. Install Dependencies
* `uv` python package manager for environment management
* `just.systems`: Optional, but convenient. Without installing, the `justfile` documents the `uv` commands.

[Just Task Runner Install](https://just.systems/man/en/packages.html)
[UV python package manager install](https://docs.astral.sh/uv/#installation)

```bash
brew install just uv
uv sync

just init # this should do 'uv sync; dbt deps' and other first time steps

# there is a test table included in package called 'devbt_test_table'
just run --model devbt_test_table

# equivalent command, except env vars are not available
uv run dbt run --project-dir . --profiles-dir . --target dev --model my_outer_project_table
```
The init is now handled with `just init` which also compiles the outer project with the prod tables, making `-defer` builds available on small changes (ie dont build whole project).


#### Typical Databricks Job Parameters
```yml
process_date: {{job.trigger.time.iso_date}}
env: "prod"
```

## BUILD A MODEL IN DEV
Typical usage
Probably only want to only run specific models in dev, and use the existing prod models for dependency. To accomplish this you need to compile the `prod_shadow` and then defer to those prod models.

```bash
# typical build a model, if no dependencies needed
dbt build --project-dir .develop --profiles-dir .develop --select package:$OUTER_PKG my_model

uv run dbt compile --project-dir . --profiles-dir . --vars '{"process_date": 2025-08-19}' --target prod_shadow

just run --target dev --defer --state target --favor-state --vars "process_date: 2025-09-01" --select package:"$DEVBT_OUTER_PROJECT_NAME" my_outer_project_table
```

## RUNNING TESTS
TODO: I'm using justfile to pass catalog env vars in

```bash
just pass uv run dbt test --project-dir . --profiles-dir . --target dev --select test_schema_changes_fcmw --vars "process_date: 2025-08-26"

# or if you add {{ ref('my_outer_project_table') }} to the sql model
just test --target my_outer_project_table
```

## DOCS
```bash
# NOTE: process_date is defined in CICD and used all over
cd .devbt
uv run dbt docs generate --static \
--vars "process_date: 2025-08-19" \
--project-dir ../my_outer_project_name/src \
--profiles-dir . \
--target dev
```



----------
## DEVELOPING DEVBT REPO
**NOTE:** the `.gitignore` ignores everything in this repo, to add files you have to `git add --force new_file` to get it into the repo.

Creating the .devbt project repo
```bash
cd .devbt
uv init . --name devbt --no-workspace
uv add dbt-databricks dbt-core

cp ../project_dir/profiles.yml ./profiles.yml
uv run dbt debug --profiles-dir . --project-dir ../my_outer_project_name/src --target dev
```


### Configs are a Doozy
Quick sanity checks on how the models come out:

```bash
uv run dbt ls --target dev --resource-type model --output csv --output-keys database,schema --quiet

dbt compile --target prod_shadow
    # peek at target/manifest.json for database/schema.
```

**Override `generate_schema_name` macro is necessary for sanity!**


### Building a Model with Defer
```bash
just compile --target prod_shadow
just sanity prod_shadow

# TODO: move the file to new location for state parameter
just run --target dev \
--defer \
--state target \
--favor-state \
--vars "process_date: 2025-08-26" \
--select package:"$DEVBT_OUTER_PROJECT_NAME" my_outer_project_table

# SUCCESS

# test has reference to source so test will trigger.
just test --target dev --select test_my_outer_project_table --vars 'process_date: 2025-08-27'
just test --target dev --select my_outer_project_table --vars 'process_date: 2025-08-27'

# and if thats all good compile the test to be sure and run it
just compile --target prod_shadow --select test_my_outer_project_table
# /*****************************************************************************************
#   return missing partitions (client_date_pst_dt, platform_nm) in my_outer_project_table
#             {{ this }}
#   debug:    `my_dev_catalog`.`my_dev_schema`.`test_my_outer_project_table`
# *****************************************************************************************/

just test --target prod_shadow --select test_my_outer_project_table --vars 'process_date: 2025-08-27'
# 20:30:04  Done. PASS=1 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=1

    #    B O O M ! !
```
