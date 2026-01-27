{
  stdenv,
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_10,
  pnpmConfigHook,
  nodejs,
  makeWrapper,
  ...
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "openarchiver";
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "LogicLabs-OU";
    repo = "openarchiver";
    tag = "v${finalAttrs.version}";
    hash = "sha256-vyhoZb8sdIczRlTWQO+dTEDyQY5f/s+3/w9xDs/2524=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-otVkKL82ENOxm6r8bYpTJ6cCUd3N2a/7htT8pccW/f0=";

    inherit (finalAttrs) postPatch pnpmInstallFlags;
  };

  nativeBuildInputs = [
    nodejs
    pnpmConfigHook
    pnpm_10
    makeWrapper
  ];

  env.CI = true;

  postPatch = ''
    substituteInPlace package.json --replace-fail '"packageManager": "pnpm@10.13.1"' '"packageManager": "pnpm"'
    substituteInPlace package.json --replace-fail '"pnpm": "10.13.1"' '"pnpm": "*"'
  '';

  pnpmInstallFlags = [
    "--shamefully-hoist"
  ];

  buildPhase = ''
    runHook preBuild

    pnpm build:oss

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/app/packages/backend/{dist,node_modules}
    mkdir -p $out/app/packages/backend/src/database/migrations
    mkdir -p $out/app/packages/frontend/{build,node_modules}
    mkdir -p $out/app/packages/types/{dist,node_modules}
    mkdir -p $out/app/apps/open-archiver/dist

    cp -r node_modules $out/app

    cp -r packages/backend/dist/* $out/app/packages/backend/dist
    cp -r packages/backend/drizzle.config.ts $out/app/packages/backend/drizzle.config.ts
    cp -r packages/backend/src/database/migrations/* $out/app//packages/backend/src/database/migrations
    cp packages/backend/package.json $out/app/packages/backend/package.json
    cp -r packages/backend/node_modules/* $out/app/packages/backend/node_modules

    cp -r packages/frontend/build/* $out/app/packages/frontend/build
    cp packages/frontend/package.json $out/app/packages/frontend/package.json
    cp -r packages/frontend/node_modules/* $out/app/packages/frontend/node_modules

    cp -r packages/types/dist/* $out/app/packages/types/dist
    cp packages/types/package.json $out/app/packages/types/package.json
    cp -r packages/types/node_modules/* $out/app/packages/types/node_modules

    cp -r apps/open-archiver/dist/* $out/app/apps/open-archiver/dist
    cp apps/open-archiver/package.json $out/app/apps/open-archiver/package.json
    cp pnpm-lock.yaml $out/app/pnpm-lock.yaml
    cp pnpm-workspace.yaml $out/app/pnpm-workspace.yaml
    cp package.json $out/app/package.json

    makeWrapper ${lib.getExe pnpm_10} $out/bin/openarchiver --chdir $out/app --prefix PATH : ${
      lib.makeBinPath [
        nodejs
        pnpm_10
      ]
    } --add-flags "docker-start:oss"

    makeWrapper ${lib.getExe pnpm_10} $out/bin/openarchiver-migrate --chdir $out/app --prefix PATH : ${
      lib.makeBinPath [
        nodejs
        pnpm_10
      ]
    } --add-flags "db:migrate"


    runHook postInstall
  '';

  passthru = {
    inherit pnpm_10;
  };

  meta = {
    description = "An open-source platform for legally compliant email archiving";
    homepage = "https://openarchiver.com/";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ shawn8901 ];
    mainProgram = "openarchiver";
  };
})
