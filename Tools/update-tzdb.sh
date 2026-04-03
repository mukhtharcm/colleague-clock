#!/bin/zsh

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <tzdb-version>" >&2
    exit 1
fi

version="$1"
script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
source_root="$project_root/Tools/tzdb-src"
working_dir="$source_root/$version"
archive_path="$source_root/tzdata${version}.tar.gz"
resource_dir="$project_root/Sources/TimeZoneMenuBar/Resources/TZDB"

mkdir -p "$source_root"

curl -L "https://www.iana.org/time-zones/repository/releases/tzdata${version}.tar.gz" -o "$archive_path"

rm -rf "$working_dir"
mkdir -p "$working_dir"
tar -xzf "$archive_path" -C "$working_dir"

rm -rf "$resource_dir/zoneinfo"
mkdir -p "$resource_dir/zoneinfo"

(
    cd "$working_dir"
    zic -b slim -d "$resource_dir/zoneinfo" africa antarctica asia australasia europe northamerica southamerica etcetera backward
)

cp "$working_dir/zone1970.tab" "$resource_dir/zone1970.tab"
cp "$working_dir/zone.tab" "$resource_dir/zone.tab"
cp "$working_dir/iso3166.tab" "$resource_dir/iso3166.tab"
cp "$working_dir/backward" "$resource_dir/backward"
cp "$working_dir/version" "$resource_dir/version.txt"

echo "Bundled TZDB updated to $version"
