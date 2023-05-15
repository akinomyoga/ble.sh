# -*- mode: sh; mode: sh-bash -*-

ble/util/autoload "$_ble_base/lib/core-debug.sh" \
                  ble/debug/setdbg \
                  ble/debug/print \
                  ble/debug/print-variables \
                  ble/debug/stopwatch/start \
                  ble/debug/stopwatch/stop \
                  ble/debug/profiler/start \
                  ble/debug/profiler/stop
