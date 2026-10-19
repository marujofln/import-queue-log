# import-queue-log

Perl script that imports an Asterisk `queue_log` file into a MySQL or PostgreSQL table. Useful for backfilling queue reports when the realtime `queue_log` backend was not enabled, or for reprocessing a time window.

## Requirements

- Perl 5 with `DBI`, plus `DBD::mysql` or `DBD::Pg`
- `Time::Piece`, `Getopt::Long` (core modules)

Debian/Ubuntu:

```bash
sudo apt install libdbi-perl libdbd-mysql-perl   # or libdbd-pg-perl
```

## Target table

Each `queue_log` line (`epoch|callid|queuename|agent|event|data1|...|data5`) is inserted as:

```sql
INSERT INTO queue_log
  (time, callid, queuename, agent, event, data1, data2, data3, data4, data5, created)
```

`time` and `created` hold the event timestamp formatted as `YYYY-MM-DD HH:MM:SS`. The default table (`queue_log` in `asteriskcdrdb`) matches the FreePBX/Asterisk realtime queue_log schema.

## Usage

```bash
./import-queuelog.pl [options]
```

| Option | Description | Default |
|---|---|---|
| `--filename` | Path to the queue_log file | `/var/log/asterisk/queue_log` |
| `--db-type` | `mysql` or `Pg` | `mysql` |
| `--db-host` | Database host | `127.0.0.1` |
| `--db-database` | Database name | `asteriskcdrdb` |
| `--db-table` | Table name | `queue_log` |
| `--db-user` | Database user | `root` |
| `--db-password` | Database password | empty |
| `--date-start` | Only import events from this date (`YYYY-MM-DD-HH:MM:SS`) | none |
| `--date-end` | Only import events up to this date (`YYYY-MM-DD-HH:MM:SS`) | none |
| `--verbose` | Print each SQL statement | off |
| `--dry-run` | Print SQL without connecting or inserting | off |
| `--help` | Show help | |

Options can be abbreviated to their first letter (e.g. `-f`).

### Examples

Preview what would be imported:

```bash
./import-queuelog.pl -f /var/log/asterisk/queue_log --dry-run
```

Import a single day into PostgreSQL:

```bash
./import-queuelog.pl \
  --db-type Pg --db-host db.local --db-user asterisk --db-password "$DB_PASS" \
  --date-start 2020-10-01-00:00:00 --date-end 2020-10-01-23:59:59
```

## Notes

- Timestamps are imported as they appear in the file; no timezone or DST conversion is applied.
- Running the script twice over the same range inserts duplicates. Filter by date or clean the table first.
- Prefer passing the password through an environment variable, as above, rather than typing it literally (it would end up in the shell history).

## Credits

Based on a script by wlloyd at slap.net. Maintained by Marcelo Araujo ([Gnovit](https://gnovit.com)).
