{ stdenv

# Build time
, fetchurl, pkgconfig, autoreconfHook

# Run time
, openssl, db48, boost, zeromq, zlib, miniupnpc
, utillinux, protobuf, qrencode, libevent

# Test Time
, rapidcheck, python3

# Options and conditional deps

, withGui ? stdenv.hostPlatform.isLinux
, qtbase ? null, qttools ? null, wrapQtAppsHook ? null

, enableWallet ? !stdenv.hostPlatform.isWindows
}:

with stdenv.lib;
stdenv.mkDerivation rec {
  name = "bitcoin" + (toString (optional (!withGui) "d")) + "-" + version;
  version = "0.18.1";

  src = fetchurl {
    urls = [ "https://bitcoincore.org/bin/bitcoin-core-${version}/bitcoin-${version}.tar.gz"
             "https://bitcoin.org/bin/bitcoin-core-${version}/bitcoin-${version}.tar.gz"
           ];
    sha256 = "5c7d93f15579e37aa2d1dc79e8f5ac675f59045fceddf604ae0f1550eb03bf96";
  };

  patches = [
    ./mingw-use-pkg-config.patch
  ];

  nativeBuildInputs =
    [ pkgconfig autoreconfHook ]
    ++ optional withGui wrapQtAppsHook;

  buildInputs = [
    boost
  ] ++ optionals (!stdenv.hostPlatform.isWindows) [
    openssl db48 zlib zeromq miniupnpc protobuf libevent
  ] ++ optionals stdenv.hostPlatform.isLinux [ utillinux ]
    ++ optionals withGui [ qtbase qttools qrencode ];

  configureFlags = [
    (enableFeature enableWallet "wallet")
    (enableFeatureAs withGui "gui" "qt5")
    "--disable-bench"
  ] ++ optionals (!stdenv.hostPlatform.isWindows) [
    "--with-boost-libdir=${boost.out}/lib"
  ] ++ optionals (!doCheck) [
    "--disable-tests"
    "--disable-gui-tests"
  ] ++ optionals withGui [
    "--with-qt-bindir=${qtbase.dev}/bin:${qttools.dev}/bin"
  ];

  checkInputs = [ rapidcheck python3 ];

  doCheck = true;

  checkFlags =
    [ "LC_ALL=C.UTF-8" ]
    # QT_PLUGIN_PATH needs to be set when executing QT, which is needed when testing Bitcoin's GUI.
    # See also https://github.com/NixOS/nixpkgs/issues/24256
    ++ optional withGui "QT_PLUGIN_PATH=${qtbase}/${qtbase.qtPluginPrefix}";

  enableParallelBuilding = true;

  meta = {
    description = "Peer-to-peer electronic cash system";
    longDescription= ''
      Bitcoin is a free open source peer-to-peer electronic cash system that is
      completely decentralized, without the need for a central server or trusted
      parties. Users hold the crypto keys to their own money and transact directly
      with each other, with the help of a P2P network to check for double-spending.
    '';
    homepage = http://www.bitcoin.org/;
    maintainers = with maintainers; [ roconnor AndersonTorres ];
    license = licenses.mit;
    broken = !(withGui -> enableWallet)
      || (withGui && !stdenv.hostPlatform.isLinux);
    platforms = platforms.all;
  };
}
