#!/bin/sh

B="ANN_id licensed stalled complete watching given_up watched wishlist not_buying on_dvd"
(
(echo -n "	"
for J in $B; do
	echo -n "$J	";
done; echo)|sed 's/^/<tr><th>/'|sed 's/	/<\/th><th>/g'|sed 's/<th>$/<\/tr>/'
	
for I in *; do
	echo -n "$I	"
	for J in $B; do
		if [ -L "$I"/"$J" ]; then
			echo -n "$J	"
		else
			echo -n "	"
		fi
	done
	echo
done|sed 's/^/<tr><td>/'|sed 's/	/<\/td><td>/g'|sed 's/<td>$/<\/tr>/'

(echo -n "$(ls Tags/licensed Tags/not_licensed|wc -l)	"
for J in $B; do
	echo -n "$(ls Tags/"$J"|wc -l)	"
done; echo)|sed 's/^/<tr><td>/'|sed 's/	/<\/td><td>/g'|sed 's/<td>$/<\/tr>/'
)|ssh uwcs.co.uk tee public_html/anime.html.inc
