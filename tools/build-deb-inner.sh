#!/bin/sh
# Runs INSIDE the target-suite container; driven by tools/build-deb.sh.
set -eu
: "${SUITE:?SUITE not set}"

got=$(. /etc/os-release && echo "$VERSION_CODENAME")
if [ "$got" != "$SUITE" ]; then
    echo "container is $got, wanted $SUITE" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
    debhelper fakeroot r-base-dev libjansson-dev lintian > /dev/null

cp -r /src /build
cd /build
# never let host build artifacts leak into the container build
rm -rf .git dist src/*.o src/*.so src/Makevars

cur=$(cd pkg && dpkg-parsechangelog -S Version)
new="${cur}~${SUITE}"
{
    printf 'janssonr (%s) unstable; urgency=medium\n\n  * Build for %s.\n\n' \
        "$new" "$SUITE"
    printf -- ' -- cornball.ai <troy@cornball.ai>  %s\n\n' "$(date -uR)"
    cat pkg/debian/changelog
} > pkg/debian/changelog.new
mv pkg/debian/changelog.new pkg/debian/changelog
echo "building $new for $SUITE/$(dpkg --print-architecture)"

(cd pkg && dpkg-buildpackage -rfakeroot -us -uc -b -tc)

echo "--- lintian ---"
lintian --fail-on error --info r-cornball-janssonr_*.deb

echo "--- control ---"
dpkg-deb -f r-cornball-janssonr_*.deb \
    Package Version Architecture Depends
echo "--- contents (head) ---"
dpkg -c r-cornball-janssonr_*.deb | awk 'NR <= 15'

cp r-cornball-janssonr_*.deb /out/
[ -n "${HOSTUID:-}" ] && chown "$HOSTUID:${HOSTGID:-$HOSTUID}" /out/*.deb
echo "built: $(cd /out && ls r-cornball-janssonr_*.deb)"
