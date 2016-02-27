#!/bin/bash

for file in *.d
do
	echo $file
	dmd util/testutil.d -I../ ../deimos/nanomsg/nn.d -L-lnanomsg -run "$file"
done
