cask "pixpets" do
  version "1.0.0"
  sha256 "PLACEHOLDER"

  url "https://github.com/Evgenii-Konev/pixelpets/releases/download/v#{version}/PixPets-#{version}.dmg"
  name "PixPets"
  desc "Menu bar app showing animated pixel pets for AI coding agent sessions"
  homepage "https://github.com/Evgenii-Konev/pixelpets"

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
