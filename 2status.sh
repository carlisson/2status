#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

STDIR="$(pwd)"
TITLE="2Status"
TEMPLATE="mat"
STVER="$(tail -n 1 "CHANGELOG" | cut -d\  -f 1)"
OUTDIR="out"
LOGDIR="log"
VERBOSEMODE="N"
TEMPNEW=/tmp/.2status-tempnew #provisory, real path will be created in start
TEMPSEC=/tmp/.2status-tempsec
TEMPALE=/tmp/.2status-tempale # Alerts
NH1PACK="https://codeberg.org/attachments/0da5708e-3c0d-4f6c-a5b5-75aa8641e467" # 1.4.3
BUILDER="2Status $STVER"
BOT_TELEGRAM="" # telegram group
ATTEMPS=1 # when checking results in error, how many times to try again?

# Returns actual time in seconds since 1970
_now() {
    date +%s
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
        echo >&2
        echo "Title $TITLE" >&2
        echo "Template $TEMPLATE" >&2
        echo "Version $STVER" >&2
        echo "Output dir $OUTDIR" >&2
        echo "Sections $SECTIONS" >&2
        echo "Entries $ENTRIES" >&2
        echo ">>> $*" >&2
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
    TEMPALE="$(1temp file .alerts)"
    mkdir -p "$OUTDIR" "$LOGDIR"
    cp "misc/2status.ico" "$OUTDIR/favicon.ico"
#--    cat "templates/$TEMPLATE/head.txt" | sed "s/\-=\[title\]=\-/$TITLE/g" > "$TEMPNEW"
    cp -r templates/$TEMPLATE/* "$OUTDIR/"
    rm $OUTDIR/*.txt $OUTDIR/*.angel &> /dev/null
}

# @description Alert when test become up or down
# @arg $1 string Service name
# @arg $2 status 0: ok; 1: fail
# @arg $3 int Since (if fail)
_2status.alert() {
    local _MSG _NOW _SERV _STA _DOW
    _SERV=$(echo $1)
    shift
    _STA=$1
    shift
    _DOW="$*"
    _NOW="$(date "+%Y-%m-%d %H:%M")"
    if [ ! -z "$BOT_TELEGRAM" ]
    then
        _2verb "service $1, status $_STA, downtime $_DOW"
        if [ $_STA -eq 0 ]
        then
            if [ -f "$STDIR/templates/$TEMPLATE/bot-up.angel" ]
            then
                _MSG=$(1angel run $STDIR/templates/$TEMPLATE/bot-up.angel service="$_SERV" downtime="$_DOW")
            else
                _MSG="✅ $_SERV 👍 $_NOW ⏲️ $_DOW."
            fi
        else
            if [ -f "$STDIR/templates/$TEMPLATE/bot-down.angel" ]
            then
                _MSG="$(1angel run $STDIR/templates/$TEMPLATE/bot-down.angel service="$_SERV")"
            else
                _MSG="❌ $_SERV 👎 $_NOW."
            fi
        fi
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
    _2verb "1morph escape em $2 de $#"
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
            _AUX=$(1elapsed $_PREVIOUS)
            _1db.set  "$LOGDIR" "2st" "$_TESTID" "$_IDPREV"
            _1db.set  "$LOGDIR" "down" "$_TESTID" "$(date -d @$_PREVIOUS "+%Y-%m-%d_%H:%M")" $_AUX
            echo $_TESTID 0 $_AUX >> $TEMPALE
        fi
    else
        if [ $_PREVIOUS -eq 0 ]
        then
            _1db.set  "$LOGDIR" "2st" "$_TESTID" "$_IDPREV" $(_now)
            echo $_TESTID 1 >> $TEMPALE
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
#--    cat "templates/$TEMPLATE/headsec.txt" | sed "s/\-=\[title\]=\-/$NAM/g" >> "$TEMPNEW"
    ENTRIES=0
    echo "group=$1 entries=$TEMPSEC.$SECTIONS" >> "$TEMPSEC"
}

# @description Close a section
_2status.section_end() {
    _2verb "section end"
#--    if [ $ENTRIES -eq 0 ]
#--    then
#--            cat "templates/$TEMPLATE/sec-empty.txt" >> "$TEMPNEW"
#--    fi
#--    cat "templates/$TEMPLATE/footsec.txt" >> "$TEMPNEW"
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


    NOW="$(date "+%Y-%m-%d %H:%M") by 2status $STVER"
#--    cat "templates/$TEMPLATE/footer.txt" | sed "s/\-=\[now\]=\-/$NOW/" >> "$TEMPNEW"
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

    _2verb "Stat $STAT, Page $PAGE, Epage $EPAGE"
    DT="$(_2status.log_it "$STAT" "$PAGE")"
    if [ "$STAT" = "0" ]
    then
#--        cat "templates/$TEMPLATE/entry-on.txt" | sed "s/\-=\[page\]=\-/$PAGE/" | sed "s/\-=\[chart\]=\-/$EPAGE.svg/" >> "$TEMPNEW"
        echo "entrangel=entry-on.angel page=$PAGE chart=$EPAGE.svg" >> $TEMPSEC.$SECTIONS
    else
        DT="$(1elapsed $DT 0)"
#--        cat "templates/$TEMPLATE/entry-off.txt" | sed "s/\-=\[page\]=\-/$PAGE/" | sed "s/\-=\[chart\]=\-/$EPAGE.svg/" >> "$TEMPNEW"
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
    local I
    for I in $(seq $ATTEMPS)
    do
        if $(1ison -q "$PA2")
        then
            _2status.entry "$PA1" "$PA2" "0"
            return 0
        fi
    done
    _2status.entry "$PA1" "$PA2" "1"
    return 1
}

# @description Check if given service returns wanted HTTP status
# @arg $1 string Title
# @arg $2 string URL
# @arg $3 int Wanted HTTP status
_2status.check_web() {
    local I
    for I in $(seq $ATTEMPS)
    do
        if [ $(1httpstatus "$2") -eq $3 ]
        then
            _2status.entry "$1" "$2" "0"
            return 0
        fi
    done
    _2status.entry "$1" "$2" "1"
    return 1
}

# @description Check if given port is open
# @arg $1 string Title
# @arg $2 string IP address
# @arg $3 int Port number
_2status.check_port() {
    local I
    for I in $(seq $ATTEMPS)
    do
        $(1ports "$2" $3 >& /dev/null)
        if [ $? -eq 0 ]
        then
            _2status.entry "$1" "$2" "0"
            return 0
        fi
    done
    _2status.entry "$1" "$2" "1"
    return 1
}

# @description Check exit code for given command
# @arg $1 string Title
# @arg $1 string Shell command
_2status.check_command() {
    local I
    for I in $(seq $ATTEMPS)
    do
        eval "$2"
        if [ $? -eq 0 ]
        then
            _2status.entry "$1" "$2" "0"
            return 0
        fi
    done
    _2status.entry "$1" "$2" "1"
    return 1
}

SCONF="2status.conf"
if [ $# -gt 0 ]
then
    case $1 in
        update)
            git pull
            1update
            exit 0
            ;;
        version)
            1banner "2status $STVER"
            1version
            exit 0
            ;;
        help)
            echo "Options:"
            echo "  update     Updates 2status and nh1"
            echo "  version    Show 2status and nh1 versions"
            echo "  help       Show this help"
            echo "  (arq.conf) Loads this file and not 2status.conf"
            exit 0
            ;;
        *.conf)
            SCONF="$1"
            ;;
    esac
fi

if [ -f "$SCONF" ]
then
    
    for lnum in $(seq $(1line "$SCONF"))
    do
        line=$(1line "$SCONF" $lnum)

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
            ATTEMPTS)
                ATTEMPS="$PA1"
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
            COM)
                _2status.check_command "$PA1" "$PA2"
                ;;
            1HOSTGROUP)
                if [ -f "$_1NETLOCAL/$PA2.hosts" ]
                then
                    _2status.section "$PA1"
                    
                    for COUNT in $(seq $(1line "$_1NETLOCAL/$PA2.hosts"))
                    do
                        HLIN=$(1line "$_1NETLOCAL/$PA2.hosts" $COUNT)
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

                    for COUNT in $(seq $(1line "$_1NETLOCAL/$PA2.hosts"))
                    do
                        HLIN=$(1line "$_1NETLOCAL/$PA2.hosts" $COUNT)
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
    done
else
    _1message error "No $SCONF found"
    exit 1
fi

_2status.end

cat "$TEMPNEW" > "$OUTDIR/previous.html"
rm "$TEMPNEW"

if [ -f "templates/$TEMPLATE/main.angel" ]
then
    _1ANGELBUILDER="$BUILDER"
    pushd "templates/$TEMPLATE" >& /dev/null
    _2verb "1angel main.angel run title=\"$TITLE\" sections=\"$TEMPSEC\" > $OUTDIR/angel.html"
        #1banner 1
        #cat $TEMPSEC.1
        #1banner 2
        #cat $TEMPSEC.2
        #1banner MAIN
        #cat $TEMPSEC
    1angel run main.angel title="$TITLE" sections="$TEMPSEC" > $OUTDIR/angel.html
    popd >& /dev/null
    mv "$OUTDIR/angel.html" $OUTDIR/index.html
#--else
#--    cp "$OUTDIR/previous.html" "$OUTDIR/index.html"
fi

rm "$TEMPSEC"*

TOTAL=$(wc -l < $TEMPALE)
for I in $(seq $TOTAL)
do
    LINE="$(sed -n "${I}p" $TEMPALE)"
    _2status.alert $LINE
    sleep 2
done

rm $TEMPALE
