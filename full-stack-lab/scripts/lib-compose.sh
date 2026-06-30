#!/usr/bin/env bash
# Shared definitions for the lab lifecycle scripts. Sourced, not run.
# Defines PROJECT and the full -f file list for the overkill `zo` stack.
PROJECT="${COMPOSE_PROJECT_NAME:-zo}"

# Core stack + advanced demos. Optional add-ons (haproxy, observability) are included so
# stop/start/down also catch them if they happen to be running; harmless if they are not.
ZO_FILES=(
  -f compose/controllers.yml
  -f compose/routers.yml
  -f compose/echo-demo.yml
  -f compose/ssh-demo.yml
  -f compose/extras.yml
  -f compose/haproxy.yml
  -f compose/observability.yml
)

# The minimal teaching stack (separate project).
LESSON_PROJECT="zomin"
LESSON_FILES=(
  -f compose/lesson-min.yml
  -f compose/lesson-echo.yml
)
