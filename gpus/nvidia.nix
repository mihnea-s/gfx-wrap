{ lib
, nvidia-vaapi-driver
, linuxPackages
, listFilesInPaths
, enable32bits
}:

let
  nvidiaVersion = (
    let
      data = builtins.readFile "/proc/driver/nvidia/version";
      match = builtins.match ".*Module  ([0-9.]+)  .*" data;
    in
    if match != null then builtins.head match else null
  );

  nvidiaLibs = (linuxPackages.nvidia_x11.override { libsOnly = true; }).overrideAttrs (_: rec {
    version = nvidiaVersion;
    name = "gfx-wrap-nvidia-libs-${version}";
    src = builtins.fetchurl "https://download.nvidia.com/XFree86/Linux-x86_64/${version}/NVIDIA-Linux-x86_64-${version}.run";
  });

  nvidiaDrivers = [ nvidiaLibs ] ++ lib.optional enable32bits nvidiaLibs.lib32;

in
{
  eglVendors = listFilesInPaths ".json" nvidiaDrivers /share/glvnd/egl_vendor.d;

  vkicds = listFilesInPaths ".json" nvidiaDrivers /share/vulkan/icd.d;

  clicds = listFilesInPaths ".icd" nvidiaDrivers /etc/OpenCL/vendors;

  vaapi = [
    (lib.makeSearchPath "lib/dri" [ nvidia-vaapi-driver ])
  ];

  ldLibs = [
    (lib.makeLibraryPath nvidiaDrivers)
    (lib.makeSearchPathOutput "lib" "lib/vdpau" nvidiaDrivers)
  ];

  envs = { };
}
