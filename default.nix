with import <nixpkgs> {};
with darwin.apple_sdk.frameworks;

let wev = stdenv.mkDerivation {
  pname = "w08r-emacs-libvterm";
  version = "a940dd2";

  src = fetchFromGitHub {
    sha256 = "sha256-A4ptIWzeF4oFzK8bptP1UxHNp296res20Ydt6vnUAmc=";
    rev = "b44723552f86407d528c4a6c8057382c061b008e";
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
    pkgconfig
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
  version = "4e6c778";

  src = fetchFromGitHub {
    sha256 = "sha256-CKyj1cW01jG3e3pxSgzIOVvyLfS/OZ2x1Cr80uhA1I8=";
    rev = "fedd930a09a497c03df3ce5204ccbd80da724662";
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
    pkgconfig
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
  version = "b8cfe8f";

  src = fetchFromSavannah {
    rev = "b8cfe8fa754e3a3d197b785a179e0915ba4f53bf";
    repo = "emacs";
    sha256 = "sha256-S4rGk6mwgK2aGO0beFJmDAIGckZnfWMCht8kdoKozCc=";
  };

  sitelisp = fetchurl {
    url = "https://raw.githubusercontent.com/will08rien/emacs-nix/main/site-start.el";
    sha256 = "5127047146c8393036d203b46aaa9844ca50f8b65e564bfc5dd7918a0f12a943";
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
    pkgconfig
    AppKit
    zlib
    ncurses
    texinfo
    WebKit
    wev
  ];

  macsdk = "/Library/Developer/CommandLineTools/SDKs/MacOSX12.3.sdk";
  configurePhase = ''
    ./autogen.sh

    CPPFLAGS="-I${macsdk}/usr/include  -isysroot ${macsdk}/ -I${macsdk}//System/Library/Frameworks/AppKit.framework/Versions/C/Headers -I${pkgs.lib.getLib libgccjit}/include" \
    CFLAGS="-O3 -isysroot ${macsdk}/ -framework AppKit" \
    CC=/usr/bin/clang \
    LDFLAGS="-O3 -L ${pkgs.lib.getLib libgccjit}/lib" \
    ./configure \
     --disable-silent-rules \
     --prefix=$out \
     --enable-locallisppath=$out/site-lisp \
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
     --enable-mac-app=$out/Applications
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
    substituteInPlace lisp/emacs-lisp/comp.el --replace \
        "(defcustom native-comp-driver-options nil" \
        "(defcustom native-comp-driver-options '(${gccjitOpts})"
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
    substituteInPlace $out/site-lisp/site-start.el --replace \
        "(setq w08r-site-dir nil" \
        "(setq w08r-site-dir \"$out\""
  '';
}
