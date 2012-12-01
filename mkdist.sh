#!/bin/sh
BASE=/home/piers/git/public/ruby-sapnwrfc
cd $BASE
find . -name '*.log' -type f -exec echo \> {} \;
find . -name 'rfc*trc' -type f -exec rm -f {} \;
find . -name '*~' -type f -exec rm -f {} \;

VERS=0.26
DIST=sapnwrfc-$VERS
BALL=$DIST.tar.gz
ZIP=$DIST.zip

export VERS
#perl -i -ne 's/\d\.\d\d/$ENV{VERS}/;print' *.gemspec build.sh
ruby -i -ne '$_.sub!(/\d\.\d\d/, ENV["VERS"]); print' *.gemspec build.sh

./build.sh

./doco

if [ -d $DIST ]; then
  echo "removing: $DIST ..."
  rm -rf $DIST
fi

if [ -f $BALL ]; then
  echo "removing: $BALL ..."
  rm -f $BALL
fi

if [ -f $ZIP ]; then
  echo "removing: $ZIP ..."
  rm -f $ZIP
fi

echo "setting up the distribution foot print $DIST ..."
mkdir -p $DIST
for i in `cat MANIFEST`
do
  DIR=`perl -e '$ARGV[0] =~ s/^(.*)\/.*?$/$1/; print $ARGV[0]' $i`
  if [ -d $DIR ]; then
    echo "making dir: $DIR"
    mkdir -p $DIST/$DIR
  fi
  echo "copy $BASE/$i to $DIST/$i ..."
	if [ -f $BASE/$i ]; then
	  echo "$BASE/$i exists..."
	else
	  if [ -d $BASE/$i ]; then
	    echo "$BASE/$i exists..."
		else
	    echo "$BASE/$i IS MISSING !!!"
		  exit 1
		fi
	fi
  cp -a $i $DIST/$i
done

echo "make tar ball: $BALL"
tar -czvf $BALL $DIST
ls -l $BALL

echo "make zip: $ZIP"
zip -r $ZIP $DIST
ls -l $ZIP

if [ -d $DIST ]; then
  echo "removing: $DIST ..."
  rm -rf $DIST
fi
echo "Done."

chmod -R a+r doc $BALL $ZIP

echo "Copy up documentation"
rsync -av --delete --rsh=ssh doc piersharding.com:www/download/ruby/sapnwrfc/

echo "Copy up distribution"
scp $BALL piersharding.com:www/download/ruby/sapnwrfc/
scp $ZIP piersharding.com:www/download/ruby/sapnwrfc/
