#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

TITLE="2Status"
STVER="0.6.1"
OUTDIR="out"
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
                echo "2states needs wget or curl to install nh1"
                exit 1
            fi
            tar -zxf nh1.tgz
            rm nh1.tgz
            source "nh1/nh1"
        else
            echo "You can get it with:"
            echo "  git clone https://codeberg.org/cordeis/nh1"
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
    mkdir -p "$OUTDIR"
    cat template/head.txt | sed "s/\-=\[title\]=\-/$TITLE/g" > "$OUTDIR/index.html"
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
    cat template/headsec.txt | sed "s/\-=\[title\]=\-/$NAM/g" >> "$OUTDIR/index.html"
    ENTRIES=0
}

# @description Close a section
_2status.section_end() {
    _2verb "section end"
    if [ $ENTRIES -eq 0 ]
    then
            printf "<li class=\"collection-item\"><div>No checking here.</div></li>\n" >> "$OUTDIR/index.html"
    fi
    cat template/footsec.txt >> "$OUTDIR/index.html"
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
    cat template/footer.txt | sed "s/\-=\[now\]=\-/$NOW/" >> "$OUTDIR/index.html"
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
    
    printf "<li class=\"collection-item %s\"><div>%s<b class=\"secondary-content\">%s<i class=\"material-icons %s\">%s</i></b></div></li>\n" "$HTC" "$HT" "$HSM" "$HSC" "$HS" >> "$OUTDIR/index.html"
    ENTRIES=$((ENTRIES +1))
}

PIFS=$IFS
IFS="\n"

if [ -f "2status.conf" ]
then
    
    while read line
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
        export ENTRIES
        export SECTIONS
    done <<< $(cat "2status.conf")
else
    TITLE="No 2status.conf found"
fi

_2status.end

IFS=$PIFS
