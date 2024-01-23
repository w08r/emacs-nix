with import <nixpkgs> {};
with darwin.apple_sdk.frameworks;

let wev = stdenv.mkDerivation {
  pname = "w08r-emacs-libvterm";
  version = "94e2b0b";

  src = fetchFromGitHub {
    sha256 = "sha256-1+AbPtyl1dS73WTMrIUduyWeM4cOiD3CI7d0Ic3jpVw=";
    rev = "94e2b0b2b4a750e7907dacd5b4c0584900846dd1";
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
    mkdir -p $out/lib
    cp vterm.el vterm-module.so $out/lib
  '';
};

wep = stdenv.mkDerivation {
  pname = "w08r-emacs-pdftools";
  version = "c69e765";

  src = fetchFromGitHub {
    sha256 = "sha256-6u+uP865v6hMR9Q/ZiEidJrPkP8mnjPGex9lQCOvgQo=";
    rev = "c69e7656a4678fe25afbd29f3503dd19ee7f9896";
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
    ( cd server && ./autogen.sh && ./configure --prefix $out )
  '';

  buildPhase = ''
    ( cd server && PATH=$PATH:/usr/bin make )
  '';

  installPhase = ''
    ( cd server && PATH=$PATH:/usr/bin make install )
    mkdir $out/lisp && cp lisp/*.el $out/lisp
  '';
};

in stdenv.mkDerivation rec {
  pname = "w08r-emacs";
  version = "7c6e44e5ccb";

  src = fetchFromSavannah {
    rev = "7c6e44e5ccb009a63da30fbc468c924dd383b521";
    repo = "emacs";
    sha256 = "sha256-UHiJaF2sFJ6N1D0l6JeB7wOFaTwFCV7+qtb+X1CPXos=";
  };

  sitelisp = ./site-start.el;

  #   fetchurl {
  #   url = "https://raw.githubusercontent.com/will08rien/emacs-nix/main/site-start.el";
  #   sha256 = "33117a61c0cae3388a1dac524580f19c1f65539e3313f51b293efce988964a0c";
  # };

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
    tree-sitter
    wev
  ];

  macsdk = "/Library/Developer/CommandLineTools/SDKs/MacOSX14.2.sdk";
  configurePhase = ''
    ./autogen.sh

    CPPFLAGS="-I${macsdk}/usr/include  -isysroot ${macsdk}/ -I${macsdk}//System/Library/Frameworks/AppKit.framework/Versions/C/Headers -I${pkgs.lib.getLib libgccjit}/include"     CFLAGS="-O3 -isysroot ${macsdk}/ -framework AppKit"     CC=/usr/bin/clang     LDFLAGS="-O3 -L ${pkgs.lib.getLib libgccjit}/lib"     ./configure      --disable-silent-rules      --prefix=$out      --enable-locallisppath=$out/site-lisp      --without-dbus      --without-imagemagick      --with-mailutils      --disable-ns-self-contained      --with-cairo      --with-modules      --with-xml2      --with-gnutls      --with-json      --with-rsvg      --with-native-compilation      --with-gnutls=ifavailable      --enable-mac-app=$out/Applications      --with-xwidgets      --with-tree-sitter
  '';

  gccjitOpts =   (lib.concatStringsSep " "
        (builtins.map (x: ''\"-B${x}\"'') [
          # Paths necessary so the JIT compiler finds its libraries:
          "${lib.getLib libgccjit}/lib"
          "${lib.getLib libgccjit}/lib/gcc"
          "${lib.getLib stdenv.cc.libc}/lib"

          # Executable paths necessary for compilation (ld, as):
          "${lib.getBin stdenv.cc.cc}/bin"
          "${lib.getBin stdenv.cc.bintools}/bin"
          "${lib.getBin stdenv.cc.bintools.bintools}/bin"
        ]));
        
  buildPhase = ''
    PATH=$PATH:/usr/bin make -j8
  '';

  installPhase = ''
    PATH=$PATH:/usr/bin
    make NATIVE_FULL_AOT=1 install
    mkdir $out/Applications
    cp -r nextstep/Emacs.app $out/Applications/
    cp -r src $out
    mkdir -p $out/site-lisp
    runHook postInstall
  '';

  postInstall = ''
    cp $sitelisp $out/site-lisp/site-start.el
    cp ${lib.getLib wev}/lib/* $out/site-lisp/
    cp ${lib.getLib wep}/bin/* $out/bin/
    substituteInPlace $out/site-lisp/site-start.el --replace         "(setq w08r-grip-dir nil"         "(setq w08r-grip-dir \"${lib.getBin python311Packages.grip}\""
    substituteInPlace $out/site-lisp/site-start.el --replace         "(setq w08r-nix-gnutls-dir nil"         "(setq w08r-nix-gnutls-dir \"${lib.getBin gnutls}\""
    ln -s $out/lib/emacs/30.0.50/native-lisp $out/Applications/Emacs.app/Contents
    substituteInPlace $out/site-lisp/site-start.el --replace         "(setq w08r-site-dir nil"         "(setq w08r-site-dir \"$out\""
    substituteInPlace $out/site-lisp/site-start.el --replace         "(setq native-comp-driver-options nil"         "(setq native-comp-driver-options '(${gccjitOpts})"
  '';
}
