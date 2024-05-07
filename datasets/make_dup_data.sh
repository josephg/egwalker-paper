#!/bin/bash
set -e

dt bench-duplicate raw/automerge-paper.dt -o S1.dt -n3 -f
dt bench-duplicate raw/seph-blog1.dt -o S2.dt -n3 -f
dt bench-duplicate raw/egwalker.dt -o S3.dt -n1 -f

dt bench-duplicate raw/friendsforever.dt -o C1.dt -n25 -f
dt bench-duplicate raw/clownschool.dt -o C2.dt -n25 -f

dt bench-duplicate raw/node_nodecc.dt -o A1.dt -n1 -f
dt bench-duplicate raw/git-makefile.dt -o A2.dt -n2 -f

# dt bench-duplicate ../benchmark_data/automerge-paper.dt -o automerge-paperx3.dt -n3 -f
# dt bench-duplicate ../benchmark_data/seph-blog1.dt -o seph-blog1x3.dt -n3 -f
# dt bench-duplicate ../benchmark_data/egwalker.dt -o egwalkerx1.dt -n1 -f

# dt bench-duplicate ../benchmark_data/clownschool.dt -o clownschoolx25.dt -n25 -f
# dt bench-duplicate ../benchmark_data/friendsforever.dt -o friendsforeverx25.dt -n25 -f

# dt bench-duplicate ../benchmark_data/git-makefile.dt -o git-makefilex2.dt -n2 -f
# dt bench-duplicate ../benchmark_data/node_nodecc.dt -o node_nodeccx1.dt -n1 -f

