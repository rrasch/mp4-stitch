## NAME ##

Mp4-stitch - Stitch mp4 files for HIDVL AD project.

## DESCRIPTION ##

Mp4-stitch is a tool to stitch HIDVL Abu Dhabi video content.
It generates a mp4 file based on a video playlist defined in
an hidvl smil file.  It works by first parsing the smil file to
extract the filename and start/stop timecodes for each video.
For each of these videos, it then extracts as a new video clip
the section of the video defined by the timecodes. For example,
if a video has a start timecode of 00:00:31 and stop timecode
of 00:01:52, mp4-stitch will extract a new mp4 file that is 81
seconds long.  In the final step, mp4-stitch concatenates all
of the newly generate clips into a new mp4 file.  A pause of 5
seconds will be inserted between each of the video clips.

## SYNOPSIS ##

   mp4-stitch [options] <smil_file>

To get a list of options and their default values, run mp4-stitch
with no arguments.  Descriptions of these options can be found
in the conf/mp4-stitch.conf file.

## REQUIREMENTS ##

Perl with the following modules:

- AppConfig
- IO::CaptureOutput
- Log::Log4perl
- Time::Duration
- XML::Simple

MP4Box - http://gpac.sourceforge.net/

MediaInfo - http://mediainfo.sourceforge.net/

Also insure you have enough disk space for your output and tmp
directories.

## INSTALLATION ##

The easiest way is install using the rpm provided.

    sudo rpm -Uvh mp4-stitch-<version>.noarch.rpm

## AUTHOR ##

Rasan Rasch (rasan@nyu.edu)

