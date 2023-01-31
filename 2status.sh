#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

TITLE="2Status"
STVER="0.3"
OUTDIR="out"

if $(grep -q nh1 ~/.bashrc)
then
    eval "$(grep nh1 "$HOME/.bashrc")"
else
    if [ -d "nh1/" ]
    then
        source "nh1/nh1"
    else
        echo "NH1 not found. You can get it with:"
        echo "  git clone https://codeberg.org/cordeis/nh1"
    fi
fi

SECTIONS="N"
# @description Start printing HTML page
_2status.start() {
    SECTIONS="Y"
    mkdir -p "$OUTDIR"
    cat template/head.txt | sed "s/\-=\[title\]=\-/$TITLE/g" > "$OUTDIR/index.html"
}

# @description Start section
# @arg $1 string Section title
_2status.section() {
    NAM="$*"
    if [ $SECTIONS = 'N' ]
    then
        _2status.start
        SECTIONS=1
    fi
    if [ $SECTIONS = 'Y' ]
    then
        SECTIONS=1
    else
        cat template/footsec.txt >> "$OUTDIR/index.html"
        SECTIONS=$((SECTIONS+1))
    fi
    cat template/headsec.txt | sed "s/\-=\[title\]=\-/$NAM/g" >> "$OUTDIR/index.html"
}

# @description Close page
_2status.end() {
    if [ $SECTIONS != 'N' ]
    then
        cat template/footsec.txt >> "$OUTDIR/index.html"
    fi
    cp "misc/2status.ico" "$OUTDIR/favicon.ico"
    NOW="$(date "+%Y-%m-%d %H:%M") by 2status $STVER"
    cat template/footer.txt | sed "s/\-=\[now\]=\-/$NOW/" >> "$OUTDIR/index.html"
}

# @description Prints a line
# @arg $1 string Title
# @arg $2 string URL or IP
# @arg $3 int Status. 0 is ok, 1 is fail
_2status.entry() {
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
        HSC=""
        HTC=""
        HSM="On"
    else
        HS="error"
        HSC="red-text"
        HTC="red lighten-5"
        HSM="Off"
    fi
    
    printf "<li class=\"collection-item %s\"><div>%s<b class=\"secondary-content\">%s<i class=\"material-icons %s\">%s</i></b></div></li>" "$HTC" "$HT" "$HSM" "$HSC" "$HS" >> "$OUTDIR/index.html"
}

PIFS=$IFS
IFS="\n"

cat "2status.conf" | while read line
do
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
            if $(1ison -q "$PA2")
            then
                STAT="0"
            else
                STAT="1"
            fi
            _2status.entry "$PA1" "$PA2" "$STAT"
            ;;
        WEB)
            if [ $(1httpstatus "$PA2") -eq $PA3 ]
            then
                STAT="0"
            else
                STAT="1"
            fi
            _2status.entry "$PA1" "$PA2" "$STAT"
            ;;
        PORT)
            $(1ports "$PA2" $PA3 >& /dev/null)
            if [ $? -eq 0 ]
            then
                STAT="0"
            else
                STAT="1"
            fi
            _2status.entry "$PA1" "$PA2" "$STAT"
            ;;
    esac
done

_2status.end

IFS=$PIFS
