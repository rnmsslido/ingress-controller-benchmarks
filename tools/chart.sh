# Copyright 2020 HAProxy Technologies LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

graph() {
    # Create graphs directory if it doesn't exist
    mkdir -p graphs/$1

    # Initialize data variables
    reqdata="-s"
    cpudata="-s"
    l_75="-bar1"
    l_95="-bar2"
    l_99="-bar3"
    s_502="-bar1"
    s_503="-bar2"
    s_504="-bar3"

    # Process each result file
    for file in $(find tmp/$1/ -name '*.txt'|sort); do
        c_502=0
        c_503=0
        c_504=0

        proxy="$(echo $file|awk -F '/' '{print $NF}'|awk -F '.' '{print $1}')"
        
        # Calculate average requests
        d=0
        for x in $(cat $file|grep Requests |awk -F ':' '{print $2}'|tr -d '\t'); do
            d=$(echo "($d + $x)/1"|bc)
        done

        # Process latency data
        if [ "$1" == "saturate" ]; then
            n="$(grep '75%' $file|awk '{print $3}' |tr  "\n" " ") 5"
            l_75="$l_75 $(echo "$n" |awk '{print ($1 + $2 + $3 + $4 + $5)/5*1000}')"
            n="$(grep '95%' $file|awk '{print $3}' |tr  "\n" " ") 5"
            l_95="$l_95 $(echo "$n" |awk '{print ($1 + $2 + $3 + $4 + $5)/5*1000}')"
            n="$(grep '99%' $file|awk '{print $3}' |tr  "\n" " ") 5"
            l_99="$l_99 $(echo "$n" |awk '{print ($1 + $2 + $3 + $4 + $5)/5*1000}')"
        else
            l_75="$l_75 $(echo "`grep '75%' $file |awk '{print $3}'` * 1000" | bc)"
            l_95="$l_95 $(echo "`grep '95%' $file |awk '{print $3}'` * 1000" | bc)"
            l_99="$l_99 $(echo "`grep '99%' $file |awk '{print $3}'` * 1000" | bc)"
        fi

        # Process error counts
        if [ "$(grep responses $file |grep 502|awk '{print $2}')" ]; then
            c_502=$(grep responses $file |grep 502|awk '{print $2}')
        fi
        if [ "$(grep responses $file |grep 503|awk '{print $2}')" ]; then
            c_503=$(grep responses $file |grep 503|awk '{print $2}')
        fi
        if [ "$(grep responses $file |grep 504|awk '{print $2}')" ]; then
            c_504=$(grep responses $file |grep 504 |awk '{print $2}')
        fi

        s_502="$s_502 $c_502"
        s_503="$s_503 $c_503"
        s_504="$s_504 $c_504"

        # Get CPU data
        if [ -f "tmp/$1/$proxy.cpu" ]; then
            cpudata="$cpudata $(cat tmp/$1/$proxy.cpu |tr -d '\n')"
        else
            cpudata="$cpudata 0"
        fi
        
        reqdata="$reqdata $d"
    done

    # Generate graphs
    if [ -n "$(echo $reqdata | tr -d '-s ')" ]; then
        tools/chart.py -l -o graphs/$1/requests -c single -t 'Average requests per second' -y 'Req/sec' $reqdata >/dev/null 2>&1
    fi
    
    if [ -n "$(echo $cpudata | tr -d '-s ')" ]; then
        tools/chart.py -l -o graphs/$1/cpu -c single -t 'CPU User Level' -y 'Percent' $cpudata >/dev/null 2>&1
    fi
    
    if [ -n "$(echo $l_75 | tr -d '-bar1 ')" ]; then
        tools/chart.py -p -l -o graphs/$1/latency -c grouped -t 'Latency (percentiles)' -y Milliseconds $l_75 $l_95 $l_99 >/dev/null 2>&1
    fi
    
    if [ -n "$(echo $s_502 | tr -d '-bar1 ')" ]; then
        tools/chart.py -l -o graphs/$1/errors -c grouped -t 'HTTP Errors returned' -y Count -l $s_502 $s_503 $s_504 >/dev/null 2>&1
    fi
}

