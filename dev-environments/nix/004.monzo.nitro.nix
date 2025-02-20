# https://github.com/monzo/aws-nitro-util/blob/master/flake.nix
### Nix flake for building nitro CLI utilities
{
  description = "Builds AWS Nitro Enclave Image Format files (EIFs) deterministically, cross-platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    nixpkgs.lib.recursiveUpdate
      (flake-utils.lib.eachDefaultSystem
        (system:
          let
            pkgs = nixpkgs.legacyPackages."${system}";
            # returns 'aarch64' from 'aarch64-linux'
            sysPrefix = pkgs.stdenv.hostPlatform.uname.processor;
          in
          rec {
            lib = {
              # paths to each of the blobs, for use if you are not compiling these from source
              blobs =
                let
                  blobsFor = kName: prefix: rec {
                    blobPath = self.packages.${system}.aws-nitro-cli-src + "/blobs/${prefix}";

                    /*
                      The kernel binary as pre-compiled by AWS
                    */
                    kernel = blobPath + "/${kName}";
                    kernelConfig = blobPath + "/${kName}.config";
                    cmdLine = blobPath + "/cmdline";

                    /*
                      nitro kernel module as pre-compiled by AWS
                    */
                    nsmKo = blobPath + "/nsm.ko";

                    /*
                      init.c program (to boot up the enclave) as pre-compiled by AWS

                      Note you can use `packages.<system>.eif-init` instead,
                      and avoid using a downloaded binary blob.
                    */
                    init = blobPath + "/init";
                  };
                in
                {
                  aarch64 = blobsFor "Image" "aarch64";
                  x86_64 = blobsFor "bzImage" "x86_64";
                };

              /*
                Makes sys and user ramdisks. See mkSysRamdisk and mkUserRamdisk
              */
              mkRamdisksFrom =
                { init ? self.packages.${system}.eif-init
                , nsmKo      # string - path the nitro kernel module
                , entrypoint # string - command to execute after encave boot - this is the path to your entrypoint binary inside rootfs)
                , env        # string - environment variables to pass to the entrypoint)
                , rootfs     # path   - the root filesystem
                }: [
                  (lib.mkSysRamdisk { inherit init nsmKo; })
                  (lib.mkUserRamdisk { inherit entrypoint env rootfs; })
                ];

              /**
               * Assembles an initramfs archive from a compiled init binary and a compiled Nitro kernel module.
               *
               * The expected layout depends on the source of init.c, but see
               * https://github.com/aws/aws-nitro-enclaves-cli/blob/main/enclave_build/src/yaml_generator.rs
               * for the expected file layout of AWS' init.c
               *
               * By default, init is a compiled-from-source version of AWS' default init.c. See packages.init
               *
               * Returns a derivation to a cpio.gz archive
               */
              mkSysRamdisk =
                { name ? "bootstrap-initramfs"
                , init ? self.packages.${system}.eif-init # path (derivation)
                , nsmKo ? null                                   # path (derivation)
                }:
                lib.mkCpioArchive {
                  inherit name;
                  src = pkgs.runCommand "${name}-fs" { } ''
                    mkdir -p  $out/dev
                    ${if nsmKo == null then "" else "cp ${nsmKo} $out/nsm.ko"}
                    cp ${init} $out/init
                  '';
                };

              /**
               * Assembles an initramfs archive from a root filesystem and config for the entrypoint.
               * The expected layout depends on the source of init.c, but see
               * https://github.com/aws/aws-nitro-enclaves-cli/blob/main/enclave_build/src/yaml_generator.rs
               * for the expected file layout of AWS' init.c
               *
               * Returns a derivation to a cpio.gz archive
               */
              mkUserRamdisk =
                { name ? "user-initramfs"
                , entrypoint # string - command to execute after encave boot - this is the path to your entrypoint binary inside rootfs)
                , env        # string - environment variables to pass to the entrypoint)
                , rootfs     # path   - the root filesystem
                }: lib.mkCpioArchive {
                  inherit name;
                  src = pkgs.runCommand "${name}-fs" { } ''
                    mkdir -p  $out/rootfs
                    cp ${pkgs.writeText "${name}-env" env} $out/env
                    cp ${pkgs.writeText "${name}-entrypoint" entrypoint} $out/cmd
                    cp -r ${rootfs}/* $out/rootfs

                    (cd $out/rootfs && mkdir -p dev run sys var proc tmp || true)
                  '';
                };

              /* deterministically builds a cpio archive that can be used as an initramfs iamge */
              mkCpioArchive =
                { name ? "archive"
                , src # path (derivation) of unarchived folder
                }: pkgs.runCommand "${name}.cpio.gz"
                  {
                    inherit src;
                    buildInputs = [ pkgs.cpio ];
                  }
                  ''
                    mkdir -p root
                    cp -r $src/* root/

                    find root -exec touch -h --date=@1 {} +
                    (cd root && find * .[^.*] -print0 | sort -z | cpio -o -H newc -R +0:+0 --reproducible --null | gzip -n > $out)
                  '';


              /*
               * Uses eif_build to build an image. See packages.eif_build. Note that only Linux EIFs can be made.
               *
               * Returns a derivation containing:
               *  - image in derivation/image.eif
               *  - PCRs in derivation/pcr.json
               */
              mkEif =
                { name ? "image-linux-${arch}-${version}-eif"
                , version ? "0.1-dev"
                , ramdisks           # list[path] of ramdisks to use for boot. See mkUserRamdisk and mkSysRamdisk
                , kernel             # path (derivation) to compiled kernel binary
                , kernelConfig       # path (derivation) to kernel config file
                , cmdline ? "reboot=k panic=30 pci=off nomodules console=ttyS0 random.trust_cpu=on root=/dev/ram0" # string
                , arch ? sysPrefix   # string - <"aarch64" | "x86_64"> architecture to build EIF for. Defaults to current system's.
                }: pkgs.stdenv.mkDerivation rec {
                  inherit name version;

                  buildInputs = [ packages.eif_build pkgs.jq ];
                  unpackPhase = ":"; # nothing to unpack
                  ramdisksArgs = with pkgs.lib; concatStrings (map (ramdisk: "--ramdisk ${ramdisk} ") ramdisks);
                  metadataArgs = "--build-tool='monzo-aws-nitro-util' --build-time='1970-01-01T00:00:00.000000+00:00'";

                  buildPhase = ''
                    echo "Kernel:            ${kernel}"
                    echo "Kernel config:      ${kernelConfig}"
                    echo "cmdline:           ${cmdline}"
                    echo "ramdisks:          ${pkgs.lib.concatStrings ramdisks}"
                    eif_build \
                      --arch ${arch} \
                      --kernel ${kernel} \
                      --kernel_config ${kernelConfig} \
                      --cmdline "${cmdline}" \
                      ${ramdisksArgs} \
                      --name ${name} \
                      --version ${version} \
                      ${metadataArgs} \
                      --output image.eif >> log.txt;
                  '';

                  installPhase = ''
                    mkdir -p $out
                    cp image.eif $out
                    # save logs
                    cp log.txt $out
                    # extract PCRs from logs
                    cat log.txt | tail -6 >> $out/pcr.json
                    # show PCRs in nix build logs
                    jq < $out/pcr.json
                  '';
                };
              inherit pkgs;

              buildEif =
                { name ? "image-linux-${arch}-${version}-eif"
                , version ? "0.1-dev"
                , kernel # path (derivation) to compiled kernel binary
                , kernelConfig       # path (derivation) to kernel config file
                , cmdline ? "reboot=k panic=30 pci=off nomodules console=ttyS0 random.trust_cpu=on root=/dev/ram0" # string
                , arch ? sysPrefix   # string - <"aarch64" | "x86_64"> architecture to build EIF for. Defaults to current system's.
                  #  if you change this also set `kernel`
                , copyToRoot         # path - contents that get copied over to the root filesystem
                , copyToRootWithClosure ? true   # bool - whether to also copy copyToRoot's depdencies over
                , entrypoint
                , nsmKo ? null
                , init ? self.crossPackages.${system}."${arch}-linux".eif-init + "/bin/init"
                , env ? ""
                }:
                let
                  # returns a derivation with rootPath and all its dependencies, copied over
                  nixStoreFrom = rootPath: pkgs.runCommandNoCC "pack-closure" { } ''
                    mkdir -p $out/nix/store
                    PATHS=$(cat ${pkgs.closureInfo { rootPaths = [ rootPath ] ; }}/store-paths)
                    for p in $PATHS; do
                      cp -r $p $out/nix/store
                    done
                    cp -r ${rootPath}/* $out
                  '';
                  rootfs = if copyToRootWithClosure then nixStoreFrom copyToRoot else copyToRoot;
                in
                lib.mkEif {
                  inherit kernel kernelConfig cmdline arch name version;

                  ramdisks = [
                    (lib.mkSysRamdisk { inherit init nsmKo; })
                    (lib.mkUserRamdisk { inherit entrypoint env rootfs; })
                  ];
                };


              # returns a derivation that is folder containing a deterministic filesystem of the image's layers
              unpackImage =
                { name ? "image-rootfs"
                , imageName
                , imageDigest
                , sha256
                , arch ? pkgs.go.GOARCH # default architecture for current nixpkgs
                }:
                pkgs.runCommand name
                  {
                    inherit imageDigest name;
                    sourceURL = "docker://${imageName}@${imageDigest}";
                    impureEnvVars = pkgs.lib.fetchers.proxyImpureEnvVars;
                    outputHashMode = "recursive";
                    outputHashAlgo = "sha256";
                    outputHash = sha256;

                    buildInputs = [ pkgs.skopeo pkgs.umoci ];
                    SSL_CERT_FILE = "${pkgs.cacert.out}/etc/ssl/certs/ca-bundle.crt";

                    destNameTag = "private.io/pulled:latest";
                  } ''
                  skopeo \
                    --insecure-policy \
                    --tmpdir=$TMPDIR \
                    --override-os linux \
                    --override-arch ${arch} \
                    copy \
                    "$sourceURL" "oci:image:latest" \
                    | cat  # pipe through cat to force-disable progress bar

                  mkdir -p $out
                  umoci raw unpack  --rootless --image image $out
                  echo "Unpacked filesystem:"
                  ls -la $out
                '';
            };

            # The repo we get compiled blobs from
            packages.aws-nitro-cli-src =
              let
                hashes = rec {
                  x86_64-linux = "sha256-+vQ9XK3la7K35p4VI3Mct5ij2o21zEYeqndI7RjTyiQ=";
                  aarch64-darwin = "sha256-GeguCHNIOhPYc9vUzHrQQdc9lK/fru0yYthL2UumA/Q=";
                  aarch64-linux = x86_64-linux;
                  x86_64-darwin = aarch64-darwin;
                };
              in
              pkgs.fetchFromGitHub {
                owner = "aws";
                repo = "aws-nitro-enclaves-cli";
                rev = "v1.2.3";
                sha256 = hashes.${system};
              };

            # A CLI to build eif images, provided by AWS in
            # https://github.com/aws/aws-nitro-enclaves-image-format
            packages.eif_build = pkgs.callPackage ./eif_build/package.nix { };

            /*
             * Takes the system that you would like to compile for,
             * and returns an attribute set with some packages cross-compiled for that system.
             *
             * Returns normal, non-cross-compiled packages when system == crossSystem.
             *
             * For example:
             *
             * `init-for-x86 = (nitro.crossCompile "x86_64-linux").eif-init;`
             *
             * Note it is currently not possible to compile init.c and the Kernel on darwin.
             */
            crossCompile = crossSystem:
              let crossPkgs = if (system == crossSystem) then pkgs else import nixpkgs { localSystem = system; inherit crossSystem; }; in
              {
                eif-init = crossPkgs.callPackage ./init { };
              };

            crossPackages = {
              x86_64-linux = crossCompile "x86_64-linux";
              aarch64-linux = crossCompile "aarch64-linux";
            };



            checks = {
              # make sure we can build the eif_build CLI
              inherit (packages) eif_build;

              # build a simple (non-bootable) EIF image for x86-64 as part of checks
              test-make-eif = lib.mkEif {
                arch = "x86_64";
                name = "test";
                ramdisks = [
                  (lib.mkSysRamdisk { init = lib.blobs.x86_64.init; nsmKo = lib.blobs.x86_64.nsmKo; })
                  (lib.mkUserRamdisk { entrypoint = "none"; env = ""; rootfs = pkgs.writeTextDir "etc/file" "hello world!"; })
                ];
                kernel = lib.blobs.x86_64.kernel;
                kernelConfig = lib.blobs.x86_64.kernelConfig;
              };

              # check the PCR for this simple EIF is reproduced
              test-eif-PCRs-match = pkgs.stdenvNoCC.mkDerivation {
                buildInputs = [ pkgs.jq ];
                name = "test-eif-PCRs-match";
                src = checks.test-make-eif;
                dontBuild = true;
                doCheck = true;
                checkPhase = ''
                  PCR0=$(jq -r < ./pcr.json ' .PCR0 ')
                  if echo "$PCR0" | grep -qv 'f585cae40c5d5d640a60d3c7f8c5dcf7276364c49f7d7fa8d08800b35c45825099688c2acc02bb2373ebfbd8a5ba10b4'
                  then
                    echo "PCR0 did not match, got instead:" $PCR0
                    exit -1
                  fi
                '';
                installPhase = "mkdir $out";
              };
            };
          }
        ))

      # we are not cross-compiling init.c, which needs gcc:
      (flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
        let
          pkgs = nixpkgs.legacyPackages."${system}";
        in
        rec {

          /*
             * init.c, compiled and statically linked from https://github.com/aws/aws-nitro-enclaves-sdk-bootstrap
             */
          packages.eif-init = self.crossPackages.${system}.${system}.eif-init;

          checks = {
            # make sure we can build init.c
            inherit (packages) eif-init;
          };
        }
      ))
  ;
}
