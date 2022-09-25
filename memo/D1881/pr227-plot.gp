#!/usr/bin/gnuplot

set terminal pdfcairo size 4.5,4.5/sqrt(2)
set output 'pr227-sleep-delay.pdf'

set xlabel 'Requested delay (argument of sleep) [sec]'
set ylabel 'Actual delay of sleep [sec]'

avg_empty = 0.005270
avg_0_001 = 0.0112548
fcost = avg_0_001 - 0.001 - avg_empty

set title 'Scatter plot of actual delay vs requested (Bash 3.2 / CI macOS)'
set key left top Left
plot [0:0.100]\
  'pr227.ci-macos.txt' u 2:($1-avg_empty) lc rgb '#FF0000' title 'Sample points', \
  x lc rgb '#000000' title 'y = x', \
  x+fcost lc rgb '#888888' dt (8,4) title 'y = x + (fork overhead)'

plot \
  'pr227.ci-macos.txt' u 2:($1-avg_empty) lc rgb '#FF0000' ps 0.5 lw 0.5 title 'Sample points', \
  x lc rgb '#000000' title 'y = x', \
  x+fcost lc rgb '#888888' dt (8,4) title 'y = x + (fork overhead)'

set title 'Distribution of delay (requested = 0.001) (Bash 3.2 / CI macOS)'
set xlabel 'Actual delay [sec]'
set ylabel 'Histogram count'
set style fill solid
set boxwidth 0.8 relative
set yrange [0:60]
plot \
  'pr227.sleep0001.hist' u 1:2 w boxes fc rgb '#AAAAFF' notitle, \
  'pr227.sleep0001.hist' u 1:2:(sqrt($2)) w yerror lc rgb '#000088' notitle

set title 'Distribution of extra delay (requested >= 0.020) (Bash 3.2 / CI macOS)'
set xlabel 'Extra delay [sec]'
set ylabel 'Histogram count'
set style fill solid
set boxwidth 0.8 relative
set yrange [0:*]
plot \
  'pr227.sleep0020p.hist' u 1:2 w boxes fc rgb '#AAAAFF' notitle, \
  'pr227.sleep0020p.hist' u 1:2:(sqrt($2)) w yerror lc rgb '#000088' notitle

#------------------------------------------------------------------------------

set xlabel 'Requested delay (argument of sleep) [sec]'
set ylabel 'Actual delay of sleep [sec]'

set title 'Scatter plot in Bash 3.2 (GNU/Linux)'
set key left top Left
plot [0:0.200]\
  'pr227.linux32.txt' u 2:1 lc rgb '#FF0000' title 'Sample points', \
  x lc rgb '#000000' title 'y = x'

set title 'Scatter plot in Bash 5.2 (GNU/Linux)'
set key left top Left
plot [0:0.200]\
  'pr227.linux52.txt' u 2:1 lc rgb '#FF0000' title 'Sample points', \
  x lc rgb '#000000' title 'y = x'

set title 'Scatter plot in Bash 5.1 (FreeBSD 13)'
set key left top Left
plot [0:0.200]\
  'pr227.freebsd.txt' u 2:1 lc rgb '#FF0000' title 'Sample points', \
  x lc rgb '#000000' title 'y = x'

set title 'Scatter plot in Bash 4.4 (Cygwin)'
set key left top Left
plot [0:0.200]\
  'pr227.cygwin.txt' u 2:1 lc rgb '#FF0000' title 'Sample points', \
  x lc rgb '#000000' title 'y = x'

set title 'Scatter plot in Bash 3.2 (macOS)'
set key left top Left
plot [0:0.200]\
  'pr227.macos32.txt' u 2:1 lc rgb '#FF0000' title 'Sample points', \
  x lc rgb '#000000' title 'y = x'

set title 'Scatter plot in Bash 5.1 (macOS)'
set key left top Left
plot [0:0.200]\
  'pr227.macos51.txt' u 2:1 lc rgb '#FF0000' title 'Sample points', \
  x lc rgb '#000000' title 'y = x'
