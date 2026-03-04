# Database client command line tool guidance
## General
### Use utf8 encoding for input and output
#### Example
##### Mysql
--default-character-set=utf8mb4
## Client-specific
### Mysql
#### Parse connection string to config .cnf file, use that in queries, and delete the file when the task is over
Use option --defaults-extra-file=/path/to/config.cnf to connect to database
##### Example
###### Config file
[client]
user = "value"
password = "value"
host = "value"
