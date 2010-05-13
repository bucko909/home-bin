#!/bin/bash

#RIP_TEMP=/smb/newton/media_rw/media4/temp
RIP_TEMP=/smb/newton/media/peer2peer
ENC_TEMP=/disks/media
FINAL=/disks/media
LOGS=/disks/media

run_long() {
	fn=$1
	shift
	echo "$*"
	$* > $LOGS/$fn.out 2> $LOGS/$fn.err
}
run_cmd() {
	run_long "$*"
}


BASE=$1
ACTIONS="$2"
if [ -z "$ACTIONS" ]; then
	ACTIONS="get_dvd_info find_tracks rip_titles extract_tracks remove_vobs encode_tracks merge_tracks clean"
fi

for ACTION in $ACTIONS; do
case $ACTION in
get_dvd_info)
	echo get_dvd_info
	mplayer dvd:// -frames 1 -vo null -ao null > $LOGS/$BASE.mplayer_output 2> $LOGS/$BASE.mplayer_stderr
	TITLES="$(perl -ne '/^There are (\d+) titles on this DVD\./&&print"$1"' $BASE.mplayer_output)"
	echo Titles: $TITLES

	rm $FINAL/$BASE.rip_profile
	echo "Disc_name = \"\";" >> $FINAL/$BASE.rip_profile
	for TITLE in $(seq 1 $TITLES); do
		echo Title $TITLE:
		echo -n "TITLE_$TITLE: " >> $FINAL/$BASE.rip_profile
		echo -n "Series = \"\"; Season = \"\"; " >> $FINAL/$BASE.rip_profile
		mplayer dvd://$TITLE -frames 1 -vo null -ao null > $LOGS/$BASE.tit_$TITLE.mplayer_output 2> $LOGS/$BASE.tit_$TITLE.mplayer_stderr
		FPS="$(perl -ne '/^VIDEO:  MPEG2.*?(\d+\.\d+) fps/&&print"$1"' $BASE.tit_$TITLE.mplayer_output)"
		TELECINE=1 # TODO infer
		CHAPTERS="$(perl -ne '/^There are (\d+) chapters in this DVD title\./&&print"$1"' $BASE.tit_$TITLE.mplayer_output)"
		ANGLES="$(perl -ne '/^There are (\d+) angles in this DVD title\./&&print"$1"' $BASE.tit_$TITLE.mplayer_output)"
		AUDIO_CHANNELS="$(perl -ne '/^number of audio channels on disk: (\d+)\./&&print"$1"' $BASE.tit_$TITLE.mplayer_output)"
		SUBTITLES="$(perl -ne '/^number of subtitles on disk: (\d+)/&&print"$1"' $BASE.tit_$TITLE.mplayer_output)"
		echo -n "Telecine = $TELECINE; " >> $FINAL/$BASE.rip_profile
		echo -n "FPS = $FPS; " >> $FINAL/$BASE.rip_profile
		echo -n "Chapters = $CHAPTERS; " >> $FINAL/$BASE.rip_profile
		if [ "$CHAPTERS" -ge 5 ]; then
			echo -n "Type = Feature; " >> $FINAL/$BASE.rip_profile
		else
			echo -n "Type = Extras; " >> $FINAL/$BASE.rip_profile
		fi
		if [ "$ANGLES" -ne 1 ]; then echo "Angles = $ANGLES; " >> $FINAL/$BASE.rip_profile; fi
		echo "	"Chapters: $CHAPTERS
		echo "	"Audio channels: $AUDIO_CHANNELS
		echo -n "Audio = $AUDIO_CHANNELS; " >> $FINAL/$BASE.rip_profile
		for AUDIO_CHANNEL in $(seq 0 $(expr $AUDIO_CHANNELS - 1)); do
			LANGUAGE="$(perl -ne '/^audio stream: '$AUDIO_CHANNEL' .* language: (\w+)/&&print"$1"' $BASE.tit_$TITLE.mplayer_output)"
			FORMAT="$(perl -ne '/^audio stream: '$AUDIO_CHANNEL' format: (\S+)/&&print"$1"' $BASE.tit_$TITLE.mplayer_output)"
			AID="$(perl -ne '/^audio stream: '$AUDIO_CHANNEL' .* aid: (\d+)/&&print"$1"' $BASE.tit_$TITLE.mplayer_output)"
			if [ "$LANGUAGE" = "ja" -o "$LANGUAGE" = "jp" ]; then
				L2=jpn
				NAME=Japanese
			elif [ "$LANGUAGE" = "en" ]; then
				L2=eng
				NAME=English
			else
				L2=$LANGUAGE
				NAME=$LANGUAGE
			fi
			echo -n "Audio_$AUDIO_CHANNEL"_name = \"$NAME\"\;" " >> $FINAL/$BASE.rip_profile
			echo -n "Audio_$AUDIO_CHANNEL"_language = $L2\;" " >> $FINAL/$BASE.rip_profile
			echo -n "Audio_$AUDIO_CHANNEL"_format = $FORMAT\;" " >> $FINAL/$BASE.rip_profile
			echo -n "Audio_$AUDIO_CHANNEL"_aid = $AID\;" " >> $FINAL/$BASE.rip_profile
		done
		echo -n "Subtitles = $SUBTITLES; " >> $FINAL/$BASE.rip_profile
		echo "	"Subtitles: $SUBTITLES
		for SUBTITLE in $(seq 0 $(expr $SUBTITLES - 1)); do
			LANGUAGE="$(perl -ne '/^subtitle \( sid \): '$SUBTITLE' language: (\w+)/&&print"$1"' $BASE.tit_$TITLE.mplayer_output)"
			if [ "$LANGUAGE" = "ja" -o "$LANGUAGE" = "jp" ]; then
				L2=jpn
				NAME=Japanese
			elif [ "$LANGUAGE" = "en" ]; then
				L2=eng
				NAME=English
			else
				L2=$LANGUAGE
				NAME=$LANGUAGE
			fi
			echo -n "Subtitle_$SUBTITLE"_name = \"$NAME\"\;" " >> $FINAL/$BASE.rip_profile
			echo -n "Subtitle_$SUBTITLE"_language = $L2\;" " >> $FINAL/$BASE.rip_profile
		done
		echo "	"Angles: $ANGLES
		echo -n "Angles = $ANGLES; " >> $FINAL/$BASE.rip_profile
		if [ "$ANGLES" = 1 ]; then
			echo -n "Angle_1" = \"Video\"\;" " >> $FINAL/$BASE.rip_profile
		else
			for ANGLE in $(seq 1 $ANGLES); do
				echo -n "Angle_$ANGLE"_name = \"Angle $ANGLE\"\;" " >> $FINAL/$BASE.rip_profile
			done
		fi
		echo >> $FINAL/$BASE.rip_profile
		dvdxchap -t $TITLE /dev/dvd > $LOGS/$BASE.tit_$TITLE.chapters.txt
		if [ "$CHAPTERS" -ge 5 ]; then
			perl -ne 'if(/CHAPTER0*(\d+)=(\d+):(\d+):(\d+).(\d+)/){$pn=$2*3600+$3*60+$4+$5/1000;$l[$1-1]=$pn-$p if$1>1;$p=$pn;$p[$1]="$2:$3:$4.$5";$pl[$1]=$pn;}END{$e=int($pl[$#pl]/1320);for$n(1..$#l){@a=grep{abs($l[$_]-$l[$n])<3}(1..$#l);if($l[$n]<120&&@a>=$e-1){$r[$c++]=$n;last if$c==2}}for(1..$#p){print"CHAPTER_$_: ";if(abs($l[$r[0]+$_-1]-$l[$r[0]])<3){print "Episode = ".++$ep."; Episode_name = \"\"; ";$part=0;}print"Chapter_name = \"";if (abs($l[$r[0]]-$l[$_])<3){print"Opening Credits"}elsif(abs($l[$r[1]]-$l[$_])<3){print"Closing Credits"}else{print"Part ".++$part}print"\"; ";print"Chapter_start = $p[$_]; Chapter_length = ".sprintf("%.3f",$l[$_]).";\n"}}' < $LOGS/$BASE.tit_$TITLE.chapters.txt >> $FINAL/$BASE.rip_profile
		else
			perl -ne 'if(/CHAPTER0*(\d+)=(\d+):(\d+):(\d+).(\d+)/){$pn=$2*3600+$3*60+$4+$5/1000;$l[$1]=$pn-$p;$p=$pn;$p[$1]="$2:$3:$4.$5";$pl[$1]=$pn;}END{for(1..$#p){print"CHAPTER_$_: Extra = T'$TITLE'C$_; Extra_name = \"\"; ";print"Chapter_name = \"Part ".++$part."\"; ";print"Chapter_start = $p[$_]; Chapter_length = ".sprintf("%.3f",$l[$_]).";\n"}}' < $LOGS/$BASE.tit_$TITLE.chapters.txt >> $FINAL/$BASE.rip_profile
		fi
	done
;;
rip_titles)
	if mount /mnt/cdrom0; then
		UM=1
	fi
	# Now rip the raw VOBs; we won't need the DVD anymore after this.
	for TITLE in $(seq 1 $TITLES); do
		echo "Ripping title $TITLE:";
		echo "	Copying IFO file...";
		cp /mnt/cdrom0/video_ts/vts_"$TITLE"_0.ifo $RIP_TEMP/$BASE.tit_$TITLE.vts.ifo
		echo "	Copying VOB stream...";
		run_long $BASE.tit_$TITLE.mplayer_rip_vob \
			mplayer dvd://$TITLE -dumpstream -dumpfile $RIP_TEMP/$BASE.tit_$TITLE.rawvob.vob
		echo
		# TODO multi angle here
	done
	if [ "$UM" = 1 ]; then
		umount /mnt/cdrom0
	fi
;;
find_tracks)
	echo find_tracks
	# Add some episode based stats
	perl -ne '{
	my($status,$name,$title,$chap,$start,$len,$type,$ignore);
	sub finish_track {
		print $cstatus."_$cname $ctitle $cstart $clen\n" unless $cignore;
		undef $cstatus;
	}
	if(/TITLE_(\d+)/) {
		$title = $1;
		if (defined $cstatus) {
			finish_track();
		}
		$ctitle = $title;
	}
	if(/CHAPTER_(\d+)/) { $chap = $1 }
	if(/Episode\s*=\s*(\d+)/) { $name = $1; $status = "ep" }
	if(/Extra\s*=\s*([^;]+)/) { $name = $1; $status = "ex" }
	if(/Type\s*=\s*"([^"]+")/) { $status = $1 }
	if(/Ignore\s*=\s*1/) { $ignore = 1 }
	if(/Chapter_start\s*=\s*([0-9:.]+)/) { $start = $1 }
	if(/Chapter_length\s*=\s*([0-9.]+)/) { $len = $1 }
	if (defined $status && ($ctatus ne $status || $name ne $cname)) {
		if (defined $cstatus) {
			finish_track();
		}
		$cname = $name;
		$cstatus = $status;
		$clen = $len;
		$cstart = $start;
		$cignore = $ignore;
	} elsif ($len) {
		$clen += $len;
	}
	}
	END {
		finish_track() if $cstatus;
	}
	' $FINAL/$BASE.rip_profile > $ENC_TEMP/$BASE.tracks
;;
extract_tracks)
	echo extract_tracks
	cat $ENC_TEMP/$BASE.tracks|while read NAME TITLE START LENGTH; do
		echo "Track: $NAME:"
		echo "	Title: $TITLE"
		AUDIO_CHANNELS="$(perl -ne '/^TITLE_'$TITLE':.*Audio = (\d+);/&&print"$1"' $FINAL/$BASE.rip_profile)"
		SUBTITLES="$(perl -ne '/^TITLE_'$TITLE':.*Subtitles = (\d+);/&&print"$1"' $FINAL/$BASE.rip_profile)"
		ANGLES="$(perl -ne '/^TITLE_'$TITLE':.*Angles = (\d+);/&&print"$1"' $FINAL/$BASE.rip_profile)"

		TRACK_ONLY="$RIP_TEMP/$BASE.tit_$TITLE.rawvob.vob -ss $START -endpos $LENGTH"
		for AUDIO_CHANNEL in $(seq 0 $(expr $AUDIO_CHANNELS - 1)); do
			FORMAT="$(perl -ne '/^TITLE_'$TITLE':.*Audio_'$AUDIO_CHANNEL'_format = ([^;]+);/&&print"$1"' $FINAL/$BASE.rip_profile)"
			AID="$(perl -ne '/^TITLE_'$TITLE':.*Audio_'$AUDIO_CHANNEL'_aid = ([^;]+);/&&print"$1"' $FINAL/$BASE.rip_profile)"
			echo "	Extracting audio track $AUDIO_CHANNEL ($AID/$FORMAT)...";
			run_long $BASE.$NAME.mencoder_extract_audio-$AUDIO_CHANNEL \
				mencoder $TRACK_ONLY -aid $AID -oac copy -of rawaudio -o $ENC_TEMP/$BASE.$NAME.audio-$AUDIO_CHANNEL.$FORMAT -ovc frameno
		done
		for SUBTITLE in $(seq 0 $(expr $SUBTITLES - 1)); do
			echo "	Extracting subtitle track $SUBTITLE..."
			#		tccat -i $BASE.tit_$TITLE.rawvob.vob -L | tcextract -x ps1 -t vob -a $(expr 32 + $SUBTITLE) > $BASE.tit_$TITLE.subs-$SUBTITLE
			#		subtitle2vobsub -o $BASE.tit_$TITLE.vobsubs-$SUBTITLE -i $BASE.tit_$TITLE.vts.ifo -a $SUBTITLE < $BASE.tit_$TITLE.subs-$SUBTITLE
			run_long $BASE.$NAME.mencoder_extract_subtitle-$SUBTITLE \
				mencoder $TRACK_ONLY -oac copy -ovc frameno -vobsubout $ENC_TEMP/$BASE.$NAME.subs-$SUBTITLE -vobsuboutindex 0 -sid $SUBTITLE -o /dev/null
		done
		for ANGLE in $(seq 1 $ANGLES); do
			echo "	Extracting video angle $ANGLE..."
			run_long $BASE.$NAME.mencoder_extract_video-$ANGLE \
				mencoder $TRACK_ONLY -oac copy -ovc copy -of rawvideo -o $ENC_TEMP/$BASE.$NAME.video-$ANGLE.mpeg
		done
		echo
	done
;;
remove_vobs)
	echo remove_vobs
	# We should at this point be done with the VOBs, too.
	for TITLE in $(seq 1 $TITLES); do
		echo "Removing VOB for title $TITLE."
		run_long $BASE.tit_$TITLE.remove_vob \
			rm $RIP_TEMP/$BASE.tit_$TITLE.rawvob.vob
	done
;;
encode_tracks)
	echo encode_tracks
	cat $ENC_TEMP/$BASE.tracks|while read NAME TITLE START LENGTH; do
		echo "Track $NAME..."
		ANGLES="$(perl -ne '/^TITLE_'$TITLE':.*Angles = (\d+);/&&print"$1"' $FINAL/$BASE.rip_profile)"
		for ANGLE in $(seq 1 $ANGLES); do
			run_long $BASE.$NAME.mencoder_encode_angle_$ANGLE \
				mencoder $ENC_TEMP/$BASE.$NAME.video-$ANGLE.mpeg -o $ENC_TEMP/$BASE.$NAME-video-$ANGLE.264 \
					-vf pullup,softskip,harddup \
					-ofps 24000/1001 -of rawvideo \
					-oac copy \
					-ovc x264 -x264encopts crf=20:subq=6:bframes=4:8x8dct:frameref=13:partitions=all:b_pyramid:weight_b:threads=auto
			# old filters: pullup instead of filmdint
			run_long $BASE.$NAME.mp4creator_video_angle_$ANGLE \
				mp4creator -c $ENC_TEMP/$BASE.$NAME-video-$ANGLE.264 -rate 23.976 $ENC_TEMP/$BASE.$NAME-video-$ANGLE.mp4
		done
	done
;;
merge_tracks)
	echo merge_tracks
	cat $ENC_TEMP/$BASE.tracks|while read NAME TITLE START LENGTH; do
		echo "Track $NAME..."
		AUDIO_CHANNELS="$(perl -ne '/^TITLE_'$TITLE':.*Audio = (\d+);/&&print"$1"' $FINAL/$BASE.rip_profile)"
		SUBTITLES="$(perl -ne '/^TITLE_'$TITLE':.*Subtitles = (\d+);/&&print"$1"' $FINAL/$BASE.rip_profile)"
		ANGLES="$(perl -ne '/^TITLE_'$TITLE':.*Angles = (\d+);/&&print"$1"' $FINAL/$BASE.rip_profile)"
		case $NAME in
			ep_*)
				EPNO=${NAME#ep_}
				SERIES="$(perl -ne '/^TITLE_'$TITLE':.*Series = "([^"]+)";/&&print"$1"' $FINAL/$BASE.rip_profile)"
				SEASON="$(perl -ne '/^TITLE_'$TITLE':.*Season = "([^"]+)";/&&print"$1"' $FINAL/$BASE.rip_profile)"
				ETITLE="$(perl -ne '/Episode = '$EPNO';.*Episode_name = "([^"]+)";/&&print"$1"' $FINAL/$BASE.rip_profile)"
				FILENAME="$SERIES"
				if [ -n "$SEASON" ]; then FILENAME="$FILENAME - $SEASON"; fi
				FILENAME="$FILENAME - $EPNO"
				if [ -n "$ETITLE" ]; then FILENAME="$FILENAME - $ETITLE"; fi
				FILENAME="$FILENAME.mkv"
				# Build a chapter file
				perl -ne '
				BEGIN{
					$o="'$START'";
					$o=~/(\d+):(\d+):(\d+)\.(\d+)/;
					$o = $1 * 3600 + $2 * 60 + $3 + $4 / 1000;
				}
				$m=0 if/Episode =/;
				$m=1 if/Episode = '$EPNO';/;
				if ($m) {
					/Chapter_start = (\d+):(\d+):(\d+)\.(\d+);/;
					$s = $1 * 3600 + $2 * 60 + $3 + $4 / 1000;
					/Chapter_length = ([^;]*);/;
					$l = $1;
					/Chapter_name = "([^"]*)";/;
					$n = $1;
					$s -= $o;
					$sn = sprintf("%02i:%02i:%02i.%03i", $s/3600, ($s/60)%60, $s%60, ($s*1000)%1000);
					$cn = sprintf("%02i",++$c);
					print "CHAPTER$cn=$sn\n";
					print "CHAPTER".$cn."NAME=".($n||"Chapter $cn")."\n";
				}
				' $FINAL/$BASE.rip_profile > $ENC_TEMP/$BASE.$NAME.chapters.txt
				TNAME="$(perl -ne '/Episode = '$EPNO';.*Episode_name = "([^"]+)";/&&print"$1"' $FINAL/$BASE.rip_profile)"
			;;
			*)
				SNAME=${NAME#*_}
				DTITLE="$(perl -ne '/Disc_name = "([^"]+)";/&&print"$1"' $FINAL/$BASE.rip_profile)"
				ETITLE="$(perl -ne '/Extra = "'$SNAME'";.*Extra_name = "([^"]+)";/&&print"$1"' $FINAL/$BASE.rip_profile)"
				FILENAME="$DTITLE"
				if [ -n "$ETITLE" ]; then
					FILENAME="$FILENAME - $ETITLE"
				else
					FILENAME="$FILENAME - $NAME"
				fi
				FILENAME="$FILENAME.mkv"
				perl -ne '
				BEGIN{
					$o="'$START'";
					$o=~/(\d+):(\d+):(\d+)\.(\d+)/;
					$o = $1 * 3600 + $2 * 60 + $3 + $4 / 1000;
				}
				$m=0 if/Extra =/;
				$m=1 if/Extra = '$SNAME';/;
				if ($m) {
					/Chapter_start = (\d+):(\d+):(\d+)\.(\d+);/;
					$s = $1 * 3600 + $2 * 60 + $3 + $4 / 1000;
					/Chapter_length = ([^;]*);/;
					$l = $1;
					/Chapter_name = "([^"]*)";/;
					$n = $1;
					$s -= $o;
					$sn = sprintf("%02i:%02i:%02i.%03i", $s/3600, ($s/60)%60, $s%60, ($s*1000)%1000);
					$cn = sprintf("%02i",++$c);
					print "CHAPTER$cn=$sn\n";
					print "CHAPTER".$cn."NAME=".($n||"Chapter $cn")."\n";
				}
				' $FINAL/$BASE.rip_profile > $ENC_TEMP/$BASE.$NAME.chapters.txt
				TNAME="$(perl -ne '/^Extra = '$SNAME';.*Episode_name = "([^"]+)"/&&print"$1"' $FINAL/$BASE.rip_profile)"
			;;
		esac
		FILENAME="$(echo "$FILENAME"|tr -d '!')"

		unset PARAMS
		declare -a PARAMS
		for AUDIO_CHANNEL in $(seq 0 $(expr $AUDIO_CHANNELS - 1)); do
			FORMAT="$(perl -ne '/^TITLE_'$TITLE':.*Audio_'$AUDIO_CHANNEL'_format = ([^;]+);/&&print"$1"' $FINAL/$BASE.rip_profile)"
			LANGUAGE="$(perl -ne '/^TITLE_'$TITLE':.*Audio_'$AUDIO_CHANNEL'_language = ([^;]+);/&&print"$1"' $FINAL/$BASE.rip_profile)"
			ANAME="$(perl -ne '/^TITLE_'$TITLE':.*Audio_'$AUDIO_CHANNEL'_name = "([^"]+)";/&&print"$1"' $FINAL/$BASE.rip_profile)"
			DEFAULT="$(perl -ne '/^TITLE_'$TITLE':.*Audio_'$AUDIO_CHANNEL'_default = 1;/&&print"$1"' $FINAL/$BASE.rip_profile)"
			if [ -n "$DEFAULT" ]; then
				PARAMS[${#PARAMS[@]}]="--default-track"
				PARAMS[${#PARAMS[@]}]="0"
			fi
			if [ -n "$LANGUAGE" ]; then
				PARAMS[${#PARAMS[@]}]="--language"
				PARAMS[${#PARAMS[@]}]="0:$LANGUAGE"
			fi
			if [ -n "$ANAME" ]; then
				PARAMS[${#PARAMS[@]}]="--track-name"
				PARAMS[${#PARAMS[@]}]="0:$ANAME"
			fi
			PARAMS[${#PARAMS[@]}]="$BASE.$NAME.audio-$AUDIO_CHANNEL.$FORMAT"
		done
		for SUBTITLE in $(seq 0 $(expr $SUBTITLES - 1)); do
			LANGUAGE="$(perl -ne '/^TITLE_'$TITLE':.*Subtitle_'$SUBTITLE'_language = ([^;]+);/&&print"$1"' $FINAL/$BASE.rip_profile)"
			ANAME="$(perl -ne '/^TITLE_'$TITLE':.*Subtitle_'$SUBTITLE'_name = "([^"]+)";/&&print"$1"' $FINAL/$BASE.rip_profile)"
			DEFAULT="$(perl -ne '/^TITLE_'$TITLE':.*Subtitle_'$SUBTITLE'_default = 1;/&&print"$1"' $FINAL/$BASE.rip_profile)"
			if [ -n "$DEFAULT" ]; then
				PARAMS[${#PARAMS[@]}]="--default-track"
				PARAMS[${#PARAMS[@]}]="0"
			fi
			if [ -n "$LANGUAGE" ]; then
				PARAMS[${#PARAMS[@]}]="--language"
				PARAMS[${#PARAMS[@]}]="0:$LANGUAGE"
			fi
			if [ -n "$ANAME" ]; then
				PARAMS[${#PARAMS[@]}]="--track-name"
				PARAMS[${#PARAMS[@]}]="0:$ANAME"
			fi
			PARAMS[${#PARAMS[@]}]="$BASE.$NAME.subs-$SUBTITLES.idx"
		done
		for ANGLE in $(seq 1 $ANGLES); do
			LANGUAGE="$(perl -ne '/^TITLE_'$TITLE':.*Angle_'$ANGLE'_language = ([^;]+);/&&print"$1"' $FINAL/$BASE.rip_profile)"
			ANAME="$(perl -ne '/^TITLE_'$TITLE':.*Angle_'$ANGLE'_name = "([^"]+)";/&&print"$1"' $FINAL/$BASE.rip_profile)"
			ASPECT="$(perl -ne '/^TITLE_'$TITLE':.*Angle_'$ANGLE'_aspect = ([^;]+);/&&print"$1"' $FINAL/$BASE.rip_profile)"
			FPS="$(perl -ne '/^TITLE_'$TITLE':.*FPS = ([^;]+);/&&print"$1"' $FINAL/$BASE.rip_profile)"
			DEFAULT="$(perl -ne '/^TITLE_'$TITLE':.*Angle_'$ANGLE'_default = 1;/&&print"$1"' $FINAL/$BASE.rip_profile)"
			if [ -n "$DEFAULT" ]; then PARAMS[${#PARAMS[@]}]="--default-track"; PARAMS[${#PARAMS[@]}]="1"; fi
			if [ -n "$FPS" ]; then
				PARAMS[${#PARAMS[@]}]="--timecodes"; PARAMS[${#PARAMS[@]}]="1:$BASE.$NAME.video-$ANGLE.time"
				echo "# timecode format v1" > $ENC_TEMP/$BASE.$NAME.video-$ANGLE.time
				echo "assume $FPS" >> $ENC_TEMP/$BASE.$NAME.video-$ANGLE.time
			fi
			if [ -n "$ASPECT" ]; then
				PARAMS[${#PARAMS[@]}]="--aspect-ratio"
				PARAMS[${#PARAMS[@]}]="1:$ASPECT"
			fi
			if [ -n "$LANGUAGE" ]; then
				PARAMS[${#PARAMS[@]}]="--language"
				PARAMS[${#PARAMS[@]}]="1:$LANGUAGE"
			fi
			if [ -n "$ANAME" ]; then
				PARAMS[${#PARAMS[@]}]="--track-name"
				PARAMS[${#PARAMS[@]}]="1:$ANAME"
			fi
			PARAMS[${#PARAMS[@]}]="$BASE.$NAME.video-$ANGLE.mp4"
		done
		PARAMS[${#PARAMS[@]}]="--chapters"; PARAMS[${#PARAMS[@]}]="/smb/newton/media_rw/media4/temp/sr1.1-chapters.txt"
		run_long $BASE.$NAME.mkvmerge \
			mkvmerge ${PARAMS[@]} -o $FINAL/"$FILENAME"
	done
;;
clean)
;;
esac
done
