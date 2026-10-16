{
  autoPatchelfHook,
  fetchurl,
  lib,
  python3Packages,
  stdenv,
}:
let
  ps = python3Packages;
in
{
  mideaLan = ps.buildPythonPackage {
    pname = "midea-lan";
    version = "2026.9.2";
    format = "wheel";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/44/28/075d3bdc125f111e6d1cb676f4e5a923488df02a069642d30fb225c5afc6/midea_lan-2026.9.2-py3-none-any.whl";
      hash = "sha256-zg2hJlzDiud6AvGMJpk+HeMs0ymCV22sg0uUpBxV2uE=";
    };

    dependencies = with ps; [
      aiofiles
      aiohttp
      colorlog
      defusedxml
      ifaddr
      platformdirs
      pycryptodome
      typing-extensions
    ];

    pythonImportsCheck = [ "midealan" ];
    doCheck = false;

    meta = {
      description = "Local control library for Midea M-Smart appliances";
      homepage = "https://github.com/midea-lan/midea-local";
      license = lib.licenses.mit;
    };
  };

  miniRacer = ps.buildPythonPackage {
    pname = "mini-racer";
    version = "0.14.1";
    format = "wheel";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/56/0c/5260cc29908777c91391dd8b61be9042a3d1c089e6bfc798cd403e44e87d/mini_racer-0.14.1-py3-none-manylinux_2_27_aarch64.whl";
      hash = "sha256-f5PZGXPdstpOiZ4G7LQmv+fqEDzRySaH7Jw48gbzdes=";
    };

    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];

    pythonImportsCheck = [ "py_mini_racer" ];
    doCheck = false;

    meta = {
      description = "Embedded V8 runtime for Python";
      homepage = "https://github.com/bpcreech/PyMiniRacer";
      license = lib.licenses.isc;
      platforms = [ "aarch64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
}
