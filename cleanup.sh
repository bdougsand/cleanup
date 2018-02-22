#!/bin/bash

set -e

dirname=$1
verbose=${VERBOSE:-1}

CLLOG() {
    ((verbose)) && echo $@
}

if [ ! -d "$dirname" ]; then
    echo "First argument should be a valid directory." && exit 1
fi

projname=$(basename $dirname)

# if [ -d "_outbox" ]; then
#     echo "There is already an _outbox directory. Please remove it and try again."
#     exit 1
# fi

mkdir -p _outbox

if [ -d "_outbox/$projname" ]; then
    CLLOG "Cleaning up old directory..."
    rm -rf _outbox/$dirname
fi

CLLOG "Copying files..."
cp -R $dirname _outbox/$projname/
cd _outbox/$projname

if [ -f ".clientignore" ]; then
    CLLOG "Processing .clientignore"
    while read line || [[ -n "$line" ]]; do
        if [[ line =~ ^/ ]]; then
            path_patt=".$line"
        else
            path_patt="*/$line"
        fi

        for filename in $(find . -path "$path_patt"); do
            CLLOG "Removing $filename"
            rm -r $filename
        done
    done < .clientignore
    rm .clientignore
fi

if ((!NO_TOUCHING)); then
    find . -exec touch {} \;
fi

cd ..

if [ -z "$S3_BUCKET" ]; then
    echo "No S3 bucket set; no ZIP file created" && exit 1
fi

s3_url=s3://$S3_BUCKET/$projname.tar.gz

CLLOG "Zipping project..."
tar -czf $projname.tar.gz $projname

CLLOG "Uploading zip..."
aws s3 cp $projname.tar.gz $s3_url

CLLOG "Signing URL..."
signed_url=$(aws s3 presign $s3_url --expires-in=${S3_EXPIRATION:-86400})

CLLOG "Cleaning up..."
rm $projname.tar.gz
rm -r $projname

CLLOG "Done."
echo $signed_url
