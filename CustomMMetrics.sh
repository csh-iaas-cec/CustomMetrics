#!/bin/bash
# Copyright 2019 Oracle or its affiliates. All Rights Reserved
# Custom Metric Script
# Usage: CustomMetrics.sh [option]
#	collects memory utilization on an Oracle Linux
#	and sends this data as custom metrics to Oracle Monitoring Service
# 
# Description of available option:
#
#	--mntpath = AbsolutePath Specifies the location of the disk to be monitored
#	--ocipath = PATH	Specifies the location of oci cli
#
# All memory utilization values are converted or used in GB
#
# Examples
#
#	To set a five-minute cron schedule to report memory utilization to OCI Monitoring Service
#	*/5 * * * * /bin/sh /home/opc/test/custom_metric.sh --mntpath="/home/project" --ocipath="/home/opc/bin" >> /home/opc/test/custom_metric.log
#
SHELL=/bin/sh
mntpath="/home/project"
PATH=/home/opc/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/opc/.local/bin:/home/opc/bin:/home/opc/test/:
len=`echo ${#mntpath}`
function float_to_int(){
         printf '%.*f\n' 0 $1
}
if [[ $len == 0 ]]
then
        echo "no path provided"
else
	if [[ -d $mntpath ]]
	then
        echo "fetching data"
        readarray -t array <<< "$(df -h -l -P $mntpath)"
		line=${array[@]/${array[0]}}
		IFS=', ' read -r -a fields <<< "$line"
		diskTotal=${fields[1]}
		#diskTotal=${diskTotal::-1}
		echo "Disk Total : $diskTotal"
		diskUsedinO=${fields[2]}
		if [[ $diskUsedinO =~ "M" ]]
		then
        	echo "found in MB converting to GB"
        	diskUsed=`expr ${diskUsedinO::-1} / 1024`
        	diskUsed=`expr ${diskUsed} \* 100`
        	diskUsed=`expr ${diskUsed} / ${diskTotal::-1}`
		fi
		if [[ $diskUsedinO =~ "G" ]]
		then
        	echo "found in GB"
        	num=`float_to_int ${diskUsedinO::-1}`
        	echo $num
        	diskUsed=`expr ${num} \* 100`
        	diskUsed=`expr ${diskUsed} / ${diskTotal::-1}`
		fi
		echo "Disk Used : $diskUsedinO"
		echo "Disk used percentage : $diskUsed %"
		diskAvailableinO=${fields[3]}
		number=`float_to_int ${diskAvailableinO::-1}`
		echo $number
		diskAvailable=`expr ${number} \* 100`
		diskAvailable=`expr ${diskAvailable} / ${diskTotal::-1}`
		#diskAvailable=${diskAvailable::-1}
		echo "Disk Available : $diskAvailableinO"
		echo "Disk Available percent : $diskAvailable %"
		fileSystem=${fields[0]}
		echo "File System : $fileSystem"
		mount=${fields[5]}
		echo "Mount : $mount"
		d=`date -u +%Y-%m-%d"T"%H:%M:%S"Z"`
		echo $d
		h=`hostname`
		jq -M '.[].datapoints[].value = $Value|.[].datapoints[].timestamp=$din|.[].dimensions.ServerName=$serverName|.[].dimensions.DiskName=$diskName' --arg Value ${diskUsed} --arg din ${d} --arg serverName ${h} --arg diskName ${mntpath} /home/opc/test/test.json > /home/opc/test/tempfiles/tmp.$$.json && mv /home/opc/test/tempfiles/tmp.$$.json /home/opc/test/test.json
		pwd
		cat /home/opc/test/test.json
		/home/opc/bin/oci monitoring metric-data post --endpoint https://telemetry-ingestion.us-ashburn-1.oraclecloud.com --metric-data file:///home/opc/test/test.json --auth instance_principal

	else
        echo "path does not exists"
	fi
fi

