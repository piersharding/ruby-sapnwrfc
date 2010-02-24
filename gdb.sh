#!/bin/sh
rm -f gdb.cmds
echo "running gdb for ($1) ..."
echo "run  $1" > gdb.cmds
echo "bt" >> gdb.cmds
echo "quit" >> gdb.cmds
gdb -x gdb.cmds ruby
rm -f gdb.cmds
