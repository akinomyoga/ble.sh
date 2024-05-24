# -*- mode: sh; mode: sh-bash -*-

ble/util/autoload "$_ble_base/lib/core-debug.sh" \
                  ble/debug/setdbg \
                  ble/debug/print \
                  ble/debug/print-variables \
                  ble/debug/stopwatch/start \
                  ble/debug/stopwatch/stop \
                  ble/debug/profiler/start \
                  ble/debug/profiler/stop

bleopt/declare -v debug_profiler_opts line:func

# In the profiler output for the function-call tree (a.tree.txt), only the
# levels that took more than this time are recorded.
bleopt/declare -n debug_profiler_tree_threshold 5.0
