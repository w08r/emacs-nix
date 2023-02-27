#!/bin/bash

s() {
    (
        cd repos/$1
        git pull &>/dev/null
        git rev-parse --short HEAD
    )
}

l() {
    (
        cd repos/$1
        git pull &>/dev/null
        git rev-parse HEAD
    )
}

EMACS_S=$(s emacs)
EMACS=$(l emacs)

VT_S=$(s emacs-libvterm)
VT=$(l emacs-libvterm)

PDF_S=$(s pdf-tools)
PDF=$(l pdf-tools)

cat >default.nix <<EOF
with import <nixpkgs> {};
with darwin.apple_sdk.frameworks;

let wev = stdenv.mkDerivation {
  pname = "w08r-emacs-libvterm";
  version = "${VT_S}";

  src = fetchFromGitHub {
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    rev = "${VT}";
    repo = "emacs-libvterm";
    owner = "akermu";
    fetchSubmodules = true;
  };

  buildInputs = [
    cmake
    cacert
    perl
    git
    libtool
    autoconf
    pkg-config
    zlib
  ];

  configurePhase = ''
    ( mkdir build && cd build && cmake .. )
  '';

  buildPhase = ''
    ( cd build && LIBTOOL=libtool make -j8 || true )
    ( cd build/libvterm-prefix/src/libvterm/.libs && ar -rc libvterm.a ../src/.libs/*.o )
    ( cd build && LIBTOOL=libtool make -j8 || true )
  '';

  installPhase = ''
    mkdir -p \$out/lib
    cp vterm.el vterm-module.so \$out/lib
  '';
};

wep = stdenv.mkDerivation {
  pname = "w08r-emacs-pdftools";
  version = "${PDF_S}";

  src = fetchFromGitHub {
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    rev = "${PDF}";
    repo = "pdf-tools";
    owner = "vedang";
    fetchSubmodules = true;
  };

  buildInputs = [
    cmake
    poppler
    libpng
    autoconf
    automake
    imagemagick
    cacert
    perl
    git
    libtool
    autoconf
    pkg-config
    zlib
  ];

  configurePhase = ''
    ( cd server && ./autogen.sh && ./configure --prefix \$out )
  '';

  buildPhase = ''
    ( cd server && PATH=\$PATH:/usr/bin make )
  '';

  installPhase = ''
    ( cd server && PATH=\$PATH:/usr/bin make install )
    mkdir \$out/lisp && cp lisp/*.el \$out/lisp
  '';
};

in stdenv.mkDerivation rec {
  pname = "w08r-emacs";
  version = "${EMACS_S}";

  src = fetchFromSavannah {
    rev = "${EMACS}";
    repo = "emacs";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  sitelisp = fetchurl {
    url = "https://raw.githubusercontent.com/will08rien/emacs-nix/main/site-start.el";
    sha256 = "33117a61c0cae3388a1dac524580f19c1f65539e3313f51b293efce988964a0c";
  };

  buildInputs = [
    curl
    gettext
    libjpeg
    giflib
    libtiff
    librsvg
    git
    autoconf
    openssl
    libgccjit
    jansson
    pkg-config
    AppKit
    zlib
    ncurses
    texinfo
    WebKit
    wev
  ];

  macsdk = "/Library/Developer/CommandLineTools/SDKs/MacOSX13.1.sdk";
  configurePhase = ''
    ./autogen.sh

    CPPFLAGS="-I\${macsdk}/usr/include  -isysroot \${macsdk}/ -I\${macsdk}//System/Library/Frameworks/AppKit.framework/Versions/C/Headers -I\${pkgs.lib.getLib libgccjit}/include" \
    CFLAGS="-O3 -isysroot \${macsdk}/ -framework AppKit" \
    CC=/usr/bin/clang \
    LDFLAGS="-O3 -L \${pkgs.lib.getLib libgccjit}/lib" \
    ./configure \
     --disable-silent-rules \
     --prefix=\$out \
     --enable-locallisppath=\$out/site-lisp \
     --without-dbus \
     --without-imagemagick \
     --with-mailutils \
     --disable-ns-self-contained \
     --with-cairo \
     --with-modules \
     --with-xml2 \
     --with-gnutls \
     --with-json \
     --with-rsvg \
     --with-native-compilation \
     --with-gnutls=ifavailable \
     --enable-mac-app=\$out/Applications \
     --with-xwidgets
  '';

  gccjitOpts =   (lib.concatStringsSep " "
        (builtins.map (x: ''\"-B\${x}\"'') [
          # Paths necessary so the JIT compiler finds its libraries:
          "\${lib.getLib libgccjit}/lib"
          "\${lib.getLib libgccjit}/lib/gcc"
          "\${lib.getLib stdenv.cc.libc}/lib"

          # Executable paths necessary for compilation (ld, as):
          "\${lib.getBin stdenv.cc.cc}/bin"
          "\${lib.getBin stdenv.cc.bintools}/bin"
          "\${lib.getBin stdenv.cc.bintools.bintools}/bin"
        ]));
        
  buildPhase = ''
    PATH=\$PATH:/usr/bin make -j8
  '';

  installPhase = ''
    PATH=\$PATH:/usr/bin
    make NATIVE_FULL_AOT=1 install
    mkdir \$out/Applications
    cp -r nextstep/Emacs.app \$out/Applications/
    cp -r src \$out
    mkdir -p \$out/site-lisp
    runHook postInstall
  '';

  postInstall = ''
    cp \$sitelisp \$out/site-lisp/site-start.el
    cp \${lib.getLib wev}/lib/* \$out/site-lisp/
    cp \${lib.getLib wep}/bin/* \$out/bin/
    ln -s \$out/lib/emacs/30.0.50/native-lisp \$out/Applications/Emacs.app/Contents
    substituteInPlace \$out/site-lisp/site-start.el --replace \
        "(setq w08r-site-dir nil" \
        "(setq w08r-site-dir \"\$out\""
    substituteInPlace \$out/site-lisp/site-start.el --replace \
        "(setq native-comp-driver-options nil" \
        "(setq native-comp-driver-options '(\${gccjitOpts})"
  '';
}
EOF
