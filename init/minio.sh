#!/bin/bash

mc mb local/test
dd if=/dev/random of=/tmp/data1.out bs=1024 count=1000
dd if=/dev/random of=/tmp/data2.out bs=1024 count=2000
mc cp /tmp/data1.out /tmp/data2.out local/test

exit 0
