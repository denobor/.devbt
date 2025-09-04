# These task runner commands to run local dbt operations, using uv-managed environment.
# .env file holds important parameters
# usage:  just <command>    # enter 'just' to see list of commands from CLI

# TODO: init operation to prompt .env, do 'uv sync', 'dbt deps'
# TODO: sqlfmt check project name targets, or set default excludes
# TODO: 'branch' vs. dev target clean up
# TODO: dbt_vars vs define process_date in here in a macro just like outer
# TODO: add see manifest in vscode with prettify json
# TODO: always expect dev|prod_shadow args? branch makes no sense, will always be dev
# TODO: 'process_date' is better as a dbt_project variable using strftime date, vs. hard coding in .env

set positional-arguments := true
set dotenv-load := true
set dotenv-override := true
git_branch := `git symbolic-ref --short HEAD || echo "NONE"`

# typical job variables
process_date := `date +%Y-%m-%d --date="2 days ago"`


dbt_vars := `echo ${DEVBT_VARS}`

# dev branch/schema/env if not main|stable
# TODO: fix this, dev is always going to be default for local env, with option for prod_shadow
branch := if (git_branch) == "main" { "main" } else if (git_branch) == "stable" { "stable" } else { "dev" }
current_git_commit := `git rev-parse HEAD | cut -c 1-7`
file_ts := `date '+%Y-%m-%d_%H%M%S'`

# just --list
_default:
  @just --list --unsorted
  @echo "{{BRD}}REMINDERS:"
  @echo "{{RD}}    DO NOT CHANGE COLUMN ORDER{{MG}} of dbt incremental tables"
  @echo


##### DBT COMMANDS #####

# pass thru command into uv shell
pass *args:
  uv run "$@"

# dump justfile exported variables and prefect config variables to screen
env:
  @echo "✙✙✙✙✙✙✙✙              {{BL}}environment variables:{{GR}}          ✙✙✙✙✙✙✙✙"
  @env | grep "DBT_\|DEVBT_\|DATAB" | sort
  @echo "{{NC}}current just git branch:         {{BCY}}{{branch}}{{NC}}"
  @echo "current commit:                  {{BCY}}{{current_git_commit}}{{NC}}"

# dbt list    --target branch [--select <modelname>]
list *args:
  @echo "{{BGR}}Target: {{BCY}}{{branch}}{{NC}}"
  uv run dbt list --project-dir . --profiles-dir . --target {{branch}} --resource-type model "$@"

# TODO: fix this
# dbt compile --target dev|prod_shadow [--select <modelname>]
compile *args:
  @echo "{{BGR}}Target: {{BCY}}{{branch}}{{NC}}"
  uv run dbt compile --project-dir . --profiles-dir . --vars '{{ dbt_vars }}' --quiet "$@"

# dbt show    --target branch [--select <modelname>]
show *args:
  @echo "{{BGR}}Target: {{BCY}}{{branch}}{{NC}}"
  uv run dbt show --project-dir . --profiles-dir . --target {{branch}} "$@"

# dbt seed    --target branch [--select <modelname>]
seed *args: timestamp
  @echo "{{BGR}}Target: {{BCY}}{{branch}}{{NC}}"
  uv run dbt seed --project-dir . --profiles-dir . --target {{branch}} "$@"

# dbt run     --target dev|prod_shadow [--select <modelname>]
run *args: timestamp
  @echo "{{BGR}}Target: {{BCY}}{{branch}}{{NC}}"
  uv run dbt run --project-dir . --profiles-dir . "$@"

# dbt deps    --target branch [--select <modelname>]
deps *args: timestamp
  @echo "{{BCY}}{{branch}}{{NC}}"
  uv run dbt deps --project-dir . --profiles-dir . "$@"

# dbt build   --target branch [--select <modelname>]
build *args: timestamp
  @echo "{{BGR}}Target: {{BCY}}{{branch}}{{NC}}"
  uv run dbt build --project-dir . --profiles-dir . --target {{branch}} "$@"

# dbt test    --target dev|prod_shadow [--select <modelname>]
test *args: timestamp
  @echo "{{BGR}}Target: {{BCY}}{{branch}}{{NC}}"
  uv run dbt test --project-dir . --profiles-dir . --vars '{{ dbt_vars }}' "$@"

# dbt docs    --target branch
docs *args: timestamp
  @echo "{{BGR}}Target: {{BCY}}{{branch}}{{NC}}"
  @uv run dbt docs generate --static --project-dir . --profiles-dir . --target {{branch}} "$@"
  open "target/static_index.html"

# dbt source freshness --target branch [--select <modelname>]
fresh *args: timestamp
  @echo "{{BGR}}Target: {{BCY}}{{branch}}{{NC}}"
  uv run dbt source freshness --project-dir . --profiles-dir . --target {{branch}} "$@"

# dbt run-operation --target branch [macro_name] [--args '{arg1: "arg1_value"}']
runop *args: timestamp
  @echo "{{BGR}}Target: {{BCY}}{{branch}}{{NC}}"
  uv run dbt run-operation --project-dir . --profiles-dir . --target {{branch}} "$@"

# sqlfmt check, choose the folders
check *args="..":
  uv run sqlfmt {{args}} --check --diff \
    --exclude '.venv/**' \
    --exclude 'target/**' \
    --exclude 'dbt_packages/**' \
    --exclude '.devbt/.venv/**' \
    --exclude '.devbt/target/**' \
    --exclude '.devbt/dbt_packages/**' \
    --exclude '**/target/**' \
    --exclude '**/dbt_packages/**'

# sqlfmt format the files
fmt *args="..":
  uv run sqlfmt {{args}} \
    --exclude '.venv/**' \
    --exclude 'target/**' \
    --exclude 'dbt_packages/**' \
    --exclude '.devbt/.venv/**' \
    --exclude '.devbt/target/**' \
    --exclude '.devbt/dbt_packages/**' \
    --exclude '**/target/**' \
    --exclude '**/dbt_packages/**'


# elementary data report
edr:
  uv run edr report --profile-target {{branch}}_elem --project-dir . --profiles-dir . \
    --file-path ikeloa_dbx/edr-reports/elem-report.{{branch}}.{{current_git_commit}}.{{file_ts}}.html --env {{branch}}

# build, fresh, edr report
afo:
  just build && just fresh && just edr

# send edr report to ikeloa-feed channel
feed:
  uv run edr send-report --project-dir . --profiles-dir . \
    --profile-target {{branch}}_elem --env {{branch}} --slack-file-name elem-report.{{branch}}.{{current_git_commit}}.{{file_ts}}.html \
    --slack-token "${SLACK_TOKEN_TEMPLISHER}" --slack-channel-name 'ikeloa-feed'

# view the latest compiled sql files
see:
  @tree "target/compiled"

# post the date of the jobrun, stdout only has time
[private]
timestamp:
  @echo "{{BGR}}Jobrun Time: {{CY}}$(date '+%Y-%m-%d %T')"

##### WORKFLOW #####

# list of TODO in project, exclude root TODO.md
todo:
  @rg -uu --line-number --heading --no-stats "TODO:" --glob='!TODO.md' --glob='!justfile' --glob='!.venv' --glob='!dbt_packages'

# ptpython REPL in poetry shell
repl:
  @uv run ptpython

# DBT workflow reminders
info:
  @echo
  @echo "       {{BYW}}Just Taskrunner info:{{NC}}"
  @echo "         * {{CY}}DATABRICKS_TOKEN{{YW}} is expected in local env by default"
  @echo
  @echo
  @echo "       {{BYW}}Development workflow - develop, test, push{{NC}}"
  @echo
  @echo "         * {{CY}}Branches{{YW}} [dev, stable, main] -> [ikeloa_dev, ikeloa_stable, ikeloa]{{NC}}"
  @echo "               {{BL}}stable {{BK}}full replica of main, merge from {{BL}}dev{{NC}}"
  @echo "               {{BL}}dev    {{BK}}branch and feature branches -> ikeloa_dev{{NC}}"
  @echo "               {{BL}}  \ -- {{BK}}    get smaller build on big tables{{NC}}"
  @echo "         * {{CY}}justfile{{YW}} call poetry, sets target <- branch and proj directory{{NC}}"
  @echo "         * {{CY}}tag selectors{{GR}} just list --select tag:test{{NC}}"
  @echo
  @echo "       {{BGR}}DEV WORKFLOW:"
  @echo "           {{GR}}git checkout stable"
  @echo "           git checkout -b pbb-2112/new-feature"
  @echo "               {{BK}}write sql, write tests{{GR}}"
  @echo "           just build --select model_you_are_working_on"
  @echo "               {{BK}}more explicit: just compile ..; just show ..; just run;  just test..{{GR}}"
  @echo "           just run --target audit"
  @echo "               {{BK}}fix errors, etc.{{GR}}"
  @echo "           just docs"
  @echo "               {{BK}}review the project structure{{GR}}"
  @echo "           just edr"
  @echo "               {{BK}}observability report, state of data and tests{{GR}}"
  @echo "               {{BK}}NOTE: warnings are errors{{GR}}"
  @echo "           git checkout dev"
  @echo "           git merge --no-ff pbb-2112/new-feature"
  @echo
  @echo "           just deps && just seed && just build && just fresh {{BK}}all in one{{GR}}"
  @echo
  @echo "           just build"
  @echo "               {{BK}}all PASSING, ready to merge{{GR}}"
  @echo "           git checkout stable"
  @echo "               {{BK}}all the same dbt actions{{GR}}"
  @echo "           git merge --no-ff dev"
  @echo "           just edr"
  @echo "           git push"
  @echo "           {{BK}}Now move on to main, merge local and test, tag as appropriate"
  @echo
  @echo "           {{BBK}}NOTES:"
  @echo "           {{BK}}    target branch default set to current branch"
  @echo "           {{BK}}    on dev a full dbt build is about 10 minutes"
  @echo
  @echo "           {{BBK}}EXAMPLES:"
  @echo "           {{BK}}    disabled model override with vars:"
  @echo "           {{GR}}    just run {{MG}}--vars {{YW}}'audit_enabled: true {{MG}}--select {{BMG}}audit_calendar"
  @echo


### Git Flow ###

# open files to bump version number before tag
bump:
  @echo "{{BMG}}Bump version numbers{{NC}}"
  @echo "    {{BGR}}git add .; git commit -m {{YW}}'v1.0.0: these things I have did'"
  @echo "    {{BGR}}git tag -a v1.0.0 -m {{YW}}'v1.0.0 Templisher time'"
  @echo "    {{BGR}}git push"
  @echo "    {{BGR}}git push origin tag v1.0.0"
  @echo
  @read -p "PRESS y TO CONTINUE ELSE ABORT [yN]: " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]
  @vim pyproject.toml
  @vim ikeloa_dbx/dbt_project.yml


#################### INIT #########################

# initialize uv/dbt environment
init:
  uv sync
  uv run dbt deps --project-dir . --profiles-dir .
  just compile-prod

# compile shadow prod for manifest files
compile-prod:
  uv run dbt compile \
  --project-dir . --profiles-dir . --target prod_shadow \
  --vars '{{ dbt_vars }}' \
  --select package:"$DEVBT_OUTER_PROJECT_NAME"

# prettify the manifest json and open with vscode
fest *args="target/manifest.json":
  python3 -m json.tool {{ args }} > tmp.json && \
  mv tmp.json {{ args }} && \
  code {{ args }}

# sanity check of configured paths given target
sanity arg='dev':
  uv run dbt ls --target {{arg}} --resource-type model --output-keys database,schema --quiet

#################### COLORS #########################

# show the color codes
[private]
colortest:
  @echo "            {{NC}}NC{{NC}}"
  @echo "   {{BK}}BK{{NC}}               {{BL}}BL{{NC}}"
  @echo "   {{BBK}}BBK{{NC}}              {{BBL}}BBL{{NC}}"
  @echo "   {{RD}}RD{{NC}}               {{MG}}MG{{NC}}"
  @echo "   {{BRD}}BRD{{NC}}              {{BMG}}BMG{{NC}}"
  @echo "   {{GR}}GR{{NC}}               {{CY}}CY{{NC}}"
  @echo "   {{BGR}}BGR{{NC}}              {{BCY}}BCY{{NC}}"
  @echo "   {{YW}}YW{{NC}}               {{WT}}WT{{NC}}"
  @echo "   {{BYW}}BYW{{NC}}              {{BWT}}BWT{{NC}}"

# color decoration definitions
BK  := '\033[0;30m'   # Black
BBK := '\033[1;30m'   # Bright Gray
RD  := '\033[0;31m'   # Red
BRD := '\033[1;31m'   # Bright Red
GR  := '\033[0;32m'   # Green
BGR := '\033[1;32m'   # Bright Green
YW  := '\033[0;33m'   # Yellow
BYW := '\033[1;33m'   # Bright Yellow
BL  := '\033[0;34m'   # Blue
BBL := '\033[1;34m'   # Light Blue
MG  := '\033[0;35m'   # Magenta
BMG := '\033[1;35m'   # Light Purple
CY  := '\033[0;36m'   # Cyan
BCY := '\033[1;36m'   # Light Cyan
WT  := '\033[0;37m'   # White
BWT := '\033[1;37m'   # Light White
NC := '\033[0m'       # no color
