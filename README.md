# ckpt_collect_log_file_sizes
Used to collect log file sizes from a Check Point log server

## Instructions

### Script setup
1. ssh into a Check Point log server
1. enter expert mode
1. copy file [collect_log_file_sizes.sh](https://raw.githubusercontent.com/joeaudet/ckpt_collect_log_file_sizes/master/collect_log_file_sizes.sh) to /home/admin/ on log server
   ```
   curl_cli -k https://raw.githubusercontent.com/joeaudet/ckpt_collect_log_file_sizes/master/collect_log_file_sizes.sh > /home/admin/collect_log_file_sizes.sh
   ```
1. chmod the script to be executable
   ```
   chmod u+x /home/admin/collect_log_file_sizes.sh
   ```
