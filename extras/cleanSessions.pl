#
# Shell script to clean up sesisons directories
#
 find /data/www -type d -name wikidb 2>/dev/null | \

  while read a ; 
  find /data/www -type d -name wikidb 2>/dev/null | \

  while read a ; do
  find $a/sessions -mtime 8 | xargs rm
  done
