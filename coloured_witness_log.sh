#!/bin/bash

# This will tail the miner log and output a line every time
# 1) A witness is heard
# 2) A witness is successfully submitted to the challenger, and
# 3) The maximum number of retries is met

# For example: 
# 2022-01-26 17:03:07.736 Heard witness
# 2022-01-26 17:03:38.994 Successfully sent 
# 2022-01-26 17:03:43.682 Max retry

#process everything in the log as of now:
sudo docker exec miner cat     /var/data/log/console.log | grep --text witness |  awk '{if ($6=="successfully") print "\x1b[32m"$1" "$2" Successfully sent \x1b[0m"; else if ($13=="treating") print $1" "$2" Heard witness"; else if ($10=="max") print "\x1b[31m"$1" "$2" Max retry\x1b[0m"; }'
#tail the log
sudo docker exec miner tail -f /var/data/log/console.log | grep --text witness |  awk '{if ($6=="successfully") print "\x1b[32m"$1" "$2" Successfully sent \x1b[0m"; else if ($13=="treating") print $1" "$2" Heard witness"; else if ($10=="max") print "\x1b[31m"$1" "$2" Max retry\x1b[0m"; }'
