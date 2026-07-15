set -aox pipefail

if [[ ! -x "scanner.bin" ]]; then
    odin build scanner -o:speed
fi

function protocol() {
    local EXTRA=-dont-emit-libwayland
    if [[ "${4}" = "true" ]]; then
        EXTRA=
    fi
    ./scanner.bin -input:$1 -output:$2 -package-name:$3 $EXTRA
}

rm -rf wp
mkdir wp

protocol ./scanner/protocols/presentation-time.xml ./wp/presentation-time.odin wp true
protocol ./scanner/protocols/linux-dmabuf-v1.xml ./wp/linux-dmabuf-v1.odin wp
protocol ./scanner/protocols/tablet-v2.xml ./wp/tablet-v2.odin wp
protocol ./scanner/protocols/viewporter.xml ./wp/viewporter.odin wp
protocol ./scanner/protocols/cursor-shape-v1.xml ./wp/cursor-shape-v1.odin wp

rm -rf xdg
mkdir xdg

protocol ./scanner/protocols/xdg-shell.xml ./xdg/shell.odin xdg true
protocol ./scanner/protocols/xdg-decoration-unstable-v1.xml ./xdg/decoration-unstable-v1.odin xdg

protocol ./scanner/protocols/wayland.xml ./wayland.odin wayland
