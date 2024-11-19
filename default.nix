with import <nixpkgs> {};
with darwin.apple_sdk.frameworks;

let wev = stdenv.mkDerivation {
  pname = "w08r-emacs-libvterm";
  version = "9882793";

  src = fetchFromGitHub {
    sha256 = "sha256-W/UGA3/ecu1fd7u5pYTlRqcULF3EgCVnWQGQYX93YOI=";
    rev = "988279316fc89e6d78947b48513f248597ba969a";
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
  version = "30b5054";

  src = fetchFromGitHub {
    sha256 = "sha256-/UH3KcuZf9p7MA0ZzhqAgTv6LjKnBXHfJUOdIxV6KbI=";
    rev = "30b50544e55b8dbf683c2d932d5c33ac73323a16";
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
  version = "200c877cd48";

  src = fetchFromSavannah {
    rev = "200c877cd48aa0f7638fdd5157555374f0f7bfc8";
    repo = "emacs";
    sha256 = "sha256-OX7zU9lC2mMW1WHIHwYXCn6O234TMOKh6AnbgfAlNBk=";
  };

  sitelisp = fetchurl {
    url = "https://raw.githubusercontent.com/will08rien/emacs-nix/main/site-start.el";
    sha256 = "sha256-bNSkJHdSfGnl3tQqPT6tVOmZz7VqeTiej/LFDwjHwEA=";
  };

  buildInputs = [
    curl
    gettext
    libjpeg
    sqlite
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
    gnutls
    tree-sitter
    wev
  ];

  macsdk = "/Library/Developer/CommandLineTools/SDKs/MacOSX15.1.sdk";
  configurePhase = ''
    ./autogen.sh

    CPPFLAGS="-I${macsdk}/usr/include  -isysroot ${macsdk}/ -I${macsdk}//System/Library/Frameworks/AppKit.framework/Versions/C/Headers -I${pkgs.lib.getLib libgccjit}/include"     CFLAGS="-O3 -isysroot ${macsdk}/ -framework AppKit"     CC=/usr/bin/clang     LDFLAGS="-O3 -L ${pkgs.lib.getLib libgccjit}/lib"     ./configure      --disable-silent-rules      --prefix=$out      --enable-locallisppath=$out/site-lisp      --without-dbus      --without-imagemagick      --with-mailutils      --disable-ns-self-contained      --with-cairo      --with-modules      --with-xml2      --with-gnutls      --with-json      --with-rsvg      --with-native-compilation      --with-gnutls=ifavailable      --enable-mac-app=$out/Applications      --with-xwidgets      --with-tree-sitter --with-sqlite
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
    ln -s $out/lib/emacs/31.0.50/native-lisp $out/Applications/Emacs.app/Contents
    substituteInPlace $out/site-lisp/site-start.el --replace         "(setq w08r-site-dir nil"         "(setq w08r-site-dir \"$out\""
    substituteInPlace $out/site-lisp/site-start.el --replace         "(setq native-comp-driver-options nil"         "(setq native-comp-driver-options '(${gccjitOpts})"
  '';
}
