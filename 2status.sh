#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

TITLE="2Status"
TEMPLATE="mat"
STVER="$(tail -n 1 "CHANGELOG" | cut -d\  -f 1)"
OUTDIR="out"
LOGDIR="log"
VERBOSEMODE="N"
TEMPNEW=/tmp/.2status-tempnew #provisory, real path will be created in start
TEMPSEC=/tmp/.2status-tempsec
NH1PACK="https://codeberg.org/attachments/7416b0f6-5daa-4b53-9283-b5d6f5fc419b" # 1.4.2
BUILDER="2Status $STVER"
BOT_TELEGRAM="" # telegram group

# Returns actal time in seconds since 1970
_now() {
    date +%s
}

# Returns seconds diff in human legible
# @arg 1 int Difference in seconds
# @arg 2 int abbreviat? 0: yes; 1: no (default)
_datediff() {
    local _AUX _ABR _SEC _MIN _HOU _DAY _WEE _YEA
    _AUX=$1
    if [ $((_AUX)) -le 0 ]
    then
        return 1
    fi
    _AUX=$(( $(_now) - _AUX ))
    if [ $((_AUX)) -le 0 ]
    then
        return 2
    fi
    case $# in
        1)
            _ABR=1
            ;;
        2)
            _ABR=$2
            if [ $((_ABR)) -lt 0 -o $((_ABR)) -gt 1 ]
            then
                return 3
            fi
            ;;
        *)
            return 4
    esac
    if [ $_AUX -gt 220752000 ] # 1 year
    then
        if [ $_ABR -eq 0 ]
        then
            _1text "+1y"
            return 0
        else
            if [ $_AUX -ge 441504000 ]
            then
                printf "$(_1text "%s years") " $((_AUX / 220752000))
            else
                printf "$(_1text "%s year") " $((_AUX / 220752000))
            fi
            _AUX=$((_AUX % 220752000))
        fi
    fi
    if [ $_AUX -gt 604800 ] # 1 week
    then
        if [ $_ABR -eq 0 ]
        then
            printf "$(_1text "%sw")" $((_AUX / 604800))
            return 0
        else
            if [ $_AUX -ge 1209600 ]
            then
                printf "$(_1text "%s weeks") " $((_AUX / 604800))
            else
                printf "$(_1text "%s week") " $((_AUX / 604800))
            fi
            _AUX=$((_AUX % 604800))
        fi
    fi
    if [ $_AUX -gt 86400 ] # 1 day
    then
        if [ $_ABR -eq 0 ]
        then
            printf "$(_1text "%sd")" $((_AUX / 86400))
            return 0
        else
            if [ $_AUX -ge 172800 ]
            then
                printf "$(_1text "%s days") " $((_AUX / 86400))
            else
                printf "$(_1text "%s day") " $((_AUX / 86400))
            fi
            _AUX=$((_AUX % 86400))
        fi
    fi
    if [ $_AUX -gt 3600 ] # 1 hour
    then
        if [ $_ABR -eq 0 ]
        then
            printf "$(_1text "%sh")" $((_AUX / 3600))
            return 0
        else
            if [ $_AUX -ge 7200 ]
            then
                printf "$(_1text "%s hours") " $((_AUX / 3600))
            else
                printf "$(_1text "%s hour") " $((_AUX / 3600))
            fi
            _AUX=$((_AUX % 3600))
        fi
    fi
    if [ $_AUX -gt 60 ] # 1 min
    then
        if [ $_ABR -eq 0 ]
        then
            printf "$(_1text "%smin")" $((_AUX / 60))
            return 0
        else
            if [ $_AUX -ge 120 ]
            then
                printf "$(_1text "%s minutes") " $((_AUX / 60))
            else
                printf "$(_1text "%s minute") " $((_AUX / 60))
            fi
            _AUX=$((_AUX % 60))
        fi
    fi
    if [ $_AUX -gt 0 ] # 1 min
    then
        if [ $_ABR -eq 0 ]
        then
            printf "$(_1text "%ss")" $_AUX
            return 0
        else
            if [ $_AUX -gt 1 ]
            then
                printf "$(_1text "%s seconds") " $_AUX
            else
                printf "$(_1text "%s second") " $_AUX
            fi
        fi
    fi
    return 0
}

yes_or_no() {
    while true; do
        read -p "$* [y/n]: " yn
        case $yn in
            [Yy]*) return 0  ;;  
            [Nn]*) return  1 ;;
        esac
    done
}

# @description Prints if in verbose mode
# @arg $1 string Text to print
_2verb() {
    if [ "$VERBOSEMODE" = "Y" ]
    then
        echo
        echo "Title $TITLE"
        echo "Template $TEMPLATE"
        echo "Version $STVER"
        echo "Output dir $OUTDIR"
        echo "Sections $SECTIONS"
        echo "Entries $ENTRIES"
        echo ">>> $*"        
    fi
}
if $(grep -q nh1 ~/.bashrc)
then
    eval "$(grep nh1 "$HOME/.bashrc")"
else
    if [ -d "nh1/" ]
    then
        source "nh1/nh1"
    else
        if yes_or_no "NH1 not found. Do you want to download it now?"
        then
            # NH1 v1.4
            if [ -f /usr/bin/wget ]
            then
                wget "$NH1PACK" -O nh1.tgz
            elif [ -f /usr/bin/curl ]
            then
                curl -o nh1.tgz -OL "$NH1PACK"
            else
                echo "2status needs wget or curl to install nh1"
                exit 1
            fi
            tar -zxf nh1.tgz
            rm nh1.tgz
            source "nh1/nh1"
        else
            echo "You can get it with:"
            echo "  git clone https://codeberg.org/bardo/nh1"
            exit 0
        fi
    fi
fi

SECTIONS="N"
ENTRIES=0

# @description Start printing HTML page
_2status.start() {
    _2verb "start"
    SECTIONS="Y"
    TEMPNEW="$(1temp name .html)"
    TEMPSEC="$(1temp name .vars)"
    mkdir -p "$OUTDIR" "$LOGDIR"
    cat "templates/$TEMPLATE/head.txt" | sed "s/\-=\[title\]=\-/$TITLE/g" > "$TEMPNEW"
    cp -r templates/$TEMPLATE/* "$OUTDIR/"
    rm $OUTDIR/*.txt $OUTDIR/*.angel &> /dev/null
}

# @description Alert when test become up or down
# @arg $1 string Service name
# @arg $2 status 0: ok; 1: fail
# @arg $3 int Since (if fail)
_2status.alert() {
    local _MSG _NOW
    _NOW="$(date "+%Y-%m-%d %H:%M")"
    if [ ! -z "$BOT_TELEGRAM" ]
    then
        _2verb "service $1, status $2, downtime $3"
        if [ $2 -eq 0 ]
        then
            _MSG="✅ Service $1 is up $_NOW after $3."
        else    
            _MSG="⚠️ Service $1 is down $_NOW."
        fi
        echo "$_MSG" >&2
        1bot telegram say "$BOT_TELEGRAM" "$_MSG"
    fi
}

# @description Save into 1db
# @arg $1 string Status for test (0: ok; 1: fail)
# @arg $2 string Host Title
# @stdout string Downtime
_2status.log_it() {
    local _TESTID _STATUS _IDTOTAL _IDON _AUX _PREVIOUS
    _STATUS=$1
    shift
    _TESTID="$(1morph escape "$*")"
    if [ ! -f "$LOGDIR/$_TESTID.2st" ]
    then
        _1db "$LOGDIR" "2st" new "$_TESTID"
    fi
    if [ ! -f "$LOGDIR/$_TESTID.down" ]
    then
        _1db "$LOGDIR" "down" new "$_TESTID"
    fi
    _IDTOTAL="S$(date "+%Y-%m-%d")"

    _IDPREV=$(grep "_down="  "$LOGDIR/$_TESTID.2st" |tail -n 1 | sed 's/\(.*\)=\(.*\)/\1/')
    if [ -z "$_IDTOTAL" ]
    then
        _IDPREV="$_IDTOTAL""_down"
    fi
    _IDON="$_IDTOTAL""_on"
    _AUX=$(( $(_1db.get "$LOGDIR" "2st" "$_TESTID" "$_IDTOTAL") + 1 ))
    _PREVIOUS=$(("$(_1db.get "$LOGDIR" "2st" "$_TESTID" "$_IDPREV")"))

    _1db.set  "$LOGDIR" "2st" "$_TESTID" "$_IDTOTAL" $_AUX
    if [ "$_STATUS" = "0" ]
    then
        _AUX=$(( $(_1db.get "$LOGDIR" "2st" "$_TESTID" "$_IDON") + 1 ))
        _1db.set  "$LOGDIR" "2st" "$_TESTID" "$_IDON" $_AUX
        if [ $_PREVIOUS -gt 0 ]
        then
            _AUX=$(_datediff $_PREVIOUS)
            _1db.set  "$LOGDIR" "2st" "$_TESTID" "$_IDPREV"
            _1db.set  "$LOGDIR" "down" "$_TESTID" "$(date -d @$_PREVIOUS "+%Y-%m-%d_%H:%M")" $_AUX
            _2status.alert "$_TESTID" 0 $_AUX
        fi
    else
        if [ $_PREVIOUS -eq 0 ]
        then
            _1db.set  "$LOGDIR" "2st" "$_TESTID" "$_IDPREV" $(_now)
            _2status.alert "$_TESTID" 1
        else
            echo "$_PREVIOUS"
            return 0
        fi
    fi
    echo "0"
    return 0
}

# @description Start section
# @arg $1 string Section title
_2status.section() {
    _2verb "section $1"
    NAM="$*"
    if [ $SECTIONS = 'N' ]
    then
        _2status.start
        SECTIONS='Y'
    fi
    if [ $SECTIONS = 'Y' ]
    then
        SECTIONS=1
    else
        _2status.section_end
    fi
    cat "templates/$TEMPLATE/headsec.txt" | sed "s/\-=\[title\]=\-/$NAM/g" >> "$TEMPNEW"
    ENTRIES=0
    echo "group=$1 entries=$TEMPSEC.$SECTIONS" >> "$TEMPSEC"
}

# @description Close a section
_2status.section_end() {
    _2verb "section end"
    if [ $ENTRIES -eq 0 ]
    then
            cat "templates/$TEMPLATE/sec-empty.txt" >> "$TEMPNEW"
    fi
    cat "templates/$TEMPLATE/footsec.txt" >> "$TEMPNEW"
    SECTIONS=$((SECTIONS+1))
}

# @description Close page
_2status.end() {
    _2verb "end"
    if [ "$SECTIONS" = "N" ]
    then
        echo "Acionado END. $SECTIONS"
        _2status.section Status
    fi
    _2status.section_end


    cp "misc/2status.ico" "$OUTDIR/favicon.ico"
    NOW="$(date "+%Y-%m-%d %H:%M") by 2status $STVER"
    cat "templates/$TEMPLATE/footer.txt" | sed "s/\-=\[now\]=\-/$NOW/" >> "$TEMPNEW"
}

# @description Prints a line
# @arg $1 string Title
# @arg $2 string URL or IP
# @arg $3 int Status. 0 is ok, 1 is fail
_2status.entry() {
    local PAGE TARG STAT EPAGE DT
    _2verb "entry $1 $2 $3"
    PAGE="$1"
    TARG="$2"
    STAT="$3"
    EPAGE="$(1morph escape "$PAGE")"
    
    case $SECTIONS in
        N|Y)
            _2status.section "Status"
            ;;
    esac

    if [[ "$TARG" =~ 'http' ]]
    then
        HT="<a href='$TARG'>$PAGE</a>"
    else
        HT="$PAGE"
    fi

    DT="$(_2status.log_it "$STAT" "$PAGE")"
    if [ "$STAT" = "0" ]
    then
        cat "templates/$TEMPLATE/entry-on.txt" | sed "s/\-=\[page\]=\-/$PAGE/" | sed "s/\-=\[chart\]=\-/$EPAGE.svg/" >> "$TEMPNEW"
        echo "entrangel=entry-on.angel page=$PAGE chart=$EPAGE.svg" >> $TEMPSEC.$SECTIONS
    else
        DT="$(_datediff $DT 0)"
        cat "templates/$TEMPLATE/entry-off.txt" | sed "s/\-=\[page\]=\-/$PAGE/" | sed "s/\-=\[chart\]=\-/$EPAGE.svg/" >> "$TEMPNEW"
        echo "entrangel=entry-off.angel page=$PAGE chart=$EPAGE.svg downtime=$DT" >> $TEMPSEC.$SECTIONS
    fi
    
    ENTRIES=$((ENTRIES +1))
    _2status.make_chart "$EPAGE"
}

# @description Make a chart
# @description Checking ID
_2status.make_chart() {
    local SINGLE XPOS YPOS COUNT DELTA PERC POINTS DATE
    local FILE="$OUTDIR/$1.svg"
    local LOGF="$LOGDIR/$1.2st"
    local TXTS="$(mktemp)"
    local TOTAL=$(grep _on= "$LOGF" | wc -l)
    if [ $TOTAL -gt 30 ]
    then
        TOTAL=30
    elif [ $TOTAL -lt 2 ]
    then
        cat "templates/$TEMPLATE/chart-head.txt" \
            "templates/$TEMPLATE/chart-nodata.txt" \
            "templates/$TEMPLATE/chart-foot.txt" > "$FILE"
        return 1
    fi
    COUNT=1
    POINTS=""
    # (240 - 15) % TOTAL
    DELTA=$((225/($TOTAL-1)))
    for SINGLE in $(grep -v _on= "$LOGDIR/$1.2st" | grep -v _down= | cut -d= -f 1 | tail -n $TOTAL | tac)
    do
        if [ $COUNT -eq $TOTAL ]
        then
            XPOS=15
        else
            XPOS=$((15 + ($TOTAL - $COUNT) * $DELTA ))
        fi
        PERC=$(( (100 * $(( $(_1db.get "$LOGDIR" "2st" "$1" "$SINGLE"_on) )) ) / $(_1db.get "$LOGDIR" "2st" "$1" "$SINGLE") ))
        YPOS=$((110 - $PERC))
        DATE=$(echo $SINGLE | sed 's/^S//')
        POINTS="$POINTS $XPOS,$YPOS"
        cat "templates/$TEMPLATE/chart-date.txt" | \
        sed "s/\-=\[pos\]=\-/$((XPOS+6))/g" |
        sed "s/\-=\[textid\]=\-/date$COUNT/g" | \
        sed "s/\-=\[date\]=\-/$DATE/g" >> "$TXTS"
        ((COUNT++))        
    done
    cat "templates/$TEMPLATE/chart-head.txt" | sed "s/\-=\[points\]=\-/$POINTS/" > "$FILE"
    cat $TXTS >> $FILE
    cat "templates/$TEMPLATE/chart-foot.txt" >> "$FILE"
    rm $TXTS
}

# @description Check if given host respond to ping
# @arg $1 string Title
# @arg $2 string IP address
_2status.check_host() {
    local PA1="$1"
    local PA2="$2"
    local STAT
    if $(1ison -q "$PA2")
    then
        STAT="0"
    else
        STAT="1"
    fi
    _2status.entry "$PA1" "$PA2" "$STAT"
}

# @description Check if given service returns wanted HTTP status
# @arg $1 string Title
# @arg $2 string URL
# @arg $3 int Wanted HTTP status
_2status.check_web() {
    local STAT
    if [ $(1httpstatus "$2") -eq $3 ]
    then
        STAT="0"
    else
        STAT="1"
    fi
    _2status.entry "$1" "$2" "$STAT"
}

# @description Check if given port is open
# @arg $1 string Title
# @arg $2 string IP address
# @arg $3 int Port number
_2status.check_port() {
    $(1ports "$2" $3 >& /dev/null)
    if [ $? -eq 0 ]
    then
        STAT="0"
    else
        STAT="1"
    fi
    _2status.entry "$1" "$2" "$STAT"
}

PIFS=$IFS
IFS=$'\n'

if [ -f "2status.conf" ]
then
    
    while read line
    do
        line=$(echo $line | tr '^' 'n')
        COM="$(echo "$line" | cut -d\| -f 1)"
        PA1="$(echo "$line" | cut -d\| -f 2)"
        PA2="$(echo "$line" | cut -d\| -f 3)"
        PA3="$(echo "$line" | cut -d\| -f 4)"
        case "$COM" in
            OUTDIR)
                OUTDIR="$(realpath "$PA1")"
                ;;
            TITLE)
                TITLE="$PA1"
                ;;
            TEMPLATE)
                TEMPLATE="$PA1"
                ;;
            BOT)
                if [ "$PA1" = "telegram" ]
                then
                    BOT_TELEGRAM="$PA2"
                fi
                ;;
            HEAD)
                _2status.section "$PA1"
                ;;
            HOST)
                _2status.check_host "$PA1" "$PA2"
                ;;
            WEB)
                _2status.check_web "$PA1" "$PA2" "$PA3"
                ;;
            PORT)
                _2status.check_port "$PA1" "$PA2" "$PA3"
                ;;
            1HOSTGROUP)
                if [ -f "$_1NETLOCAL/$PA2.hosts" ]
                then
                    _2status.section "$PA1"
                    TOTAL=$(cat "$_1NETLOCAL/$PA2.hosts" | wc -l)
                    COUNT=0
                    while [ $COUNT -lt $TOTAL ]
                    do
                        COUNT=$((COUNT+1))
                        HLIN=$(sed -n "$COUNT"p < "$_1NETLOCAL/$PA2.hosts")
                        HNAM=$(echo $HLIN | sed 's/\(.*\)=\(.*\)/\1/')
                        MYIP=$(echo $HLIN | cut -f 2 -d "=" | cut -f 1 -d " ")
                        if [ $? -eq 0 ]
                        then
                            _2status.check_host $HNAM $MYIP
                        else
                            _2status.entry "$HNAM" "?" "1"
                        fi
                    done
                fi
                ;;
            1HGPORT)
                if [ -f "$_1NETLOCAL/$PA2.hosts" ]
                then
                    _2status.section "$PA1"
                    TOTAL=$(cat "$_1NETLOCAL/$PA2.hosts" | wc -l)
                    COUNT=0
                    while [ $COUNT -lt $TOTAL ]
                    do
                        COUNT=$((COUNT+1))
                        HLIN=$(sed -n "$COUNT"p < "$_1NETLOCAL/$PA2.hosts")
                        HNAM=$(echo $HLIN | sed 's/\(.*\)=\(.*\)/\1/')
                        MYIP=$(echo $HLIN | cut -f 2 -d "=" | cut -f 1 -d " ")
                        if [ $? -eq 0 ]
                        then
                            _2status.check_port $HNAM $MYIP $PA3
                        else
                            _2status.entry "$HNAM" "?" "1"
                        fi
                    done
                fi
                ;;
        esac
        export ENTRIES
        export SECTIONS
    done <<< $(cat "2status.conf" | tr 'n' '^')
else
    TITLE="No 2status.conf found"
fi

_2status.end

cat "$TEMPNEW" > "$OUTDIR/previous.html"
rm "$TEMPNEW"

IFS=$PIFS

if [ -f "templates/$TEMPLATE/main.angel" ]
then
    _1ANGELBUILDER="$BUILDER"
    pushd "templates/$TEMPLATE" >& /dev/null
    _2verb "1angel main.angel run title=\"$TITLE\" sections=\"$TEMPSEC\" > $OUTDIR/index.html"
    1angel run main.angel title="$TITLE" sections="$TEMPSEC" > $OUTDIR/angel.html
    popd >& /dev/null
    mv "$OUTDIR/angel.html" $OUTDIR/index.html
else
    cp "$OUTDIR/previous.html" "$OUTDIR/index.html"
fi

rm "$TEMPSEC"*
