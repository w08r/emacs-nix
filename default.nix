with import <nixpkgs> {};
with darwin.apple_sdk.frameworks;

let wev = stdenv.mkDerivation {
  pname = "w08r-emacs-libvterm";
  version = "a940dd2";

  src = fetchFromGitHub {
    sha256 = "sha256-egN9sRWxUN99ExmO8ZWhYV43x0U2EUlnFAElIP3BAlc=";
    rev = "a940dd2ee8a82684860e320c0f6d5e15d31d916f";
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
  version = "ed1d4fc";

  src = fetchFromGitHub {
    sha256 = "sha256-jeBF5CRt36mpv/qVWegj7q1wL84vy9yEuS09c+xl458=";
    rev = "4e6c778194bea39d81871a3caa0b72539fdb6868";
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
    ( cd server && make )
  '';

  installPhase = ''
    ( cd server && make install )
    mkdir $out/lisp && cp lisp/*.el $out/lisp
  '';
};

in stdenv.mkDerivation rec {
  pname = "w08r-emacs";
  version = "cda372b";

  src = fetchFromSavannah {
    rev = "cda372bfc237b1b3544b4968953b4b0532b32c88";
    repo = "emacs";
    sha256 = "sha256-G2VQPCTowtTpKZDhedJZn5Z/YJsHtxSQQNX6Eeekphc=";
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

  macsdk = "/Library/Developer/CommandLineTools/SDKs/MacOSX12.1.sdk";
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
    make -j8
  '';

  installPhase = ''
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
