#!/bin/bash

set -e

dirname=$1
verbose=${VERBOSE:-1}
start_dir=$(pwd)

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

CLLOG "Zipping project..."
tarfile=$projname.tar.gz
tar -czf $tarfile $projname

if [ -n "$S3_BUCKET" ]; then
    s3_url=s3://$S3_BUCKET/$tarfile

    CLLOG "Uploading zip..."
    aws s3 cp $tarfile $s3_url

    CLLOG "Signing URL..."
    signed_url=$(aws s3 presign $s3_url --expires-in=${S3_EXPIRATION:-86400})

    CLLOG "Cleaning up..."
    rm $tarfile

    echo $signed_url
else
    mv $tarfile $start_dir/
fi

rm -r $projname

