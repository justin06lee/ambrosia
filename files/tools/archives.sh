#!/bin/sh
# Makes the archives Archive Utility is tried on (files/src/expand.cpp) in
# ~/Archives, on the test machine, as its user: one item, several, a
# tarball, a lone gzip, a Mac's zip, 7z, one with a password ("secret"), a
# file that only says it is a zip, one whose entry climbs out with "..",
# one that writes through a link to /tmp, and 900 MB to see the progress
# window. Afterwards ~/evil.txt and /tmp/pwned.txt must not exist.
set -e
d=$HOME/Archives
rm -rf "$d" /tmp/pwned.txt "$HOME/evil.txt"
mkdir -p "$d/src" && cd "$d/src"
printf 'hello\n' > notes.txt
mkdir -p site/css Photos __MACOSX/Photos
printf '<h1>hi</h1>\n' > site/index.html; printf 'body{}\n' > site/css/main.css; chmod 755 site; 
printf 'a\n' > a.txt; printf 'b\n' > b.txt; printf 'x\n' > Photos/one.txt; printf 'r\n' > __MACOSX/Photos/._one.txt
bsdtar -a -cf ../one.zip notes.txt
bsdtar -a -cf ../many.zip a.txt b.txt site
bsdtar -a -cf ../site.tar.gz site
gzip -c notes.txt > ../notes.txt.gz
bsdtar -a -cf ../mac.zip Photos __MACOSX
bsdtar -a -cf ../pack.7z a.txt b.txt
bsdtar -a -cf ../locked.zip --options zip:encryption=zipcrypt --passphrase secret notes.txt
printf 'this is not a zip\n' > ../fake.zip
python3 - <<'PY'
import os, zipfile, tarfile, io
d = os.path.expanduser('~/Archives')
with zipfile.ZipFile(d + '/evil.zip', 'w') as z:
    z.writestr('../../evil.txt', 'out\n')
    z.writestr('ok.txt', 'in\n')
with tarfile.open(d + '/link.tar', 'w') as t:
    i = tarfile.TarInfo('out'); i.type = tarfile.SYMTYPE; i.linkname = '/tmp'; t.addfile(i)
    data = b'pwn\n'; i = tarfile.TarInfo('out/pwned.txt'); i.size = len(data); t.addfile(i, io.BytesIO(data))
    data = b'fine\n'; i = tarfile.TarInfo('fine.txt'); i.size = len(data); t.addfile(i, io.BytesIO(data))
PY
head -c 900M /dev/urandom > big.bin
bsdtar -a -cf ../big.zip --options zip:compression=store big.bin
rm -f big.bin
cd .. && rm -rf src && ls -la | cut -c1-90
