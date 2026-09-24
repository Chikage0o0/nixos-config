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
    version = "2026.9.1";
    format = "wheel";

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/ab/a1/8bc10e0834dd8ba46d0208663fff4f5bf9cdfb8596cffdf6c592f14d071a/midea_lan-2026.9.1-py3-none-any.whl";
      hash = "sha256-NzB/f+Fw8GPsLvmjAhYZ8w1dKUWlZ5l7w8fdZsyhyPs=";
    };

    dependencies = with ps; [
      aiofiles
      aiohttp
      colorlog
      defusedxml
      deprecated
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
