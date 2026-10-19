#!/usr/bin/perl -w
#
# based on script by wlloyd at slap.net
# Run once to import Asterisk queue_log to MySQL database.

# requires a DB table like the following..
# CREATE TABLE csr_queue (
#  qname varchar(30) default NULL,
#  agent varchar(30) default NULL,
#  action text,
#  info1 text,
#  info2 text,
#  info3 text,
#  timestamp int(11) NOT NULL default '0',
#  id tinytext NOT NULL
#) TYPE=MyISAM;

use DBI;
use feature qw(say);
use IO::File;
use Time::Piece qw(localtime);
use Getopt::Long 'HelpMessage';
my $LINE_NUM =0;
my $LINES_DROPED=0;
my $DB_TIME_FORMAT='%F %T';

GetOptions(
  'help',          => sub {HelpMessage(0)},
  'verbose'        => \my $opt_verbose,
  'filename=s'     => \(my $filename = '/var/log/asterisk/queue_log'),
  'db-type=s'      => \(my $db_type = "mysql"),
  'db-host=s'      => \(my $db_host = "127.0.0.1"),
  'db-user=s'      => \(my $db_user_name = 'root'),
  'db-password=s'  => \(my $db_password = ''),
  'db-database=s'  => \(my $db_database = 'asteriskcdrdb'),
  'db-table=s'     => \(my $db_table = 'queue_log'),
  'date-start=s'   => \(my $date_start = ''),
  'date-end=s'     => \(my $date_end = ''),
  'dry-run'        => \my $dry_run,
) or HelpMessage(1);

=head1 NAME

  import-queuelog.pl [options] - Imports data from Asterisk queue_log file to database

=head1 SYNOPSIS

  Option           | Description                    | Default
  -----------------+--------------------------------+---------------------------------------
  --filename       | /full/path/to/queue_log_file       | '/var/log/asterisk/queue_log'
  --db-type        |'mysql' or 'Pg'                     | 'mysql'
  --db-database    | Database Name                      | 'asteriskcdrdb'
  --db-table       | Table Name                         | 'queue_log'
  --db-user        | Database User                      | 'root'
  --db-password    | Database Password                  | ''
  --date-start     | UTC Date start YYYY-MM-DD-HH:MM:SS | no date start
  --date-end       | UTC Date end YYYY-MM-DD-HH:MM:SS   | no date end
  --verbose        | Shows SQL before insert            | 0
  --dry-run        | Just shows SQL but don't insert    | 0
  --help           | Print this help                    | 0

  Flags may be abreviated by the first letter using a single hyphen.
  * Check for localtime /DST time. all here is imported as is

  Ex. 

  ./import-queuelog.pl -f my_queue_log 

  Imports all data from file my_queue_log to database using defaults.

=head1 VERSION

  0.9 2020-1-28 Marcelo Araujo, marcelo@gnovit.com

=cut



if ($dry_run){
  $opt_verbose = 1;
}

if ($date_start){
  $date_start = Time::Piece->strptime($date_start, '%Y-%m-%d-%H:%M:%S');
}

if ($date_end){
  $date_end = Time::Piece->strptime($date_end, '%Y-%m-%d-%H:%M:%S');
}

sub import_data {
  
  my $dbh = DBI->connect("DBI:$db_type:dbname=$db_database;host=$db_host;", $db_user_name, $db_password) if !($dry_run);

  open(FH, "< $filename")  or die "Can't open queue_log file: $filename $!\n";

  while (defined(my $message = <FH>)) {
    $LINE_NUM++;
    say('Processing line ' . $LINE_NUM);
    chomp $message;
    next if $message eq '';   # blank line

    # remove chars that will cause DB problems
    $message =~ s/\"\'//g;

    @data = split(/\|/,$message);
        my $datetime = Time::Piece->strptime($data[0], '%s'); 

    if ((($date_start) && ($datetime < $date_start)) || (($date_end) && ($datetime > $date_end))){
      $LINES_DROPED++;
      say('Droping Line '. $LINE_NUM .': '.$message);
      say($datetime . ' < ' . $date_start . ' or ' . $datetime . ' > ' . $date_end) if ($opt_verbose);
      next;
    }

    if (!defined($data[5])) {
      $data[5] = '';
    }
    if (!defined($data[6])) {
      $data[6] = '';
    }
    if (!defined($data[7])) {
      $data[7] = '';
    }
    if (!defined($data[8])) {
        $data[8] = '';
      }
    if (!defined($data[9])) {
        $data[9] = '';
      }
    if (!defined($data[10])) {
        $data[10] = '';
      }

    my $db_datetime = ($datetime->strftime($DB_TIME_FORMAT));
    my $sql = "INSERT INTO $db_table (time, callid, queuename, agent, event, data1, data2, data3, data4, data5, created) VALUES ('$db_datetime', '$data[1]', '$data[2]', '$data[3]', '$data[4]', '$data[5]', '$data[6]', '$data[7]', '$data[8]', '$data[9]', '$db_datetime')";

    say ("$sql") if ($opt_verbose);
    
    if (!$dry_run) {
      $dbh->do($sql);
    }
  }
  $dbh->disconnect() if (!$dry_run);

}

import_data();
say ('Script Done');
say ('Lines Parsed: ' . $LINE_NUM);
say ('Lines Droped: ' . $LINES_DROPED);

exit 0;
