#!/bin/bash

TITLE="2Status"
STVER="0.1"
OUTDIR="out/"
OUTEMP="$(mktemp -d)"

if $(grep -q nh1 ~/.bashrc)
then
    eval "$(grep nh1 "$HOME/.bashrc")"
else
    if [ -d "nh1/" ]
    then
        source "nh1/nh1.sh"
    else
        echo "NH1 not found. You can get it with:"
        echo "  git clone https://codeberg.org/cordeis/nh1"
    fi
fi

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
            echo "$PA1" > $OUTEMP/out
            ;;
        TITLE)
            TITLE="$PA1"
            echo "$PA1" > $OUTEMP/tit
            ;;
        HOST)
            if $(1ison -q "$PA2")
            then
                STAT="v"
            else
                STAT="X"
            fi
            printf "%s|%s\n" "$PA1" "$STAT" >> $OUTEMP/hosts
            ;;
        WEB)
            if [ $(1httpstatus "$PA2") -eq $PA3 ]
            then
                STAT="v"
            else
                STAT="X"
            fi
            printf "%s|%s|%s\n" "$PA1" "$PA2" "$STAT" >> $OUTEMP/web
            ;;
        PORT)
            $(1ports "$PA2" $PA3 >& /dev/null)
            if [ $? -eq 0 ]
            then
                STAT="v"
            else
                STAT="X"
            fi
            printf "%s|%s\n" "$PA1" "$STAT" >> $OUTEMP/ports
            ;;
    esac
done

TITLE="$(cat "$OUTEMP/tit")"
cat template/head.txt | sed "s/\-=\[title\]=\-/$TITLE/g" > "$OUTDIR/index.html"

mkdir -p "$OUTDIR"

cat template/headsec.txt | sed "s/\-=\[title\]=\-/Hosts/g" >> "$OUTDIR/index.html"

cat "$OUTEMP/hosts" | while read host
do
    HT=$(echo "$host" | cut -d\| -f 1)
    if [ "$(echo "$host" | cut -d\| -f 2)" = "v" ]
    then
        HS="check_circle"
        HSC=""
        HTC=""
    else
        HS="error"
        HSC="red-text"
        HTC="red lighten-5"
    fi
    
    printf "<li class=\"collection-item %s\"><div>%s<b class=\"secondary-content\"><i class=\"material-icons %s\">%s</i></b></div></li>" "$HTC" "$HT" "$HSC" "$HS" >> "$OUTDIR/index.html"
done

cat template/footsec.txt >> "$OUTDIR/index.html"
cat template/headsec.txt | sed "s/\-=\[title\]=\-/Websites/g" >> "$OUTDIR/index.html"

cat "$OUTEMP/web" | while read webs
do
    HT=$(echo "$webs" | cut -d\| -f 1)
    HL=$(echo "$webs" | cut -d\| -f 2)
    if [ "$(echo "$webs" | cut -d\| -f 3)" = "v" ]
    then
        HS="check_circle"
        HSC=""
        HTC=""
    else
        HS="error"
        HSC="red-text"
        HTC="red lighten-5"
    fi
    
    printf "<li class=\"collection-item %s\"><div><a href=\"%s\">%s</a><b class=\"secondary-content\"><i class=\"material-icons %s\">%s</i></b></div></li>" "$HTC" "$HL" "$HT" "$HSC" "$HS" >> "$OUTDIR/index.html"

done

cat template/footsec.txt >> "$OUTDIR/index.html"
cat template/headsec.txt | sed "s/\-=\[title\]=\-/Websites/g" >> "$OUTDIR/index.html"

cat "$OUTEMP/ports" | while read iport
do
    HT=$(echo "$iport" | cut -d\| -f 1)
    if [ "$(echo "$iport" | cut -d\| -f 2)" = "v" ]
    then
        HS="check_circle"
        HSC=""
        HTC=""
    else
        HS="error"
        HSC="red-text"
        HTC="red lighten-5"
    fi
    
    printf "<li class=\"collection-item %s\"><div>%s<b class=\"secondary-content\"><i class=\"material-icons %s\">%s</i></b></div></li>" "$HTC" "$HT" "$HSC" "$HS" >> "$OUTDIR/index.html"

done

cat template/footsec.txt >> "$OUTDIR/index.html"

NOW="$(date "+%Y-%m-%d %H:%M") by 2status $STVER"

cat template/footer.txt | sed "s/\-=\[now\]=\-/$NOW/" >> "$OUTDIR/index.html"

IFS=$PIFS

rm -rf "$OUTEMP"
