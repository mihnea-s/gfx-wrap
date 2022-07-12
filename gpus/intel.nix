{ lib
, mesa
, intel-ocl
, intel-media-driver
, libvdpau-va-gl
, vaapiIntel
, pkgsi686Linux
, listFilesInPaths
, enable32bits
}:

let
  intelDrivers = {
    gl = [ mesa.drivers ]
      ++ lib.optionals enable32bits (with pkgsi686Linux; [ mesa.drivers ]);
    va = [ intel-media-driver vaapiIntel ]
      ++ lib.optionals enable32bits (with pkgsi686Linux; [ intel-media-driver vaapiIntel ]);
    vdpau = [ libvdpau-va-gl ]
      ++ lib.optionals enable32bits (with pkgsi686Linux; [ libvdpau-va-gl ]);
  };

in
{
  eglVendors = listFilesInPaths ".json" intelDrivers.gl /share/glvnd/egl_vendor.d;

  vkicds = listFilesInPaths ".json" intelDrivers.gl /share/vulkan/icd.d;

  clicds = listFilesInPaths ".icd" [ intel-ocl ] /etc/OpenCL/vendors;

  vaapi = [
    (lib.makeSearchPath "lib/dri" intelDrivers.va)
  ];

  ldLibs = [
    (lib.makeLibraryPath intelDrivers.gl)
    (lib.makeSearchPathOutput "lib" "lib/vdpau" intelDrivers.vdpau)
  ];

  envs = {
    "LIBGL_DRIVERS_PATH" = lib.makeSearchPathOutput "lib" "lib/dri" intelDrivers.gl;
  };
}
