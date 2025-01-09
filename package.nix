{ lib, buildDotnetModule, dotnetCorePackages, ffmpeg}:

buildDotnetModule rec {
  pname = "InternetRadio2Computercraft";
  version = "1.0";

  src = ./.;

  projectFile = "./InternetRadio2Computercraft.sln";
  dotnet-sdk = dotnetCorePackages.sdk_9_0;
  dotnet-runtime = dotnetCorePackages.sdk_9_0;
  dotnetFlags = [ "" ];
  executables = [ "InternetRadio2Computercraft" ];
  runtimeDeps = [ ffmpeg ];
}
