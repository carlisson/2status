#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

TITLE="2Status"
TEMPLATE="mat"
STVER="0.6b8"
OUTDIR="out"
LOGDIR="log"
VERBOSEMODE="N"

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
            REMURL="https://codeberg.org/attachments/e28fd258-d328-411a-bc46-3e8bfa377d8b"
            if [ -f /usr/bin/wget ]
            then
                wget "$REMURL" -O nh1.tgz
            elif [ -f /usr/bin/curl ]
            then
                curl -o nh1.tgz -OL "$REMURL"
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
    mkdir -p "$OUTDIR" "$LOGDIR"
    cat "templates/$TEMPLATE/head.txt" | sed "s/\-=\[title\]=\-/$TITLE/g" > "$OUTDIR/index.html"
    cp -r templates/$TEMPLATE/* "$OUTDIR/"
    rm $OUTDIR/*.txt
}

# @description Save into 1db
# @arg $1 string Status for test (0: ok; 1: fail)
# @arg $2 string Host Title
_2status.log_it() {
    local _TESTID _STATUS _IDTOTAL _IDON _AUX
    _STATUS=$1
    shift
    _TESTID="$(1morph escape "$*")"
    if [ ! -f "$LOGDIR/$_TESTID.2st" ]
    then
        _1db "$LOGDIR" "2st" new "$_TESTID"
    fi
    _IDTOTAL="S$(date "+%Y-%m-%d")"
    _IDON="$_IDTOTAL""_on"
    _AUX=$(( $(_1db.get "$LOGDIR" "2st" "$_TESTID" "$_IDTOTAL") + 1 ))
    _1db.set  "$LOGDIR" "2st" "$_TESTID" "$_IDTOTAL" $_AUX
    if [ "$_STATUS" = "0" ]
    then
        _AUX=$(( $(_1db.get "$LOGDIR" "2st" "$_TESTID" "$_IDON") + 1 ))
        _1db.set  "$LOGDIR" "2st" "$_TESTID" "$_IDON" $_AUX
    fi
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
    cat "templates/$TEMPLATE/headsec.txt" | sed "s/\-=\[title\]=\-/$NAM/g" >> "$OUTDIR/index.html"
    ENTRIES=0
}

# @description Close a section
_2status.section_end() {
    _2verb "section end"
    if [ $ENTRIES -eq 0 ]
    then
            printf "<li class=\"collection-item\"><div>No checking here.</div></li>\n" >> "$OUTDIR/index.html"
    fi
    cat "templates/$TEMPLATE/footsec.txt" >> "$OUTDIR/index.html"
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
    cat "templates/$TEMPLATE/footer.txt" | sed "s/\-=\[now\]=\-/$NOW/" >> "$OUTDIR/index.html"
}

# @description Prints a line
# @arg $1 string Title
# @arg $2 string URL or IP
# @arg $3 int Status. 0 is ok, 1 is fail
_2status.entry() {
    _2verb "entry $1 $2 $3"
    PAGE="$1"
    TARG="$2"
    STAT="$3"
    
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

    if [ "$STAT" = "0" ]
    then
        HS="check_circle"
        HSC="teal-text"
        HTC=""
        HSM=""
    else
        HS="error"
        HSC="red-text"
        HTC="red lighten-5"
        HSM=""
    fi
    
    printf "<li class=\"collection-item\"><div class=\"collapsible-header %s\"><b class=\"secondary-content\">%s<i class=\"material-icons %s\">%s</i></b>%s</div>\n" "$HTC" "$HSM" "$HSC" "$HS" "$HT" >> "$OUTDIR/index.html"
    echo "<div class=\"collapsible-body\"><img src=\"$PAGE.svg\" width=\"100%\"></div></li>" >> "$OUTDIR/index.html"
    ENTRIES=$((ENTRIES +1))
    _2status.log_it "$STAT" "$PAGE"
    _2status.make_chart "$PAGE"
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
    for SINGLE in $(grep -v _on= "$LOGDIR/$1.2st" | cut -d= -f 1 | tail -n $TOTAL)
    do
        if [ $COUNT -eq $TOTAL ]
        then
            XPOS=15
        else
            XPOS=$((15 + ($TOTAL - $COUNT) * $DELTA ))
        fi
        PERC=$(( (100 * $(_1db.get "$LOGDIR" "2st" "$1" "$SINGLE"_on)) / $(_1db.get "$LOGDIR" "2st" "$1" "$SINGLE") ))
        YPOS=$((110 - $PERC))
        DATE=$(echo $SINGLE | sed 's/^S//')
        POINTS="$POINTS $XPOS,$YPOS"
        cat "templates/$TEMPLATE/chart-date.txt" | \
        sed "s/\-=\[pos\]=\-/$((XPOS+3))/g" |
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
    local PA1=$1
    local PA2=$2
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
                OUTDIR="$PA1"
                ;;
            TITLE)
                TITLE="$PA1"
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
                _2status.check_port 
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

IFS=$PIFS
_2status.log_it on Teste geral