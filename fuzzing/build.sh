# SPDX-FileCopyrightText: 2024 ennamarie19
# SPDX-License-Identifier: MIT
export QPDF_SOURCE_TREE="$SRC"/qpdf
export QPDF_BUILD_LIBDIR=$QPDF_SOURCE_TREE/build/libqpdf

# Build qpdf dependency
cd $QPDF_SOURCE_TREE
cmake -S . -B build \
    -DOSS_FUZZ=ON \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_CXX_STANDARD=17 \
    CC="$CC" CXX="$CXX" CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS"
cmake --build build --parallel --target libqdf

# Build pikepdf
cd "$SRC"/pikepdf
env LD_LIBRARY_PATH=$QPDF_BUILD_LIBDIR QPDF_SOURCE_TREE=$QPDF_SOURCE_TREE QPDF_BUILD_LIBDIR=$QPDF_BUILD_LIBDIR \
    CC="$CC" CFLAGS="$CFLAGS" CXX="$CXX" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LIB_FUZZING_ENGINE" LDSHARED="$CXX -shared" \
    pip3 install --verbose .

# Build fuzzers in $OUT
for fuzzer in $(find fuzzing -name '*_fuzzer.py');do
    fuzzer_basename=$(basename -s .py $fuzzer)
    fuzzer_package=${fuzzer_basename}.pkg

    pyinstaller --distpath $OUT --onefile --name $fuzzer_package $fuzzer \
      --add-binary="$QPDF_BUILD_LIBDIR/libqpdf.so.29:." \
      --add-binary="/lib/x86_64-linux-gnu/libz.so.1:." \
      --add-binary="/lib/x86_64-linux-gnu/libjpeg.so.8:."

    echo "#!/bin/sh
    # LLVMFuzzerTestOneInput for fuzzer detection.
    this_dir=\$(dirname \"\$0\")
    LD_PRELOAD=\$(python -c \"import atheris; print(atheris.path())\")/asan_with_fuzzer.so \
    ASAN_OPTIONS=\$ASAN_OPTIONS:symbolize=1:external_symbolizer_path=\$this_dir/llvm-symbolizer:detect_leaks=0 \
    \$this_dir/$fuzzer_package \$@" > $OUT/$fuzzer_basename

    chmod +x $OUT/$fuzzer_basename
done
zip -q $OUT/pikepdf_fuzzer_seed_corpus.zip $SRC/pikepdf/fuzzing/corpus/*
