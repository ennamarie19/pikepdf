# SPDX-FileCopyrightText: 2024 ennamarie19
# SPDX-License-Identifier: MIT
export QPDF_SOURCE_TREE="$SRC"/qpdf
export QPDF_BUILD_LIBDIR=$QPDF_SOURCE_TREE/build/libqpdf
export QPDF_BUILD_LIBDIR=$OUT/src/qpdf/build/libqpdf

# Build qpdf dependency

cd $QPDF_SOURCE_TREE
./fuzz/oss-fuzz-build

# Build pikepdf
cd "$SRC"/pikepdf
env QPDF_SOURCE_TREE=$QPDF_SOURCE_TREE QPDF_BUILD_LIBDIR=$QPDF_BUILD_LIBDIR \
    CC="$CC" CFLAGS="$CFLAGS" CXX="$CXX" CXXFLAGS="$CXXFLAGS" LDSHARED="$CXX -shared" \
    pip3 install --verbose .


# Build fuzzers in $OUT
for fuzzer in $(find fuzzing -name '*_fuzzer.py');do
  compile_python_fuzzer "$fuzzer" \
      --add-binary="/src/qpdf/build/libqpdf/libqpdf.so.29:." \
      --add-binary="/lib/x86_64-linux-gnu/libz.so.1:." \
      --add-binary="/lib/x86_64-linux-gnu/libjpeg.so.8:."
done
zip -q $OUT/pikepdf_fuzzer_seed_corpus.zip $SRC/pikepdf/fuzzing/corpus/*
