cask "pixpets" do
  version "0.3.0"
  sha256 "c6e3928ca4e5c1e4e8fa483e65ab659d4ed48ab9be37ebfd120aae24196f8497"

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
