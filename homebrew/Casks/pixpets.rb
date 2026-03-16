cask "pixpets" do
  version "0.2.3"
  sha256 "783bef3efe3ef8c9852a47ccc0b92e6e13bcbfd53dbc61057214558bc9d296fb"

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
