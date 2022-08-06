{ pkgs
, lib
, runCommand
, makeWrapper
, writeShellScriptBin
, libdrm
, libglvnd
, vulkan-validation-layers
, gpus ? [ "intel" ]
, enable32bits ? true
}:

let
  listFilesInPath = (ext: path:
    let
      allFiles = builtins.readDir path;
      jsons = lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ext n) allFiles;
      jsonPaths = builtins.map (n: path + "/${n}") (lib.attrNames jsons);
    in
    jsonPaths
  );

  listFilesInPaths = (ext: paths: concat:
    let
      concated = builtins.map (path: path + concat) paths;
      listed = builtins.map (listFilesInPath ext) concated;
    in
    lib.flatten listed
  );

  intel = pkgs.callPackage ./gpus/intel.nix {
    inherit listFilesInPaths enable32bits;
  };

  nvidia = pkgs.callPackage ./gpus/nvidia.nix {
    inherit listFilesInPaths enable32bits;
  };

  gfx = rec {
    enabled = {
      intel = builtins.elem "intel" gpus;
      nvidia = builtins.elem "nvidia" gpus;
    };

    eglVendors = lib.concatStringsSep ":" (
      [ ]
      ++ (lib.optionals enabled.intel intel.eglVendors)
      ++ (lib.optionals enabled.nvidia nvidia.eglVendors)
    );

    vkicds = lib.concatStringsSep ":" (
      [ ]
      ++ (lib.optionals enabled.intel intel.vkicds)
      ++ (lib.optionals enabled.nvidia nvidia.vkicds)
    );

    clicds = lib.concatStringsSep ":" (
      [ ]
      ++ (lib.optionals enabled.intel intel.clicds)
      ++ (lib.optionals enabled.nvidia nvidia.clicds)
    );

    vaapi = lib.concatStringsSep ":" (
      [ ]
      ++ (lib.optionals enabled.intel intel.vaapi)
      ++ (lib.optionals enabled.nvidia nvidia.vaapi)
    );

    ldLibs = lib.concatStringsSep ":" (
      [ ]
      ++ (lib.optionals enabled.intel intel.ldLibs)
      ++ (lib.optionals enabled.nvidia nvidia.ldLibs)
      ++ [ (lib.makeLibraryPath [ libdrm libglvnd ]) ]
    );

    envs = (
      { "VK_LAYER_PATH" = "${vulkan-validation-layers}/share/vulkan/explicit_layer.d"; }
      // (lib.optionalAttrs enabled.intel intel.envs)
      // (lib.optionalAttrs enabled.nvidia nvidia.envs)
    );
  };

  wrap = wrapped: runCommand "${wrapped.pname or wrapped.name}-gfxwrapped"
    {
      pname = wrapped.pname or null;
      version = wrapped.version or null;
      passthru = wrapped.passthru or { };
      buildInputs = [ makeWrapper ];
    } ''
    mkdir $out
    mkdir $out/bin

    # Link every top-level folder from pkgs.hello 
    # to our new target except the bin folder
    shopt -s extglob
    ln -s ${wrapped}/!(bin) $out

    # We created the bin folder ourselves and link every binary in it
    for bin in ${wrapped}/bin/*; do
      if ! [[ -f "$bin" && -x "$bin" ]]; then
        # $bin is not an executable
        ln -s "$bin" "$out/bin/$(basename "$bin")"
        continue
      fi

      makeWrapper "$bin" "$out/bin/$(basename "$bin")"      \
        --inherit-argv0                                     \
        --prefix-each VK_ICD_FILENAMES ":" "${gfx.vkicds}"  \
        --prefix-each OCL_ICD_FILENAMES ":" "${gfx.clicds}" \
        --prefix-each LD_LIBRARY_PATH  ":" "${gfx.ldLibs}"  \
        --prefix-each LIBVA_DRIVERS_PATH ":" "${gfx.vaapi}" \
        --prefix-each __EGL_VENDOR_LIBRARY_FILENAMES ":" "${gfx.eglVendors}" \
        ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "--set \"${k}\" \"${v}\"") gfx.envs)} \
        ;
    done
  '';

  run = writeShellScriptBin "gfx-run" ''
    export VK_ICD_FILENAMES="${gfx.vkicds}":VK_ICD_FILENAMES
    export OCL_ICD_FILENAMES="${gfx.clicds}":OCL_ICD_FILENAMES
    export LD_LIBRARY_PATH="${gfx.ldLibs}":LD_LIBRARY_PATH
    export LIBVA_DRIVERS_PATH="${gfx.vaapi}":LIBVA_DRIVERS_PATH
    export __EGL_VENDOR_LIBRARY_FILENAMES="${gfx.eglVendors}":__EGL_VENDOR_LIBRARY_FILENAMES
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=\"${v}\"") gfx.envs)}
    exec "$@"
  '';
in
{
  inherit wrap run;
}
