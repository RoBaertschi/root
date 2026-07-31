set -aox pipefail

rm -rf wp xdg
rm -f protocol.odin

odin run scanner/v2 -- \
	-input:scanner/protocols \
	-config:scanner/config.json
