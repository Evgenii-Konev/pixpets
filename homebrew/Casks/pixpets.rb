cask "pixpets" do
  version "0.6.1"
  sha256 "e9a06f82b8356359e0693bd5dc4c1f682f9ef5bd28f9819b0f43a969105e3887"

  url "https://github.com/Evgenii-Konev/pixpets/releases/download/v#{version}/PixPets-#{version}.dmg"
  name "PixPets"
  desc "Menu bar app showing animated pixel pets for AI coding agent sessions"
  homepage "https://github.com/Evgenii-Konev/pixpets"

  depends_on macos: ">= :ventura"

  app "PixPets.app"

  postflight do
    ohai "Run 'pixpets --install-hooks' to set up Claude Code integration"
  end

  zap trash: "~/.pixpets"

  caveats <<~EOS
    To enable session tracking, run:
      pixpets --install-hooks

    This installs the hook script and configures Claude Code to report sessions.
  EOS
end
