
# cp -r t/rDB t/useModDB  (runwikMod.t should have created t/useModDB)
cp t/config.convMod t/config
./r/runlogm.pl -t t/conv.out

./extras/backendConvert.pl -o t/useModDB -n t/plainDB
cp t/config.convDef t/config
./r/runlogm.pl -t t/conv.out

./extras/backendConvert.pl -o t/useModDB -n t/svnDB -N Subversion
cp t/config.convSVN t/config
./r/runlogm.pl -t t/conv.out

