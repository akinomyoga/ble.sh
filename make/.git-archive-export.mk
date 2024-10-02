# This template is supposed to be instantiated by "git archive".

BLE_GIT_COMMIT_ID := $Format:%h$
BLE_GIT_BRANCH := $(shell echo "$Format:%D$" | sed -n 's/.*HEAD -> \([^,[:space:]]*\).*/\1/p')
