{ stdenv, version, fetch, cmake, python, llvm, libcxxabi }:
stdenv.mkDerivation rec {
  name = "compiler-rt-${version}";
  inherit version;
  src = fetch "compiler-rt" "065ybd8fsc4h2hikbdyricj6pyv4r7r7kpcikhb2y5zf370xybkq";

  nativeBuildInputs = [ cmake python llvm ];
  buildInputs = stdenv.lib.optional stdenv.hostPlatform.isDarwin libcxxabi;

  configureFlags = [
    "-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON"
  ];

  outputs = [ "out" "dev" ];

  patches = [
    ./compiler-rt-codesign.patch # Revert compiler-rt commit that makes codesign mandatory
  ] ++ stdenv.lib.optional stdenv.hostPlatform.isMusl ./sanitizers-nongnu.patch
  ++ stdenv.lib.optional stdenv.hostPlatform.isDarwin ./compiler-rt-clock_gettime.patch;

  # TSAN requires XPC on Darwin, which we have no public/free source files for. We can depend on the Apple frameworks
  # to get it, but they're unfree. Since LLVM is rather central to the stdenv, we patch out TSAN support so that Hydra
  # can build this. If we didn't do it, basically the entire nixpkgs on Darwin would have an unfree dependency and we'd
  # get no binary cache for the entire platform. If you really find yourself wanting the TSAN, make this controllable by
  # a flag and turn the flag off during the stdenv build.
  postPatch = stdenv.lib.optionalString stdenv.isDarwin ''
    substituteInPlace cmake/config-ix.cmake \
      --replace 'set(COMPILER_RT_HAS_TSAN TRUE)' 'set(COMPILER_RT_HAS_TSAN FALSE)'
  '';

  # Hack around weird upsream RPATH bug
  postInstall = stdenv.lib.optionalString stdenv.isDarwin ''
    ln -s "$out/lib"/*/* "$out/lib"
  '';

  enableParallelBuilding = true;
}