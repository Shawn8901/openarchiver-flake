{
  description = "Flake to setup Open-Archiver";
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    inputs:
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs { inherit system; };
      openarchiver-pkg = pkgs.callPackage ./package.nix { };
    in
    {
      nixosModules.openarchiver = import ./module.nix { inherit openarchiver-pkg; };
      packages.${system}.openarchiver = openarchiver-pkg;
    };

}
