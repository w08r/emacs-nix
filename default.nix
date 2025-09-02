with import <nixpkgs> {};

let wev = stdenv.mkDerivation {
  pname = "w08r-emacs-libvterm";
  version = "056ad74";

  src = fetchFromGitHub {
    sha256 = "sha256-ZBAQOUr+IrDlXUKpG2HUzNjVfGdphXqrmiPn90bvAVY=";
    rev = "056ad74653704bc353d8ec8ab52ac75267b7d373";
    repo = "emacs-libvterm";
    owner = "akermu";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    apple-sdk
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

  nativeBuildInputs = [
    apple-sdk
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
  version = "66ef930ebea";

  src = fetchFromSavannah {
    rev = "66ef930ebea4618c1dac71a09495766476ced1d6";
    repo = "emacs";
    sha256 = "sha256-MyGfTN/q1GmgRRhFh7FX+pPbmh/xtCNbEikHJNtv7U8=";
  };

  sitelisp = fetchurl {
    url = "https://raw.githubusercontent.com/will08rien/emacs-nix/main/site-start.el";
    sha256 = "sha256-x3EmNaX2ec3jBK4BK/bS0i8V4rU4e4Mp+rHrm4Jd5TQ=";
  };

  nativeBuildInputs = [
    apple-sdk
    curl
    gettext
    libjpeg
    giflib
    libtiff
    librsvg
    gnutls
    sqlite
    git
    autoconf
    openssl
    libgccjit
    jansson
    pkg-config
    zlib
    ncurses
    texinfo
    tree-sitter
    wev
  ];

  macsdk = "/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk";
  configurePhase = ''
    ./autogen.sh;

     LIBRARY_PATH="" CPPFLAGS="-I${macsdk}/usr/include  -isysroot ${macsdk}/ -I${macsdk}//System/Library/Frameworks/AppKit.framework/Versions/C/Headers -I${pkgs.lib.getLib libgccjit}/include"     CFLAGS="-O3 -isysroot ${macsdk}/ -framework AppKit"     CC=/usr/bin/clang     LDFLAGS="-O3"     ./configure      --disable-silent-rules      --prefix=$out      --enable-locallisppath=$out/site-lisp      --without-dbus      --without-imagemagick      --with-mailutils      --disable-ns-self-contained      --with-cairo      --with-modules      --with-xml2      --with-gnutls      --with-json      --with-librsvg      --with-native-compilation      --with-gnutls=ifavailable      --enable-mac-app=$out/Applications      --with-xwidgets      --with-tree-sitter      --with-sqlite
  '';

  env = {
    LIBRARY_PATH = "";
  };

  gccjitOpts =   (lib.concatStringsSep " "
        (builtins.map (x: ''\"-B${x}\"'') [
          # Paths necessary so the JIT compiler finds its libraries:
          # "${lib.getLib libgccjit}/lib"
          "${lib.getLib libgccjit}/lib/gcc/arm64-apple-darwin/14.3.0/"
          "/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk/usr/lib/"
          # "${lib.getLib stdenv.cc.libc}/lib"

          # Executable paths necessary for compilation (ld, as):
          # "${lib.getBin stdenv.cc.cc}/bin"
          # "${lib.getBin stdenv.cc.bintools}/bin"
          # "${lib.getBin stdenv.cc.bintools.bintools}/bin"
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
    cat >> $out/site-lisp/site-start.el <<EOF
    (add-to-list 'exec-path "${antigen.out}/bin")
    (add-to-list 'exec-path "${aspell.out}/bin")
    (add-to-list 'exec-path "${atuin.out}/bin")
    (add-to-list 'exec-path "${awscli2.out}/bin")
    (add-to-list 'exec-path "${colima.out}/bin")
    (add-to-list 'exec-path "${coreutils.out}/bin")
    (add-to-list 'exec-path "${devcontainer.out}/bin")
    (add-to-list 'exec-path "${direnv.out}/bin")
    (add-to-list 'exec-path "${docker.out}/bin")
    (add-to-list 'exec-path "${duckdb.out}/bin")
    (add-to-list 'exec-path "${eza.out}/bin")
    (add-to-list 'exec-path "${fd.out}/bin")
    (add-to-list 'exec-path "${ffmpeg.out}/bin")
    (add-to-list 'exec-path "${gnupg.out}/bin")
    (add-to-list 'exec-path "${ipcalc.out}/bin")
    (add-to-list 'exec-path "${karabiner-elements.out}/bin")
    (add-to-list 'exec-path "${kubectl.out}/bin")
    (add-to-list 'exec-path "${ollama.out}/bin")
    (add-to-list 'exec-path "${ripgrep.out}/bin")
    (add-to-list 'exec-path "${starship.out}/bin")
    (add-to-list 'exec-path "${tokei.out}/bin")
    (add-to-list 'exec-path "${zoxide.out}/bin")
    (add-to-list 'exec-path "${zsh.out}/bin")

    (setq w08r-uk-dict-list '("${aspellDicts.en.out}" "${aspellDicts.uk.out}"))
    EOF
  '';
}
