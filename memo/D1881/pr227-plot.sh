#!/usr/bin/env bash

awk '
  BEGIN {
    bin_width = 0.0005;
    ibin_min = 99999;
    ibin_max = 0;
    count = 0;
  }
  $2 == 0.001 {
    v = $1;
    ibin = int(v / bin_width)
    hist[ibin]++;
    if (ibin < ibin_min) ibin_min = ibin;
    if (ibin > ibin_max) ibin_max = ibin;
    count++;
  }
  END {
    for (ibin = ibin_min; ibin <= ibin_max; ibin++) {
      center = (ibin + 0.5) * bin_width;
      print center, hist[ibin], hist[ibin] / (count * bin_width);
    }
  }
' pr227.ci-macos.txt > pr227.sleep0001.hist

awk '
  BEGIN {
    bin_width = 0.005;
    ibin_min = 99999;
    ibin_max = 0;
    count = 0;
  }
  $2 >= 0.020 {
    v = $1 - $2;
    ibin = int(v / bin_width)
    hist[ibin]++;
    if (ibin < ibin_min) ibin_min = ibin;
    if (ibin > ibin_max) ibin_max = ibin;
    count++;
  }
  END {
    for (ibin = ibin_min; ibin <= ibin_max; ibin++) {
      center = (ibin + 0.5) * bin_width;
      print center, hist[ibin], hist[ibin] / (count * bin_width);
    }
  }
' pr227.ci-macos.txt > pr227.sleep0020p.hist

gnuplot pr227-plot.gp

