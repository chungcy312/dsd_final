dir="${1%/}"
base="${dir#Report_}"   # CHIP_6636cb2_2.3
cycle="${base##*_}"     # 2.3
base="${base%_*}"       # CHIP_6636cb2

area="${dir}/${base}_syn.area"
critical="${dir}/${base}_syn.critical_path"

cell_area=$(awk '/Total cell area:/ {print $NF}' "$area")
slack=$(awk '/slack/ {s=$NF} END {print s}' "$critical")

echo "Total cell area: $cell_area"
echo "slack: $slack"

if awk "BEGIN {exit !($slack >= 0)}"; then
  awk "BEGIN {printf \"area*cycle^3: %.6f\\n\", $cell_area * $cycle * $cycle * $cycle}"
else
  echo "area*cycle^3: NOT_MET"
fi
