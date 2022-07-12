# gfx-wrap

Inspired by: <https://github.com/guibou/nixGL>

## Installation

In `configuration.nix` / `home.nix`:

```nix
gfx-wrap-source = builtins.fetchurl {
    url = "https://github.com/mihnea-s/gfx-wrap/";
    sha256 = "";
}

gfx = pkgs.callPackage gfx-wrap-source {
    gpus = [ "nvidia" "intel" ]; # Default: [ "intel" ]
    enable32bits = false; # Default: true
};

# ... Some lines later ...

home.packages = with pkgs; [
    # gfx-wrap will automatically set the
    # needed libraries for a given derivation
    (gfx.wrap blender)

    # if you need to run executables outside
    # of your home packages, use gfx-run
    gfx.run

    # celluloid will not work without the proper
    # graphics drivers
    celluloid
];
```

Now switch / reboot into your new environment:

```shell
$ blender
    Read prefs: .../.config/blender/3.2/config/userpref.blend
    ^C
    Saved session recovery to '/tmp/quit.blend'
    Blender quit

$ celluloid
    Gsk-Message: 14:52:33.039: Failed to realize renderer of type 'GskGLRenderer' for surface 'GdkWaylandToplevel':
        Failed to create EGL display
    ^C

$ gfx-run celluloid
    (No errors! 🥳)
```

## Support Matrix

|     API     |       Intel        |     AMD     |       Nvidia       |   Nouveau   |
| :---------: | :----------------: | :---------: | :----------------: | :---------: |
|   OpenGL    | :heavy_check_mark: |     :x:     | :heavy_check_mark: |     :x:     |
|   OpenCL    | :heavy_check_mark: |     :x:     | :heavy_check_mark: |     :x:     |
|   Vulkan    | :heavy_check_mark: |     :x:     | :heavy_check_mark: |     :x:     |
|   VA-API    | :heavy_check_mark: |     :x:     |      :o:[^1]       |     :x:     |
|    VDPAU    | :heavy_check_mark: |     :x:     |      :o:[^2]       |     :x:     |
| NVENC/NVDEC |    :wavy_dash:     | :wavy_dash: | :heavy_check_mark: | :wavy_dash: |
|    CUDA     |    :wavy_dash:     | :wavy_dash: | :heavy_check_mark: | :wavy_dash: |
|    ROCm     |    :wavy_dash:     |     :x:     |    :wavy_dash:     | :wavy_dash: |

[^1]: Only decoding is supported via NVDEC, see: <https://github.com/elFarto/nvidia-vaapi-driver>
[^2]: Nvidia VDPAU works only if the Nvidia GPU is controlling the display, on optimus laptops using Intel VDPAU with VA-API backend is recommended.

## Selecting drivers

```bash
# To use the NVIDIA GPU for OpenGL rendering set the following:
export __NV_PRIME_RENDER_OFFLOAD=1
export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only

# Change the GPU to be used for decoding with VDPAU:
#   - 'va_gl' for VA-API/GL based Intel driver
#   - 'nvidia' for official Nvidia VDPAU implementation
#
# Note: Selecting 'va_gl' here requires the next value to
# be set to 'iHD'.
export VDPAU_DRIVER=('va_gl' or 'nvidia') 

# Choose which GPU will be used for encoding, decoding 
# and transforming videos:
#   - 'iHD' for official Intel VA-API implementation
#   - 'nvidia' for NVDEC based unofficial driver
export LIBVA_DRIVER_NAME=('iHD' or 'nvidia')

# Your program must be gfx.wrapped!
# Otherwise run it with gfx-run
gfx-run vdpau-or-vaapi-using-program
```
