#!/usr/bin/perl
#
# Stitch together mp4 files.
#
# Authorr: Rasan Rasch <rasa@nyu.edu>

use strict;
use warnings;
use AppConfig qw(:expand);
use Cwd qw(abs_path);
use Data::Dumper;
use File::Basename;
use File::Compare;
use File::Copy;
use File::Path;
use File::Temp qw(tempdir);
use IO::CaptureOutput qw(capture_exec_combined);
use Log::Log4perl qw(:easy);
use Sys::Hostname;
use Time::Duration;
use XML::Simple;


# Default options. Can be overridden in mp4-stitch.conf conf file and
# from command line.
my %opt = (
	# file used to create pause between to mp4 files.
	# BITRATE is a placeholder for the bitrate (300 or 800)
	pause_file => "$ENV{HOME}/pause/pause_<BITRATE>k_s.mp4",

	# directory containing mp4 files from media preserve
	content_dir => "/content/prod/rstar/content/dlts/hidvl/wip",

	# directory where final stitched content will go
	stitch_dir => "/content/dev/$ENV{USER}",

	# tmp directory used to process intermediate files
	# make sure there is enough disk space for mp4box operations.
	tmp_dir => "/content/dev/$ENV{USER}/tmp",

	# logging config file
	logconf => "conf/log4perl.conf",

	# Path to mp4box tool that does stitching
	mp4box => "/usr/bin/MP4Box",

	# Path to mediainfo technical metadata display tool
	mediainfo => "/usr/bin/mediainfo",
);

my $cfg_file = "conf/mp4-stitch.conf";

############################################################

$SIG{__WARN__} = sub { die @_ };

my $cfg = AppConfig->new({GLOBAL => {EXPAND => EXPAND_ALL}});

for my $opt_name (keys %opt)
{
	$cfg->define("$opt_name=s");
}

# find application directory
my $bin_dir  = dirname(abs_path($0));
my $app_home = dirname($bin_dir);

# read options from file
$cfg_file = "$app_home/$cfg_file";
$cfg->file($cfg_file);

# read options from cmdline
$cfg->args();

# override default options
for my $opt_name (keys %opt)
{
	$opt{$opt_name} = $cfg->get($opt_name) if $cfg->get($opt_name);
}

my $host = hostname();

if (!@ARGV) {
	usage(%opt);
	exit(1);
}

# input SMIL file to be parsed
my $smil_file = shift;

my $stitch_name;
if ($smil_file =~ /(?:^|\/)?(\d+)_stream_high.smil$/) {
	$stitch_name = $1;
} else {
	die("Invalid name for SMIL file: $smil_file");
}

Log::Log4perl->easy_init(
	{
		level  => $TRACE,
		file   => "STDERR",
		layout => "[%d bcn=$stitch_name %p] %m%n"
	}
);

my $log = get_logger();

$opt{tmp_dir} = tempdir(
	DIR     => $opt{tmp_dir},
	CLEANUP => 1,
);

# Also set tmp dir as cmdline option to insure
# there is enough disk space for concat operations.
$opt{mp4box} .= " -tmp $opt{tmp_dir}";

if ($log->is_debug())
{
	$opt{mp4box} .= " -v";
	$opt{mediainfo} .= " -f";
}

for my $opt_name (keys %opt)
{
	$log->trace("config param $opt_name: $opt{$opt_name}");
}

# parse smil file
$log->debug("Opening $smil_file.");
my $smil = XMLin($smil_file, ForceArray => ["video"]);
$log->trace(Dumper($smil));

my $videos = $smil->{body}{seq}{video};
$log->trace(Dumper($videos));

for my $bitrate (300, 800)
{
	my $stitch_cmd = $opt{mp4box};

	my $pause_file = $opt{pause_file};
	$pause_file =~ s/<BITRATE>/$bitrate/;
	sys("$opt{mediainfo} $pause_file");

	my $basename;
	my $tmp_file;
	my $video_num = 0;

	for my $video (@{$videos})
	{
		my $mov_file = basename($video->{src});

		if ($mov_file =~ /^pause/)
		{
			$stitch_cmd .= " -cat $pause_file";
			next;
		}

		$video_num++;

		my $video_name;
		if ($mov_file =~ /^(hi\d+_\d+)_\d+(_[a-z])?_cable.mov/i) {
			$video_name = uc($1 . empty($2));
		} else {
			$log->logdie("invalid filename: $mov_file");
		}

		$basename = "${video_name}_${bitrate}k_s.mp4";

		my $input_file = "$opt{content_dir}/$video_name/aux/$basename";

		$tmp_file = "$opt{tmp_dir}/$basename";

		# Copy input file to temp directory for processing.
		# To speed things up we skip copy and use existing dest
		# file if src and dest don't differ.
		if (compare($input_file, $tmp_file)) {
			$log->debug("Copying $host:$input_file to $tmp_file");
			copy($input_file, $tmp_file)
			  or $log->logdie("can't copy $input_file to $tmp_file: $!");
		} else {
			$log->debug("Using existing file $tmp_file");
		}
		sys("$opt{mediainfo} $tmp_file");

		my $split_file = "$opt{tmp_dir}/$basename.splitx-$video_num";

		if (-f $split_file) {
			$log->logdie("Split file $split_file already exists");
		}

		my $start = get_seconds($video->{clipBegin});
		my $end   = get_seconds($video->{clipEnd});

		# trim beginning and ending of mp4 file according to
		# timecode in smil file
		sys("$opt{mp4box} -splitx $start:$end -out $split_file $tmp_file");
		sys("$opt{mediainfo} $split_file");

		$stitch_cmd .= " -cat $split_file";

	}

	$basename = "${stitch_name}_${bitrate}k_s.mp4";
	$tmp_file = "$opt{tmp_dir}/$basename";
	my $output_file = "$opt{stitch_dir}/$basename";

	$stitch_cmd .= " -new $tmp_file";

	sys($stitch_cmd);

	$log->debug("Moving $tmp_file to $host:$output_file");
	move($tmp_file, $output_file)
	  or $log->logdie("can't move $tmp_file to $output_file: $!");
}


sub get_seconds
{
	my $timecode = shift;
	$timecode =~ s/npt=//;
	$log->trace("timecode=$timecode");
	my ($hrs, $min, $sec) = split(":", $timecode);

	$sec += $min * 60;
	$sec += $hrs * 60 * 60;
	
	return sprintf("%.3f", $sec);
}


sub sys
{
	my @cmd = @_;
	$log->debug("running command @cmd");
	my $start_time = time;
	my ($output, $success, $exit_code) = capture_exec_combined(@cmd);
	my $end_time = time;
	$output =~ s/\r/\n/g;  # replace carriage returns with newlines
	$log->debug("output: $output");
	$log->debug("run time: ", duration_exact($end_time - $start_time));
	if (!$success) {
		$log->logdie("The exit code was " . ($exit_code >> 8));
	}
}


sub usage
{
	my %opt = @_;
	print STDERR "\nUsage: $0 [options] <smil_file>\n\noptions:\n\n";
	for my $opt_name (sort keys %opt)
	{
		print STDERR "  --$opt_name\t(default: $opt{$opt_name})\n";
	}
	print STDERR "\n";
}


sub empty
{
	shift || "";
}

